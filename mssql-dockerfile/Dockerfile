# 基于 Azure SQL Edge 镜像（轻量、稳定）
FROM mcr.microsoft.com/azure-sql-edge:latest

# 关键修复：手动创建 APT 需要的目录（解决 CI 中 /var/lib/apt/lists/partial 缺失错误）
USER root
RUN mkdir -p /var/lib/apt/lists/partial

# 安装 gosu（用于从 root 切换到普通用户）
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

# 将自定义入口脚本复制到镜像内，并直接设置为可执行
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

# 暴露 SQL Server 默认端口
EXPOSE 1433