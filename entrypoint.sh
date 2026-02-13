#!/bin/bash
set -e

# ========== 配置区域 ==========
REPO_URL="https://gitee.com/jnschool/learnsite-wz.git"          # 主源码仓库
CUSTOM_WEB_CONFIG_URL="https://gitee.com/jnschool/game/raw/master/LearnSite_ChengDu/web.config"  # 自定义 web.config
SRC_TMP="/tmp/learnsite-src"
APP_DIR="/app"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
MARKER_FILE="${APP_DIR}/.initialized"                           # 标记文件，存在表示已初始化
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup"
echo "========================================="

# 检查是否为第一次运行（标记文件不存在）
if [ ! -f "${MARKER_FILE}" ]; then
    echo "🚀 First run detected. Performing initial setup..."

    # 步骤1：克隆最新源码（仅最新提交，深度1）
    echo "Cloning latest source from ${REPO_URL}..."
    git clone --depth 1 ${REPO_URL} ${SRC_TMP}

    # 步骤2：清空 /app 目录（但保留目录本身）
    rm -rf ${APP_DIR}/*
    echo "✓ Cleaned ${APP_DIR}"

    # 步骤3：定位 LearnSiteDev 目录并复制内容
    if [ -d "${SRC_TMP}/LearnSiteDev" ]; then
        echo "✓ Found LearnSiteDev directory"
        cp -r ${SRC_TMP}/LearnSiteDev/* ${APP_DIR}/
        cp -r ${SRC_TMP}/LearnSiteDev/.[!.]* ${APP_DIR}/ 2>/dev/null || true
    else
        echo "⚠️ LearnSiteDev not found, copying root content..."
        cp -r ${SRC_TMP}/* ${APP_DIR}/
        cp -r ${SRC_TMP}/.[!.]* ${APP_DIR}/ 2>/dev/null || true
    fi

    # 步骤4：清理临时源码
    rm -rf ${SRC_TMP}
    echo "✓ Source update completed"

    # 步骤5：下载自定义 web.config
    echo "Downloading custom web.config from ChengDu version..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o /tmp/web.config.custom ${CUSTOM_WEB_CONFIG_URL}
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O /tmp/web.config.custom ${CUSTOM_WEB_CONFIG_URL}
    else
        echo "❌ Neither curl nor wget found. Cannot download custom web.config."
        exit 1
    fi

    if [ -s /tmp/web.config.custom ]; then
        mv /tmp/web.config.custom ${TARGET_WEB_CONFIG}
        echo "✓ Replaced web.config with ChengDu version."
    else
        echo "⚠️ Failed to download custom web.config. Keeping original from source."
    fi

    # 创建标记文件，表示初始化完成
    touch "${MARKER_FILE}"
    echo "✓ Initialization complete. Marker file created."
else
    echo "⏭️ Not first run (marker file exists). Skipping source update and web.config download."
fi

# ========== 以下步骤每次启动都会执行 ==========
# 修改数据库连接字符串（使用环境变量）
if [ -f "${TARGET_WEB_CONFIG}" ]; then
    echo "Applying database connection settings from environment variables..."
    sed -i "s/Data Source=[^;]*;/Data Source=${DB_HOST};/" ${TARGET_WEB_CONFIG}
    sed -i "s/Initial Catalog=[^;]*;/Initial Catalog=${DB_NAME};/" ${TARGET_WEB_CONFIG}
    sed -i "s/uid=[^;]*;/uid=${DB_USER};/" ${TARGET_WEB_CONFIG}
    sed -i "s/pwd=[^;]*;/pwd=${DB_PASSWORD};/" ${TARGET_WEB_CONFIG}
    echo "✓ Database connection string updated."
else
    echo "❌ Error: web.config not found at ${TARGET_WEB_CONFIG}"
    exit 1
fi

# 可选：如果需要使用 envsubst 进行通用变量替换，可以保留
if command -v envsubst >/dev/null 2>&1; then
    echo "Applying environment variables to web.config (envsubst)..."
    envsubst < "${TARGET_WEB_CONFIG}" > "${TARGET_WEB_CONFIG}.tmp" && mv "${TARGET_WEB_CONFIG}.tmp" "${TARGET_WEB_CONFIG}"
fi

echo "========================================="
echo "Starting web server..."
echo "========================================="

exec "$@"
