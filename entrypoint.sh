#!/bin/bash
set -e

# ========== 配置区域 ==========
# 主源码仓库地址（请根据您的实际仓库修改）
REPO_URL="https://github.com/RealKiro/learnsite.git"
# 应用目录（容器内）
APP_DIR="/app"
# 持久化状态目录，用于存放上次构建的commit和标记文件
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
        SRC_TMP="/tmp/learnsite-src"
        rm -rf "${SRC_TMP}"
        # 克隆最新源码（深度1，只取最新提交）
        git clone --depth 1 "${REPO_URL}" "${SRC_TMP}"

        # 清空 /app 目录，但保留 .state 目录及其内容
        find "${APP_DIR}" -mindepth 1 -not -path "${STATE_DIR}" -not -path "${STATE_DIR}/*" -delete 2>/dev/null || true

        # 将克隆的源码复制到 /app 目录
        echo "Copying source code to ${APP_DIR}..."
        # 根据仓库实际结构，支持多种可能的子目录
        if [ -d "${SRC_TMP}/LearnSiteDev" ]; then
            # 如果存在 LearnSiteDev 子目录，复制其内容
            cp -r "${SRC_TMP}/LearnSiteDev/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/LearnSiteDev/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        elif [ -d "${SRC_TMP}/src" ]; then
            # 如果存在 src 子目录
            cp -r "${SRC_TMP}/src/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/src/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        elif [ -d "${SRC_TMP}/Source" ]; then
            # 如果存在 Source 子目录
            cp -r "${SRC_TMP}/Source/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/Source/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        else
            # 否则直接复制根目录所有内容
            cp -r "${SRC_TMP}/"* "${APP_DIR}/" 2>/dev/null || true
            cp -r "${SRC_TMP}/".[!.]* "${APP_DIR}/" 2>/dev/null || true
        fi

        # 清理临时源码
        rm -rf "${SRC_TMP}"
        # 记录本次构建的 commit
        echo "${REMOTE_MAIN_COMMIT}" > "${LAST_MAIN_COMMIT_FILE}"
        echo "✓ Main source updated."
    else
        # 如果主源码未更新，但 /app 可能为空（例如卷丢失），则强制更新
        if [ ! -d "${APP_DIR}" ] || [ -z "$(ls -A "${APP_DIR}")" ]; then
            echo "⚠️ /app is empty but commit record exists. Forcing main source update."
            # 重新克隆（逻辑同上，为简化可调用自身？但直接重复代码更清晰）
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

    # 复制默认 web.config 模板到目标位置（覆盖源码中可能自带的 web.config）
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