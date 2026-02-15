# 基于 SQL Server 2019 官方镜像（更稳定）
FROM mcr.microsoft.com/mssql/server:2019-latest

# 将自定义入口脚本复制到镜像内
COPY mssql-entrypoint.sh /entrypoint.sh

# 赋予执行权限
RUN chmod +x /entrypoint.sh

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433