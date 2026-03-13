# mssql-dockerfile/Dockerfile
FROM mcr.microsoft.com/azure-sql-edge:latest

# ========== 关键修复：手动创建 APT 需要的目录 ==========
# 这解决了之前 CI 中 "/var/lib/apt/lists/partial is missing" 的错误
USER root
RUN mkdir -p /var/lib/apt/lists/partial

# ========== 安装 gosu（用于从 root 切换到普通用户）==========
# 先更新源（现在目录存在了），再安装 gosu
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

# 将自定义入口脚本复制到镜像内
COPY --chmod=0755 mssql-entrypoint.sh /entrypoint.sh

# 设置自定义入口点
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 1433