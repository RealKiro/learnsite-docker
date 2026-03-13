# 基于 Azure SQL Edge 镜像（轻量、稳定）
FROM mcr.microsoft.com/azure-sql-edge:latest

# 切换到 root 用户以确保安装权限
USER root

# 下载 gosu 二进制到临时目录并安装
RUN wget -O /tmp/gosu "https://github.com/tianon/gosu/releases/download/1.14/gosu-amd64" \
    && chmod +x /tmp/gosu \
    && mv /tmp/gosu /usr/local/bin/gosu

# 将自定义入口脚本复制到镜像内，并直接设置为可执行
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433