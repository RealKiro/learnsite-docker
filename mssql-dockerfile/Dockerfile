# 基于官方 SQL Server 2025 镜像
FROM mcr.microsoft.com/mssql/server:2025-latest

# 将自定义入口脚本复制到镜像内
COPY mssql-entrypoint.sh /entrypoint.sh

# 赋予执行权限
RUN chmod +x /entrypoint.sh

# 设置自定义入口点（镜像启动时自动执行此脚本）
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口（仅为文档说明，不影响实际运行）
EXPOSE 1433