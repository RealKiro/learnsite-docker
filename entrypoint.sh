#!/bin/bash
set -e

# ========== 配置区域（可自定义）==========
# 主要仓库地址（GitHub）
PRIMARY_REPO_URL="https://github.com/RealKiro/learnsite.git"
# 备用仓库地址（Gitee）
FALLBACK_REPO_URL="https://gitee.com/realiy/learnsite.git"
# SQL 文件主要下载链接
PRIMARY_SQL_URL="https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql"
# SQL 文件备用下载链接
FALLBACK_SQL_URL="https://gitee.com/realiy/learnsite/raw/main/sql/learnsite.sql"

APP_DIR="/app"
STATE_DIR="${APP_DIR}/.state"
LAST_COMMIT_FILE="${STATE_DIR}/last_commit"
MARKER_FILE="${APP_DIR}/.initialized"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
DEFAULT_WEB_CONFIG="/usr/local/share/default-web.config"

# 环境变量控制：是否每次启动都检查更新（默认 false）
AUTO_UPDATE=${AUTO_UPDATE_SOURCE:-false}
# ==========================================

echo "========================================="
echo "Starting LearnSite (runtime source fetch mode)"
echo "Auto update: $AUTO_UPDATE"
echo "========================================="

mkdir -p "${STATE_DIR}"

# 函数：克隆仓库（支持主备切换）
clone_repo() {
    local repo_url=$1
    local target=$2
    echo "Attempting to clone from $repo_url ..."
    if git clone --depth 1 "$repo_url" "$target"; then
        return 0
    else
        echo "Failed to clone from $repo_url"
        return 1
    fi
}

# 函数：拉取最新更新（git pull）
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
            echo "❌ Failed to pull from fallback."
            return 1
        fi
    fi
    cd - >/dev/null
}

# 判断是否需要获取/更新源码
if [ ! -f "${MARKER_FILE}" ] || [ "${AUTO_UPDATE}" = "true" ]; then
    if [ ! -f "${MARKER_FILE}" ]; then
        echo "🚀 First run (marker not found)."
    else
        echo "🔄 Auto update enabled. Checking for source updates..."
    fi

    # 如果 /app 为空，则执行初始克隆
    if [ -z "$(ls -A "${APP_DIR}" 2>/dev/null)" ]; then
        echo "📦 /app is empty. Performing initial clone..."
        # 清空可能残留的隐藏文件，但保留挂载点
        find "${APP_DIR}" -mindepth 1 -delete 2>/dev/null || true
        # 尝试主仓库
        if clone_repo "${PRIMARY_REPO_URL}" "${APP_DIR}"; then
            echo "✓ Cloned from primary repository."
        else
            echo "⚠️ Primary clone failed, trying fallback..."
            if clone_repo "${FALLBACK_REPO_URL}" "${APP_DIR}"; then
                echo "✓ Cloned from fallback repository."
            else
                echo "❌ ERROR: Both repositories failed to clone."
                exit 1
            fi
        fi
        # 记录当前 commit
        git --git-dir="${APP_DIR}/.git" rev-parse HEAD > "${LAST_COMMIT_FILE}"
    else
        # /app 非空，检查是否是 git 仓库
        if [ -d "${APP_DIR}/.git" ]; then
            echo "📁 Existing Git repository found."
            # 获取当前远程 commit
            cd "${APP_DIR}"
            LOCAL_COMMIT=$(git rev-parse HEAD)
            # 获取远程最新 commit（从主仓库）
            REMOTE_COMMIT=$(git ls-remote "${PRIMARY_REPO_URL}" HEAD | cut -f1)
            if [ -n "$REMOTE_COMMIT" ] && [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                echo "New commits detected. Pulling..."
                update_repo
                # 更新后重新记录 commit
                git rev-parse HEAD > "${LAST_COMMIT_FILE}"
            else
                echo "✓ Repository already up-to-date."
            fi
            cd - >/dev/null
        else
            # 非 git 仓库，可能是用户手动放置的代码，跳过更新
            echo "⚠️ /app is not a Git repository. Assuming user-provided code. Skipping source update."
        fi
    fi

    # 创建标记文件（如果不存在）
    touch "${MARKER_FILE}"
else
    echo "⏭️ Marker exists and auto update disabled. Skipping source update."
fi

# ========== 确保 learnsite.sql 存在（如果缺失则从备用链接下载）==========
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
            echo "❌ Failed to download learnsite.sql. Database init may fail."
        fi
    fi
else
    echo "✓ learnsite.sql already exists."
fi

# ========== 应用自定义 web.config 模板（覆盖源码中的配置文件）==========
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