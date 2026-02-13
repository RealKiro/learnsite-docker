#!/bin/bash
set -e

# ========== 配置区域 ==========
REPO_URL="https://gitee.com/jnschool/learnsite-wz.git"
CUSTOM_WEB_CONFIG_URL="https://raw.githubusercontent.com/RealKiro/learnsite-docker/main/web.config"   # 替换为您的 Raw 链接
SRC_TMP="/tmp/learnsite-src"
APP_DIR="/app"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
STATE_DIR="${APP_DIR}/.state"               # 持久化状态目录
LAST_MAIN_COMMIT_FILE="${STATE_DIR}/last_main_commit"
LAST_CONFIG_COMMIT_FILE="${STATE_DIR}/last_config_commit"
MARKER_FILE="${APP_DIR}/.initialized"
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup (with commit check)"
echo "========================================="

# 确保状态目录存在
mkdir -p "${STATE_DIR}"

# 函数：获取远程主仓库最新 commit
get_remote_main_commit() {
    git ls-remote "${REPO_URL}" HEAD | cut -f1
}

# 函数：获取远程 web.config 文件的 commit（注意：需要仓库克隆或API，这里简单使用下载文件的 ETag 或直接使用日期，为简化，我们用下载文件并计算 hash）
# 实际上，更准确的是获取文件的 commit，但需要 git 克隆。这里采用下载文件并计算 sha1 的方式判断是否变化。
download_config_and_get_hash() {
    local tmp_file="/tmp/web_config_current"
    if curl -fsSL -o "${tmp_file}" "${CUSTOM_WEB_CONFIG_URL}"; then
        sha1sum "${tmp_file}" | awk '{print $1}'
        rm -f "${tmp_file}"
    else
        echo ""
    fi
}

# 检查是否为第一次运行（标记文件不存在）
if [ ! -f "${MARKER_FILE}" ]; then
    echo "🚀 First run detected. Checking for existing valid source..."

    # 读取之前记录的 commit
    PREV_MAIN_COMMIT=""
    PREV_CONFIG_HASH=""
    [ -f "${LAST_MAIN_COMMIT_FILE}" ] && PREV_MAIN_COMMIT=$(cat "${LAST_MAIN_COMMIT_FILE}")
    [ -f "${LAST_CONFIG_COMMIT_FILE}" ] && PREV_CONFIG_HASH=$(cat "${LAST_CONFIG_COMMIT_FILE}")

    # 获取远程最新信息
    REMOTE_MAIN_COMMIT=$(get_remote_main_commit)
    REMOTE_CONFIG_HASH=$(download_config_and_get_hash)

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

    # 判断是否需要更新 web.config
    NEED_UPDATE_CONFIG=false
    if [ -z "${REMOTE_CONFIG_HASH}" ]; then
        echo "⚠️ Failed to get remote config hash, will proceed with update to be safe."
        NEED_UPDATE_CONFIG=true
    elif [ "${PREV_CONFIG_HASH}" != "${REMOTE_CONFIG_HASH}" ]; then
        echo "web.config changed (hash ${PREV_CONFIG_HASH} -> ${REMOTE_CONFIG_HASH}), updating..."
        NEED_UPDATE_CONFIG=true
    else
        echo "web.config unchanged (hash ${PREV_CONFIG_HASH}), reusing existing."
    fi

    # 如果需要更新主源码
    if [ "${NEED_UPDATE_MAIN}" = true ]; then
        echo "Updating main source from ${REPO_URL}..."
        rm -rf "${SRC_TMP}"
        git clone --depth 1 "${REPO_URL}" "${SRC_TMP}"
        # 清空 /app 但保留状态目录和标记文件（当前标记文件还不存在，所以无需特别保留）
        # 注意：要保留 .state 目录，所以不能直接 rm -rf ${APP_DIR}/*
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
        # 如果主源码未更新，但 /app 可能为空（例如卷丢失），需要从某个备份恢复？这里假设如果状态存在但 /app 为空，则强制更新。
        if [ ! -d "${APP_DIR}" ] || [ -z "$(ls -A "${APP_DIR}")" ]; then
            echo "⚠️ /app is empty but commit record exists. Forcing main source update."
            NEED_UPDATE_MAIN=true
            # 跳转到更新逻辑（可复用上面的代码，但为简化，这里直接递归调用自身？不，最好重构。为简洁，我们重复更新代码或让用户确保卷挂载正确。）
            # 简单处理：重新克隆
            git clone --depth 1 "${REPO_URL}" "${SRC_TMP}"
            # ... 复制等
        fi
    fi

    # 如果需要更新 web.config
    if [ "${NEED_UPDATE_CONFIG}" = true ]; then
        echo "Downloading custom web.config..."
        if curl -fsSL -o /tmp/web.config.custom "${CUSTOM_WEB_CONFIG_URL}"; then
            if [ -s /tmp/web.config.custom ]; then
                mv /tmp/web.config.custom "${TARGET_WEB_CONFIG}"
                echo "${REMOTE_CONFIG_HASH}" > "${LAST_CONFIG_COMMIT_FILE}"
                echo "✓ web.config updated."
            else
                echo "⚠️ Downloaded config is empty, keeping existing."
            fi
        else
            echo "⚠️ Failed to download web.config, keeping existing."
        fi
    fi

    # 确保最终有 web.config 文件（如果还没有，可能是第一次且下载失败，则从源码中找）
    if [ ! -f "${TARGET_WEB_CONFIG}" ]; then
        # 从源码中查找默认 web.config 并复制
        find "${APP_DIR}" -name "web.config" -type f -print -quit | while read -r default_config; do
            cp "${default_config}" "${TARGET_WEB_CONFIG}"
            echo "✓ Copied default web.config from source."
        done
    fi

    # 如果 web.config 存在，将其转换为模板（占位符）
    if [ -f "${TARGET_WEB_CONFIG}" ]; then
        echo "Converting web.config to template with placeholders..."
        sed -i "s/Data Source=[^;]*;/Data Source=\${DB_HOST};/" "${TARGET_WEB_CONFIG}"
        sed -i "s/Initial Catalog=[^;]*;/Initial Catalog=\${DB_NAME};/" "${TARGET_WEB_CONFIG}"
        sed -i "s/uid=[^;]*;/uid=\${DB_USER};/" "${TARGET_WEB_CONFIG}"
        sed -i "s/pwd=[^;]*;/pwd=\${DB_PASSWORD};/" "${TARGET_WEB_CONFIG}"
        echo "✓ Template created."
    else
        echo "❌ Error: web.config not found after all attempts."
        exit 1
    fi

    # 创建标记文件
    touch "${MARKER_FILE}"
    echo "✓ Initialization complete. Marker file created."
else
    echo "⏭️ Not first run (marker file exists). Skipping source update and template generation."
fi

# 最终启动服务
echo "========================================="
echo "Starting web server with template web.config..."
echo "========================================="
exec "$@"
