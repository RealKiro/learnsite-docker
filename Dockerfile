FROM mono:latest

# ========== 基础环境配置 ==========
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list

RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y mono-xsp4 ca-certificates-mono locales curl fonts-wqy-* tzdata git gettext-base && \
    locale-gen zh_CN.UTF-8 && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Shanghai
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

# ========== 构建时源码拉取开关 ==========
# 构建参数 UPDATE_SOURCE：1=从 Git 拉取最新源码；0=不拉取（使用镜像内置源码或留空）
ARG UPDATE_SOURCE=0
# 源码仓库地址（可自定义）
ARG PRIMARY_REPO_URL="https://github.com/RealKiro/learnsite.git"
ARG FALLBACK_REPO_URL="https://gitee.com/realiy/learnsite.git"

WORKDIR /tmp

RUN if [ "$UPDATE_SOURCE" = "1" ]; then \
        echo "🚀 UPDATE_SOURCE=1：尝试从 GitHub 克隆最新源码..." && \
        (git clone --depth 1 ${PRIMARY_REPO_URL} /app || \
         (echo "⚠️ GitHub 克隆失败，尝试从 Gitee 备用仓库..." && \
          git clone --depth 1 ${FALLBACK_REPO_URL} /app)) || \
        { echo "❌ 错误：所有仓库克隆失败，请检查网络或仓库地址。"; exit 1; }; \
    else \
        echo "⏸️ UPDATE_SOURCE=0：使用镜像内置的默认源码（如果有）或跳过源码拉取。"; \
        mkdir -p /app; \
    fi

# ========== 复制默认 web.config 模板 ==========
COPY web.config /usr/local/share/default-web.config

# ========== 复制 entrypoint 脚本 ==========
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["xsp4", "--port", "8080", "--nonstop", "--address", "0.0.0.0"]