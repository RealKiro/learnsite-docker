#!/bin/bash
set -e

# ========== 配置区域（请根据实际修改）==========
# 主要仓库地址（GitHub）
PRIMARY_REPO_URL="https://github.com/RealKiro/learnsite.git"
# 备用仓库地址（Gitee，用于网络故障时切换）
FALLBACK_REPO_URL="https://gitee.com/realiy/learnsite.git"

# SQL 文件的主要下载链接（GitHub Raw）
PRIMARY_SQL_URL="https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql"
# SQL 文件的备用下载链接（Gitee Raw）
FALLBACK_SQL_URL="https://gitee.com/realiy/learnsite/raw/main/sql/learnsite.sql"

# 应用目录（容器内挂载点）
APP_DIR="/app"
# Git 目录标记
GIT_DIR="${APP_DIR}/.git"
# 目标 web.config 路径
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
# 镜像内的默认 web.config 模板（由 Dockerfile 复制）
DEFAULT_WEB_CONFIG="/usr/local/share/default-web.config"
# ==============================================

echo "========================================="
echo "Starting LearnSite dynamic setup (git-smart mode)"
echo "========================================="

# ========== 辅助函数 ==========
# 尝试从给定 URL 克隆仓库，成功返回0，失败返回1
clone_repo() {
    local repo_url=$1
    local target_dir=$2
    echo "Attempting to clone from $repo_url ..."
    if git clone --depth 1 "$repo_url" "$target_dir"; then
        return 0
    else
        echo "Failed to clone from $repo_url"
        return 1
    fi
}

# 尝试从给定 URL 下载 SQL 文件
download_sql() {
    local sql_url=$1
    local output_file=$2
    echo "Attempting to download SQL from $sql_url ..."
    if curl -f -sSL -o "$output_file" "$sql_url"; then
        return 0
    else
        echo "Failed to download from $sql_url"
        return 1
    fi
}

# 检查并更新 Git 仓库（如果存在 .git）
update_git_repo() {
    if [ -d "${GIT_DIR}" ]; then
        echo "✓ Existing Git repository found. Checking for updates..."
        # 进入仓库目录
        cd "${APP_DIR}"
        # 获取当前远程地址
        local remote_url=$(git config --get remote.origin.url)
        echo "Current remote: $remote_url"

        # 尝试从主要仓库 fetch（如果远程不是主仓库，可能需要处理，这里简化：直接 fetch 当前 remote）
        if git fetch --depth 1 origin; then
            local local_commit=$(git rev-parse HEAD)
            local remote_commit=$(git rev-parse origin/HEAD 2>/dev/null || echo "")
            if [ -n "$remote_commit" ] && [ "$local_commit" != "$remote_commit" ]; then
                echo "New commits detected. Pulling updates..."
                git pull --depth 1 origin
                echo "✓ Repository updated."
            else
                echo "✓ Repository already up-to-date."
            fi
        else
            echo "⚠️ Failed to fetch from current remote. Trying fallback remote..."
            # 如果 fetch 失败，尝试将 remote 改为备用仓库并拉取
            git remote set-url origin "${FALLBACK_REPO_URL}"
            if git fetch --depth 1 origin; then
                local local_commit=$(git rev-parse HEAD)
                local remote_commit=$(git rev-parse origin/HEAD)
                if [ "$local_commit" != "$remote_commit" ]; then
                    echo "New commits detected from fallback. Pulling..."
                    git pull --depth 1 origin
                    echo "✓ Repository updated from fallback."
                else
                    echo "✓ Repository already up-to-date (fallback)."
                fi
            else
                echo "❌ Failed to fetch from both primary and fallback remotes."
                # 不退出，继续使用现有代码
            fi
        fi
        cd - >/dev/null
    else
        # 不是 Git 仓库：首次运行或手动放置
        if [ -z "$(ls -A "${APP_DIR}" 2>/dev/null)" ]; then
            # 目录为空，执行初始克隆
            echo "🚀 /app is empty. Performing initial clone..."
            # 清空可能残留的隐藏文件（如 .gitignore），但保留目录本身
            find "${APP_DIR}" -mindepth 1 -delete 2>/dev/null || true
            # 尝试主仓库克隆
            if clone_repo "${PRIMARY_REPO_URL}" "${APP_DIR}"; then
                echo "✓ Initial clone from primary repository successful."
            else
                echo "⚠️ Primary clone failed, trying fallback repository..."
                if clone_repo "${FALLBACK_REPO_URL}" "${APP_DIR}"; then
                    echo "✓ Initial clone from fallback repository successful."
                else
                    echo "❌ ERROR: Both primary and fallback repositories failed to clone."
                    exit 1
                fi
            fi
        else
            # 目录非空且不是 Git 仓库，可能是用户手动放置的代码，不做任何操作
            echo "⚠️ /app is not empty and not a Git repository. Assuming user-provided code. Skipping clone/update."
        fi
    fi
}

# ========== 主流程 ==========
# 1. 更新/克隆源码
update_git_repo

# 2. 确保 learnsite.sql 存在（带故障转移下载）
mkdir -p /app/sql
if [ ! -f /app/sql/learnsite.sql ]; then
    echo "⚠️ learnsite.sql not found. Attempting to download..."

    if download_sql "${PRIMARY_SQL_URL}" /app/sql/learnsite.sql; then
        echo "✓ learnsite.sql downloaded from primary URL."
    else
        echo "⚠️ Primary download failed, trying fallback URL..."
        if download_sql "${FALLBACK_SQL_URL}" /app/sql/learnsite.sql; then
            echo "✓ learnsite.sql downloaded from fallback URL."
        else
            echo "❌ Failed to download learnsite.sql from both URLs. Database initialization may fail."
        fi
    fi
else
    echo "✓ learnsite.sql already exists."
fi

# 3. 复制默认 web.config 模板（覆盖，确保占位符正确）
if [ -f "${DEFAULT_WEB_CONFIG}" ]; then
    echo "Applying default web.config template..."
    cp "${DEFAULT_WEB_CONFIG}" "${TARGET_WEB_CONFIG}"
    echo "✓ Default web.config copied."
else
    echo "❌ ERROR: Default web.config not found in image. Cannot proceed."
    exit 1
fi

# 4. 使用 envsubst 替换环境变量占位符
if command -v envsubst >/dev/null 2>&1; then
    echo "Applying environment variables to web.config..."
    envsubst < "${TARGET_WEB_CONFIG}" > "${TARGET_WEB_CONFIG}.tmp" && mv "${TARGET_WEB_CONFIG}.tmp" "${TARGET_WEB_CONFIG}"
    echo "✓ Environment variables applied."
else
    echo "⚠️ envsubst not found. Placeholders will remain in web.config."
fi

echo "========================================="
echo "Starting web server with configured web.config..."
echo "========================================="

exec "$@"