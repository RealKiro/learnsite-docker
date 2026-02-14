#!/bin/bash
set -e

# ========== 配置区域 ==========
# 主源码仓库地址（请根据您的实际仓库修改）
REPO_URL="https://github.com/RealKiro/learnsite.git"
# 备用下载链接，用于当仓库中缺少 learnsite.sql 时自动补全（请确保链接有效）
BACKUP_SQL_URL="https://raw.githubusercontent.com/RealKiro/learnsite/refs/heads/main/sql/learnsite.sql"
# 应用目录（容器内）
APP_DIR="/app"
# 持久化状态目录，用于存放上次构建的commit和标记文件（独立于源码，避免被覆盖）
STATE_DIR="${APP_DIR}/.state"
# 上次成功构建的主源码commit记录文件
LAST_MAIN_COMMIT_FILE="${STATE_DIR}/last_main_commit"
# 初始化标记文件，存在表示已执行过首次初始化
MARKER_FILE="${APP_DIR}/.initialized"
# 目标 web.config 路径
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
# 镜像内的默认 web.config 模板（由 Dockerfile 复制）
DEFAULT_WEB_CONFIG="/usr/local/share/default-web.config"
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup (optimized)"
echo "========================================="

# 确保状态目录存在（后续会临时备份）
mkdir -p "${STATE_DIR}"

# 函数：获取远程主仓库最新 commit
get_remote_main_commit() {
    git ls-remote "${REPO_URL}" HEAD | cut -f1
}

# 检查是否为第一次运行（标记文件不存在）
if [ ! -f "${MARKER_FILE}" ]; then
    echo "🚀 First run detected. Checking for existing valid source..."

    # 读取上次记录的 commit（如果存在）
    PREV_MAIN_COMMIT=""
    [ -f "${LAST_MAIN_COMMIT_FILE}" ] && PREV_MAIN_COMMIT=$(cat "${LAST_MAIN_COMMIT_FILE}")

    # 获取远程最新 commit
    REMOTE_MAIN_COMMIT=$(get_remote_main_commit)

    # 判断是否需要更新主源码
    NEED_UPDATE_MAIN=false
    if [ -z "${REMOTE_MAIN_COMMIT}" ]; then
        echo "⚠️ Failed to get remote main commit, will proceed with update to be safe."
        NEED_UPDATE_MAIN=true
    elif [ "${PREV_MAIN_COMMIT}" != "${REMOTE_MAIN_COMMIT}" ]; then
        echo "Main source changed (${PREV_MAIN_COMMIT} -> ${REMOTE_MAIN_COMMIT}), updating..."
        NEED_UPDATE_MAIN=true
    else
        echo "Main source unchanged (commit ${PREV_MAIN_COMMIT}), reusing existing."
    fi

    # 如果需要更新主源码
    if [ "${NEED_UPDATE_MAIN}" = true ]; then
        echo "Updating main source from ${REPO_URL}..."

        # 备份状态目录（避免被克隆覆盖）
        if [ -d "${STATE_DIR}" ]; then
            cp -r "${STATE_DIR}" /tmp/state-backup
        fi

        # 直接克隆仓库到 /app（这会清空并替换 /app 下的所有内容）
        rm -rf "${APP_DIR}"  # 先删除整个 /app 确保干净
        git clone --depth 1 "${REPO_URL}" "${APP_DIR}"

        # 恢复状态目录
        if [ -d "/tmp/state-backup" ]; then
            rm -rf "${STATE_DIR}" 2>/dev/null || true
            mv /tmp/state-backup "${STATE_DIR}"
        else
            mkdir -p "${STATE_DIR}"
        fi

        echo "✓ Main source cloned."
    else
        # 如果主源码未更新，但 /app 可能为空（例如卷丢失），则强制更新
        if [ ! -d "${APP_DIR}" ] || [ -z "$(ls -A "${APP_DIR}" 2>/dev/null)" ]; then
            echo "⚠️ /app is empty but commit record exists. Forcing main source update."

            # 同样备份状态目录
            if [ -d "${STATE_DIR}" ]; then
                cp -r "${STATE_DIR}" /tmp/state-backup
            fi

            rm -rf "${APP_DIR}"
            git clone --depth 1 "${REPO_URL}" "${APP_DIR}"

            if [ -d "/tmp/state-backup" ]; then
                rm -rf "${STATE_DIR}" 2>/dev/null || true
                mv /tmp/state-backup "${STATE_DIR}"
            else
                mkdir -p "${STATE_DIR}"
            fi

            echo "✓ Main source forced cloned."
        fi
    fi

    # ========== 确保 learnsite.sql 存在 ==========
    mkdir -p /app/sql
    if [ ! -f /app/sql/learnsite.sql ]; then
        echo "⚠️ learnsite.sql not found in cloned source. Downloading from backup URL..."
        # 使用 curl 下载备用文件，-f 使失败时返回错误码，-sSL 静默但显示错误
        curl -f -sSL -o /app/sql/learnsite.sql "${BACKUP_SQL_URL}"
        if [ $? -eq 0 ] && [ -f /app/sql/learnsite.sql ]; then
            echo "✓ learnsite.sql downloaded successfully."
        else
            echo "❌ Failed to download learnsite.sql. Database initialization may fail."
            # 不退出，让后续步骤继续（可能已有其他文件）
        fi
    else
        echo "✓ learnsite.sql found in source."
    fi
    # ===========================================

    # 复制默认 web.config 模板到目标位置（覆盖克隆下来的 web.config）
    if [ -f "${DEFAULT_WEB_CONFIG}" ]; then
        echo "Copying default web.config template to ${TARGET_WEB_CONFIG}"
        cp "${DEFAULT_WEB_CONFIG}" "${TARGET_WEB_CONFIG}"
        echo "✓ Default web.config template copied."
    else
        echo "❌ ERROR: Default web.config not found in image. Cannot proceed."
        exit 1
    fi

    # 创建标记文件，表示首次初始化完成
    touch "${MARKER_FILE}"
    echo "✓ Initialization complete. Marker file created."
else
    echo "⏭️ Not first run (marker file exists). Skipping source update and template copy."
fi

# ========== 确保 web.config 存在（保险，如果首次运行时复制失败）==========
if [ ! -f "${TARGET_WEB_CONFIG}" ] && [ -f "${DEFAULT_WEB_CONFIG}" ]; then
    echo "⚠️ Target web.config missing. Restoring from default template..."
    cp "${DEFAULT_WEB_CONFIG}" "${TARGET_WEB_CONFIG}"
    echo "✓ Restored web.config from default template."
fi

# ========== 使用 envsubst 替换环境变量占位符 ==========
if command -v envsubst >/dev/null 2>&1; then
    echo "Applying environment variables to web.config..."
    # 使用临时文件避免同时读写
    envsubst < "${TARGET_WEB_CONFIG}" > "${TARGET_WEB_CONFIG}.tmp" && mv "${TARGET_WEB_CONFIG}.tmp" "${TARGET_WEB_CONFIG}"
    echo "✓ Environment variables applied."
else
    echo "⚠️ envsubst not found. Placeholders will remain in web.config."
fi

echo "========================================="
echo "Starting web server with configured web.config..."
echo "========================================="

exec "$@"