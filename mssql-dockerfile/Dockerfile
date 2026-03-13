# 基于 Azure SQL Edge 镜像（轻量、稳定）
FROM mcr.microsoft.com/azure-sql-edge:latest

# 下载 gosu 二进制到临时目录并安装
RUN wget -O /tmp/gosu "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" \
    && chmod +x /tmp/gosu \
    && mv /tmp/gosu /usr/local/bin/gosu

# 将自定义入口脚本复制到镜像内，并直接设置为可执行
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 确保镜像默认以 root 用户运行，以便 entrypoint 可以创建系统目录和调整权限
USER root

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433