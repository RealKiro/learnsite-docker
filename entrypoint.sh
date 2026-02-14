#!/bin/bash
set -e

# ========== 配置区域 ==========
APP_DIR="/app"
TARGET_WEB_CONFIG="${APP_DIR}/web.config"
DEFAULT_WEB_CONFIG="/usr/local/share/default-web.config"
# ==============================

echo "========================================="
echo "Starting LearnSite (build-time source control)"
echo "========================================="

# 确保 web.config 存在（如果缺失则从默认模板恢复）
if [ ! -f "${TARGET_WEB_CONFIG}" ]; then
    echo "⚠️ web.config not found. Restoring from default template..."
    if [ -f "${DEFAULT_WEB_CONFIG}" ]; then
        cp "${DEFAULT_WEB_CONFIG}" "${TARGET_WEB_CONFIG}"
        echo "✓ Default web.config restored."
    else
        echo "❌ ERROR: Default web.config missing in image!"
        exit 1
    fi
fi

# 使用 envsubst 替换环境变量占位符
if command -v envsubst >/dev/null 2>&1; then
    echo "Applying environment variables to web.config..."
    envsubst < "${TARGET_WEB_CONFIG}" > "${TARGET_WEB_CONFIG}.tmp" && mv "${TARGET_WEB_CONFIG}.tmp" "${TARGET_WEB_CONFIG}"
    echo "✓ Environment variables applied."
else
    echo "⚠️ envsubst not found. Placeholders will remain in web.config."
fi

echo "========================================="
echo "Starting web server..."
echo "========================================="

exec "$@"