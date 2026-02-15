# 基于 Azure SQL Edge 镜像（轻量、稳定，与 SQL Server 兼容）
FROM mcr.microsoft.com/azure-sql-edge:latest

# 将自定义入口脚本复制到镜像内，并直接设置为可执行（权限 0755）
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433