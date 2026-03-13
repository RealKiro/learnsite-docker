# 基于 Mono 最新镜像
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

# ========== 复制默认 web.config 模板 ==========
COPY web.config /usr/local/share/default-web.config

# ========== 复制 entrypoint 脚本 ==========
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["xsp4", "--port", "8080", "--nonstop", "--address", "0.0.0.0"]