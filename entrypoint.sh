#!/bin/bash
set -e

# ========== 配置区域 ==========
REPO_URL="https://github.com/RealKiro/learnsite.git"          # 主仓库地址
APP_DIR="/app"
STATE_DIR="${APP_DIR}/.state"                                  # 持久化状态目录
LAST_MAIN_COMMIT_FILE="${STATE_DIR}/last_main_commit"          # 上次主源码 commit
MARKER_FILE="${APP_DIR}/.initialized"                          # 初始化标记
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
DEFAULT_WEB_CONFIG="/usr/local/share/default-web.config"       # 镜像内的默认备份
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup (with envsubst)"
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

        # 复制新源码（根据仓库结构灵活处理）
        if [ -d "${SRC_TMP}/LearnSiteDev" ]; then
            cp -r "${SRC_TMP}/LearnSiteDev/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/LearnSiteDev/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        elif [ -d "${SRC_TMP}/src" ]; then
            cp -r "${SRC_TMP}/src/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/src/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        elif [ -d "${SRC_TMP}/Source" ]; then
            cp -r "${SRC_TMP}/Source/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/Source/".[!.]* "${APP_DIR}/" 2>/dev/null || true
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
            SRC_TMP="/tmp/learnsite-src"
            git clone --depth 1 "${REPO_URL}" "${SRC_TMP}"
            find "${APP_DIR}" -mindepth 1 -not -path "${STATE_DIR}" -not -path "${STATE_DIR}/*" -delete 2>/dev/null || true
            if [ -d "${SRC_TMP}/LearnSiteDev" ]; then
                cp -r "${SRC_TMP}/LearnSiteDev/"* "${APP_DIR}/" 2>/dev/null || true
                cp -r "${SRC_TMP}/LearnSiteDev/".[!.]* "${APP_DIR}/" 2>/dev/null || true
            elif [ -d "${SRC_TMP}/src" ]; then
                cp -r "${SRC_TMP}/src/"* "${APP_DIR}/" 2>/dev/null || true
                cp -r "${SRC_TMP}/src/".[!.]* "${APP_DIR}/" 2>/dev/null || true
            elif [ -d "${SRC_TMP}/Source" ]; then
                cp -r "${SRC_TMP}/Source/"* "${APP_DIR}/" 2>/dev/null || true
                cp -r "${SRC_TMP}/Source/".[!.]* "${APP_DIR}/" 2>/dev/null || true
            else
                cp -r "${SRC_TMP}/"* "${APP_DIR}/" 2>/dev/null || true
                cp -r "${SRC_TMP}/".[!.]* "${APP_DIR}/" 2>/dev/null || true
            fi
            rm -rf "${SRC_TMP}"
            echo "${REMOTE_MAIN_COMMIT}" > "${LAST_MAIN_COMMIT_FILE}"
        fi
    fi

    # 创建标记文件（表示首次初始化完成）
    touch "${MARKER_FILE}"
    echo "✓ Initialization complete. Marker file created."
else
    echo "⏭️ Not first run (marker file exists). Skipping source update."
fi

# ========== 确保 web.config 存在（如果缺失则从默认备份恢复）==========
if [ ! -f "${TARGET_WEB_CONFIG}" ]; then
    echo "⚠️ Target web.config not found. Restoring from default template..."
    if [ -f "${DEFAULT_WEB_CONFIG}" ]; then
        cp "${DEFAULT_WEB_CONFIG}" "${TARGET_WEB_CONFIG}"
        echo "✓ Restored web.config from default template."
    else
        echo "❌ ERROR: Default web.config not found in image. Cannot proceed."
        exit 1
    fi
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
