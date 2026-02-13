#!/bin/bash
set -e

# ========== 配置区域 ==========
REPO_URL="https://gitee.com/jnschool/learnsite-wz.git"
CUSTOM_WEB_CONFIG_URL="https://gitee.com/jnschool/game/raw/master/LearnSite_ChengDu/web.config"
SRC_TMP="/tmp/learnsite-src"
APP_DIR="/app"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
TEMPLATE_WEB_CONFIG="${APP_DIR}/web.config.template"
MARKER_FILE="${APP_DIR}/.initialized"
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup"
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

    # 步骤6：创建模板文件并替换具体值为占位符
    cp ${TARGET_WEB_CONFIG} ${TEMPLATE_WEB_CONFIG}
    echo "✓ Created template file: ${TEMPLATE_WEB_CONFIG}"

    # 将模板中的具体数据库连接参数替换为占位符
    # 注意：如果原始 web.config 格式不同，请调整下面的正则表达式
    sed -i "s/Data Source=[^;]*;/Data Source=\${DB_HOST};/" ${TEMPLATE_WEB_CONFIG}
    sed -i "s/Initial Catalog=[^;]*;/Initial Catalog=\${DB_NAME};/" ${TEMPLATE_WEB_CONFIG}
    sed -i "s/uid=[^;]*;/uid=\${DB_USER};/" ${TEMPLATE_WEB_CONFIG}
    sed -i "s/pwd=[^;]*;/pwd=\${DB_PASSWORD};/" ${TEMPLATE_WEB_CONFIG}
    echo "✓ Replaced connection string values with placeholders in template."

    # 创建标记文件
    touch "${MARKER_FILE}"
    echo "✓ Initialization complete. Marker file created."
else
    echo "⏭️ Not first run (marker file exists). Skipping source update and template creation."
fi

# ========== 每次启动都会执行的步骤 ==========
# 从模板生成最终的 web.config（使用环境变量替换占位符）
if [ -f "${TEMPLATE_WEB_CONFIG}" ]; then
    echo "Generating final web.config from template using envsubst..."
    if command -v envsubst >/dev/null 2>&1; then
        envsubst < "${TEMPLATE_WEB_CONFIG}" > "${TARGET_WEB_CONFIG}"
        echo "✓ Final web.config generated."
    else
        echo "⚠️ envsubst not found. Falling back to direct sed replacement on web.config."
        # 后备方案：直接修改 web.config（可能不精确，但避免失败）
        sed -i "s/Data Source=[^;]*;/Data Source=${DB_HOST};/" ${TARGET_WEB_CONFIG}
        sed -i "s/Initial Catalog=[^;]*;/Initial Catalog=${DB_NAME};/" ${TARGET_WEB_CONFIG}
        sed -i "s/uid=[^;]*;/uid=${DB_USER};/" ${TARGET_WEB_CONFIG}
        sed -i "s/pwd=[^;]*;/pwd=${DB_PASSWORD};/" ${TARGET_WEB_CONFIG}
    fi
else
    echo "❌ Error: Template file ${TEMPLATE_WEB_CONFIG} not found!"
    exit 1
fi

# 可选：如果需要用 envsubst 处理其他文件，可以在这里添加

echo "========================================="
echo "Starting web server..."
echo "========================================="

exec "$@"
