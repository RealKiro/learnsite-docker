#!/bin/bash
set -e

# 将所有输出重定向到控制台（便于 Docker 日志捕获）
exec > /proc/1/fd/1 2>&1

# ========== 解决 Git 所有权问题 ==========
if command -v git >/dev/null 2>&1; then
    git config --global --add safe.directory /app 2>/dev/null || true
fi

# ========== 配置区域（可被环境变量覆盖）==========
: "${PRIMARY_REPO_URL:=https://gitee.com/realiy/learnsite.git}"
: "${FALLBACK_REPO_URL:=https://github.com/RealKiro/learnsite.git}"
: "${CLONE_RETRIES:=3}"
: "${RETRY_INTERVAL:=5}"

APP_DIR="/app"
STATE_DIR="${APP_DIR}/.state"
LAST_COMMIT_FILE="${STATE_DIR}/last_commit"
MARKER_FILE="${APP_DIR}/.initialized"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
DEFAULT_WEB_CONFIG="/usr/local/share/default-web.config"

AUTO_UPDATE=${AUTO_UPDATE_SOURCE:-false}
# ==============================================

echo "========================================="
echo "Starting LearnSite (runtime source fetch mode with retry)"
echo "Auto update: $AUTO_UPDATE"
echo "Primary repo: $PRIMARY_REPO_URL"
echo "Fallback repo: $FALLBACK_REPO_URL"
echo "========================================="

mkdir -p "${STATE_DIR}"

# 函数：带重试的克隆操作
clone_with_retry() {
    local repo_url=$1
    local target=$2
    local retries=$3
    local attempt=1
    while [ $attempt -le $retries ]; do
        echo "Attempt $attempt of $retries to clone from $repo_url ..."
        if git clone --depth 1 "$repo_url" "$target"; then
            echo "✓ Successfully cloned from $repo_url on attempt $attempt."
            return 0
        else
            echo "⚠️ Clone attempt $attempt failed."
            if [ $attempt -lt $retries ]; then
                echo "Retrying in $RETRY_INTERVAL seconds..."
                sleep $RETRY_INTERVAL
            fi
        fi
        attempt=$((attempt + 1))
    done
    echo "❌ Failed to clone from $repo_url after $retries attempts."
    return 1
}

# 函数：拉取最新更新（git pull），若因历史无关失败则强制重置
update_repo() {
    cd "${APP_DIR}"
    if git pull --depth 1 origin; then
        echo "✓ Repository updated via git pull."
    else
        echo "⚠️ git pull failed, trying fallback remote..."
        git remote set-url origin "${FALLBACK_REPO_URL}"
        if git pull --depth 1 origin; then
            echo "✓ Repository updated from fallback."
        else
            # 如果因为历史无关导致失败，尝试强制重置
            echo "⚠️ Pull failed, possibly due to unrelated histories. Fetching and resetting to origin/HEAD..."
            if git fetch origin; then
                git reset --hard origin/HEAD
                echo "✓ Repository reset to origin/HEAD."
            else
                echo "❌ Failed to pull from fallback."
                return 1
            fi
        fi
    fi
    cd - >/dev/null
}

# 判断是否需要获取/更新源码
if [ ! -f "${MARKER_FILE}" ]; then
    echo "🚀 First run (marker not found). Forcing clean clone regardless of existing files..."

    # 强制清空 /app 目录内容（但保留挂载点）
    echo "Cleaning up /app directory..."
    find "${APP_DIR}" -mindepth 1 -delete 2>/dev/null || true

    # 备份状态目录（避免被克隆覆盖）
    if [ -d "${STATE_DIR}" ]; then
        cp -r "${STATE_DIR}" /tmp/state-backup
    fi

    # 执行带重试的克隆：先尝试主仓库，失败则尝试备用
    CLONE_SUCCESS=false
    if clone_with_retry "${PRIMARY_REPO_URL}" "${APP_DIR}" ${CLONE_RETRIES}; then
        CLONE_SUCCESS=true
        echo "✓ Cloned from primary repository."
    else
        echo "⚠️ Primary repository failed after ${CLONE_RETRIES} attempts. Trying fallback repository..."
        if clone_with_retry "${FALLBACK_REPO_URL}" "${APP_DIR}" ${CLONE_RETRIES}; then
            CLONE_SUCCESS=true
            echo "✓ Cloned from fallback repository."
        fi
    fi

    if [ "$CLONE_SUCCESS" = false ]; then
        echo "❌ ERROR: Both primary and fallback repositories failed to clone after multiple attempts."
        echo "Container will exit. Please check network connectivity or repository URLs."
        exit 1
    fi

    # 恢复状态目录（若无备份则创建）
    if [ -d "/tmp/state-backup" ]; then
        rm -rf "${STATE_DIR}" 2>/dev/null || true
        mv /tmp/state-backup "${STATE_DIR}"
    else
        mkdir -p "${STATE_DIR}"
    fi

    # 记录当前 commit
    git --git-dir="${APP_DIR}/.git" rev-parse HEAD > "${LAST_COMMIT_FILE}"
    echo "✓ Initial source cloned."

    # 创建标记文件（仅在克隆成功后创建）
    touch "${MARKER_FILE}"
    echo "✓ Marker file created."

elif [ "${AUTO_UPDATE}" = "true" ]; then
    echo "🔄 Auto update enabled. Checking for source updates..."
    if [ -d "${APP_DIR}/.git" ]; then
        cd "${APP_DIR}"
        LOCAL_COMMIT=$(git rev-parse HEAD)
        REMOTE_COMMIT=$(git ls-remote "${PRIMARY_REPO_URL}" HEAD | cut -f1)
        if [ -n "$REMOTE_COMMIT" ] && [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
            echo "New commits detected. Pulling..."
            if update_repo; then
                git rev-parse HEAD > "${LAST_COMMIT_FILE}"
            else
                echo "❌ Failed to update repository."
                exit 1
            fi
        else
            echo "✓ Repository already up-to-date."
        fi
        cd - >/dev/null
    else
        echo "⚠️ /app is not a Git repository. Cannot auto-update. Skipping."
    fi
else
    echo "⏭️ Marker exists and auto update disabled. Skipping source update."
fi

# ========== 确保 learnsite.sql 存在 ==========
mkdir -p "${APP_DIR}/sql"
if [ ! -f "${APP_DIR}/sql/learnsite.sql" ]; then
    echo "⚠️ learnsite.sql not found. Attempting to download..."
    if curl -f -sSL -o "${APP_DIR}/sql/learnsite.sql" "${PRIMARY_SQL_URL}"; then
        echo "✓ Downloaded from primary URL."
    else
        echo "⚠️ Primary download failed, trying fallback..."
        if curl -f -sSL -o "${APP_DIR}/sql/learnsite.sql" "${FALLBACK_SQL_URL}"; then
            echo "✓ Downloaded from fallback URL."
        else
            echo "❌ Failed to download learnsite.sql from both URLs. Database init may fail."
        fi
    fi
else
    echo "✓ learnsite.sql already exists."
fi

# ========== 应用自定义 web.config 模板 ==========
if [ -f "${DEFAULT_WEB_CONFIG}" ]; then
    echo "Applying custom web.config template..."
    cp "${DEFAULT_WEB_CONFIG}" "${TARGET_WEB_CONFIG}"
    echo "✓ Custom web.config applied."
else
    echo "❌ ERROR: Default web.config not found in image!"
    exit 1
fi

# ========== 使用 envsubst 替换环境变量占位符 ==========
if command -v envsubst >/dev/null 2>&1; then
    echo "Applying environment variables to web.config..."
    envsubst < "${TARGET_WEB_CONFIG}" > "${TARGET_WEB_CONFIG}.tmp" && mv "${TARGET_WEB_CONFIG}.tmp" "${TARGET_WEB_CONFIG}"
    echo "✓ Environment variables applied."
else
    echo "⚠️ envsubst not found. Placeholders will remain."
fi

echo "========================================="
echo "Starting web server..."
echo "========================================="

exec "$@"