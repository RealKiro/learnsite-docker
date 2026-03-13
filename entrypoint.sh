#!/bin/bash
set -e
exec > /proc/1/fd/1 2>&1

# ========== PUID/PGID 权限处理 ==========
# 从环境变量获取 PUID 和 PGID，如果未设置则使用默认值 1000
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# 创建或修改用户和组
echo "--- Setting up user and group with UID:GID $PUID:$PGID ---"
# 检查组是否存在，若不存在则创建
if ! getent group appgroup > /dev/null 2>&1; then
    groupadd -g $PGID appgroup
else
    # 如果组存在但GID不匹配，修改它（简化处理，实际可能需要更复杂的逻辑）
    groupmod -g $PGID appgroup 2>/dev/null || true
fi

# 检查用户是否存在，若不存在则创建
if ! getent passwd appuser > /dev/null 2>&1; then
    useradd -u $PUID -g $PGID -m appuser
else
    usermod -u $PUID -g $PGID appuser 2>/dev/null || true
fi

# 关键步骤：将整个数据目录的权限更改为新创建的用户
# 这解决了即使目录在宿主机上权限不对，容器启动时也能尝试修复的问题
echo "--- Adjusting ownership of /var/opt/mssql ---"
chown -R $PUID:$PGID /var/opt/mssql

# 如果还需要其他目录，可以继续添加
# chown -R $PUID:$PGID /another/path

# ========== 后续步骤 ==========
# ... (等待 SQL Server 启动、下载 SQL 文件等逻辑) ...

# 注意：最终必须以非 root 用户运行 SQL Server
# 使用 gosu 或 su-exec 切换到新用户启动主进程
# 假设您已经安装了 gosu
echo "--- Starting SQL Server as appuser (UID: $PUID) ---"
exec gosu appuser /opt/mssql/bin/sqlservr