#!/bin/bash
set -e

# ========== 配置区域 ==========
REPO_URL="https://gitee.com/jnschool/learnsite-wz.git"   # 原源码仓库
CUSTOM_WEB_CONFIG_URL="https://gitee.com/jnschool/game/raw/master/LearnSite_ChengDu/web.config"  # 替换为实际的 Raw 链接
SRC_TMP="/tmp/learnsite-src"
APP_DIR="/app"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
# ==============================

echo "========================================="
echo "Starting LearnSite dynamic setup"
echo "========================================="

# 步骤1：克隆最新源码（仅最新提交，深度1）
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

# ===== 新增步骤：下载并替换 web.config =====
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
# ===========================================

# 步骤5：修改数据库连接字符串（适用于最终使用的 web.config）
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

echo "========================================="
echo "Starting web server..."
echo "========================================="

exec "$@"
