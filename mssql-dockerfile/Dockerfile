# 基于 Azure SQL Edge 镜像（轻量、稳定）
FROM mcr.microsoft.com/azure-sql-edge:latest

# 安装 gosu（用于从 root 切换到普通用户）
# 先创建 apt 需要的目录，然后更新并安装 gosu
RUN mkdir -p /var/lib/apt/lists/partial && \
    apt-get update && \
    apt-get install -y gosu && \
    rm -rf /var/lib/apt/lists/*

# 将自定义入口脚本复制到镜像内，并直接设置为可执行
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 确保镜像默认以 root 用户运行，以便 entrypoint 可以创建系统目录和调整权限
USER root

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433