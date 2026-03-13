# web.Dockerfile
# 基于 .NET SDK 的 Alpine 镜像，体积小，支持中文
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build

# 安装并配置中文环境
RUN apk add --no-cache icu-libs ttf-dejavu && \
    echo "export LANG=zh_CN.UTF-8" >> /etc/profile && \
    echo "export LANGUAGE=zh_CN.UTF-8" >> /etc/profile && \
    echo "export LC_ALL=zh_CN.UTF-8" >> /etc/profile

ENV LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8

WORKDIR /app
COPY . .

# 发布应用
RUN dotnet publish -c Release -o out

# 运行时镜像
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine
WORKDIR /app
COPY --from=build /app/out .

# 安装 curl（用于健康检查）
RUN apk add --no-cache curl

ENV LANG=zh_CN.UTF-8 \
    LANGUAGE=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8

EXPOSE 8080
ENTRYPOINT ["dotnet", "YourWebApp.dll"]   # 请替换为实际程序集名称