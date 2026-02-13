#!/bin/bash
set -e

# ========== 配置区域 ==========
REPO_URL="https://gitee.com/jnschool/learnsite-wz.git"
CUSTOM_WEB_CONFIG_URL="https://gitee.com/jnschool/game/raw/master/LearnSite_ChengDu/web.config"  # 确保是 Raw 链接
SRC_TMP="/tmp/learnsite-src"
APP_DIR="/app"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
MARKER_FILE="${APP_DIR}/.initialized"
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup (template only)"
echo "========================================="

# 检查是否为第一次运行（标记文件不存在）
if [ ! -f "${MARKER_FILE}" ]; then
    echo "🚀 First run detected. Performing initial setup..."

    # 步骤1：克隆最新源码
    echo "Cloning latest source from ${REPO_URL}..."
    git clone --depth 1 ${REPO_URL} ${SRC_TMP}

    # 步骤2：清空 /app 目录
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
        echo "✓ Downloaded custom web.config."
    else
        echo "⚠️ Failed to download custom web.config. Keeping original from source."
    fi

    # 步骤6：将 web.config 中的具体数据库连接参数替换为占位符（生成模板）
    echo "Converting web.config to template with placeholders..."
    sed -i "s/Data Source=[^;]*;/Data Source=\${DB_HOST};/" ${TARGET_WEB_CONFIG}
    sed -i "s/Initial Catalog=[^;]*;/Initial Catalog=\${DB_NAME};/" ${TARGET_WEB_CONFIG}
    sed -i "s/uid=[^;]*;/uid=\${DB_USER};/" ${TARGET_WEB_CONFIG}
    sed -i "s/pwd=[^;]*;/pwd=\${DB_PASSWORD};/" ${TARGET_WEB_CONFIG}
    echo "✓ Template created. Placeholders are now in web.config."

    # 创建标记文件
    touch "${MARKER_FILE}"
    echo "✓ Initialization complete. Marker file created."
else
    echo "⏭️ Not first run (marker file exists). Skipping source update."
fi

# 注意：不再执行 envsubst，web.config 始终保持模板状态

echo "========================================="
echo "Starting web server with template web.config..."
echo "========================================="

exec "$@"
