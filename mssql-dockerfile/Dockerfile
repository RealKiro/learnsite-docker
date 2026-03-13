# 基于 Azure SQL Edge 镜像（轻量、稳定）
FROM mcr.microsoft.com/azure-sql-edge:latest

# 将自定义入口脚本复制到镜像内，并直接设置为可执行
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 以 root 用户运行（默认已经是 root，但显式声明一下）
USER root

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433