#!/bin/bash
set -e

# 将 web.config 中的所有 ${VAR_NAME} 替换为环境变量的值
# 使用 envsubst 命令（需要安装 gettext-base）
if command -v envsubst >/dev/null 2>&1; then
    echo "Applying environment variables to web.config..."
    envsubst < /app/web.config > /app/web.config.tmp && mv /app/web.config.tmp /app/web.config
else
    echo "Warning: envsubst not found, skipping variable substitution."
fi

# 执行原命令（启动 xsp4）
exec "$@"
