#!/bin/bash
set -e

# ========== 配置区域 ==========
REPO_URL="https://gitee.com/jnschool/learnsite-wz.git"          # 主源码仓库
APP_DIR="/app"
STATE_DIR="${APP_DIR}/.state"                                    # 持久化状态目录
LAST_MAIN_COMMIT_FILE="${STATE_DIR}/last_main_commit"            # 上次主源码 commit
MARKER_FILE="${APP_DIR}/.initialized"                            # 初始化标记

# 本地 web.config 路径（与 entrypoint.sh 同目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_WEB_CONFIG="${SCRIPT_DIR}/web.config"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup (with local web.config)"
echo "========================================="

# 确保状态目录存在
mkdir -p "${STATE_DIR}"

# 函数：获取远程主仓库最新 commit
get_remote_main_commit() {
    git ls-remote "${REPO_URL}" HEAD | cut -f1
}

# 检查是否为第一次运行（标记文件不存在）
if [ ! -f "${MARKER_FILE}" ]; then
    echo "🚀 First run detected. Checking for existing valid source..."

    # 读取上次记录的 commit
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
        SRC_TMP="/tmp/learnsite-src"
        rm -rf "${SRC_TMP}"
        git clone --depth 1 "${REPO_URL}" "${SRC_TMP}"

        # 清空 /app 但保留状态目录和标记文件（当前标记文件还不存在，所以无需特别保留）
        find "${APP_DIR}" -mindepth 1 -not -path "${STATE_DIR}" -not -path "${STATE_DIR}/*" -delete 2>/dev/null || true

        # 复制新源码
        if [ -d "${SRC_TMP}/LearnSiteDev" ]; then
            cp -r "${SRC_TMP}/LearnSiteDev/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/LearnSiteDev/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        else
            cp -r "${SRC_TMP}/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        fi

        rm -rf "${SRC_TMP}"
        echo "${REMOTE_MAIN_COMMIT}" > "${LAST_MAIN_COMMIT_FILE}"
        echo "✓ Main source updated."
    else
        # 如果主源码未更新，但 /app 可能为空（例如卷丢失），则强制更新
        if [ ! -d "${APP_DIR}" ] || [ -z "$(ls -A "${APP_DIR}")" ]; then
            echo "⚠️ /app is empty but commit record exists. Forcing main source update."
            # 简单重新克隆（可复用上面逻辑，为简洁直接调用自身？但避免递归，重复代码）
            SRC_TMP="/tmp/learnsite-src"
            git clone --depth 1 "${REPO_URL}" "${SRC_TMP}"
            find "${APP_DIR}" -mindepth 1 -not -path "${STATE_DIR}" -not -path "${STATE_DIR}/*" -delete 2>/dev/null || true
            if [ -d "${SRC_TMP}/LearnSiteDev" ]; then
                cp -r "${SRC_TMP}/LearnSiteDev/"* "${APP_DIR}/" 2>/dev/null || true
                cp -r "${SRC_TMP}/LearnSiteDev/".[!.]* "${APP_DIR}/" 2>/dev/null || true
            else
                cp -r "${SRC_TMP}/"* "${APP_DIR}/" 2>/dev/null || true
                cp -r "${SRC_TMP}/".[!.]* "${APP_DIR}/" 2>/dev/null || true
            fi
            rm -rf "${SRC_TMP}"
            echo "${REMOTE_MAIN_COMMIT}" > "${LAST_MAIN_COMMIT_FILE}"
        fi
    fi

    # 从本地复制 web.config
    if [ -f "${LOCAL_WEB_CONFIG}" ]; then
        echo "Copying local web.config to ${TARGET_WEB_CONFIG}"
        cp "${LOCAL_WEB_CONFIG}" "${TARGET_WEB_CONFIG}"
        echo "✓ Local web.config copied."
    else
        echo "⚠️ Local web.config not found at ${LOCAL_WEB_CONFIG}. Searching for default in source..."
        # 从源码中查找默认 web.config 并复制
        find "${APP_DIR}" -name "web.config" -type f -print -quit | while read -r default_config; do
            cp "${default_config}" "${TARGET_WEB_CONFIG}"
            echo "✓ Copied default web.config from source."
        done
    fi

    # 如果 web.config 存在，将其转换为模板（占位符）
    # if [ -f "${TARGET_WEB_CONFIG}" ]; then
    #     echo "Converting web.config to template with placeholders..."
    #     sed -i "s/Data Source=[^;]*;/Data Source=\${DB_HOST};/" "${TARGET_WEB_CONFIG}"
    #     sed -i "s/Initial Catalog=[^;]*;/Initial Catalog=\${DB_NAME};/" "${TARGET_WEB_CONFIG}"
    #     sed -i "s/uid=[^;]*;/uid=\${DB_USER};/" "${TARGET_WEB_CONFIG}"
    #     sed -i "s/pwd=[^;]*;/pwd=\${DB_PASSWORD};/" "${TARGET_WEB_CONFIG}"
    #     echo "✓ Template created."
    # else
    #     echo "❌ Error: web.config not found after all attempts."
    #     exit 1
    # fi

    # 创建标记文件
    touch "${MARKER_FILE}"
    echo "✓ Initialization complete. Marker file created."
else
    echo "⏭️ Not first run (marker file exists). Skipping source update and template generation."
fi

echo "========================================="
echo "Starting web server with template web.config..."
echo "========================================="
exec "$@"
