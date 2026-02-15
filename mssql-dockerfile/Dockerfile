# 基于 SQL Server 2019 官方镜像（更稳定）
FROM mcr.microsoft.com/mssql/server:2019-latest

# 将自定义入口脚本复制到镜像内，并直接设置为可执行（权限 0755）
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433