FROM mono:latest

# ========== 1. 配置 APT 源（使用 archive.debian.org）==========
RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list

# ========== 2. 安装 Mono 基础组件（xsp4）==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y mono-xsp4 ca-certificates-mono && \
    rm -rf /var/lib/apt/lists/*

# ========== 3. 安装 locales 并生成中文语言环境 ==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y locales && \
    sed -i 's/^# *\(zh_CN.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen zh_CN.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# ========== 4. 安装 curl（健康检查/调试）==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# ========== 5. 安装中文字体（解决界面/PDF/图片中文方块）==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends \
        fonts-wqy-microhei \
        fonts-wqy-zenhei && \
    rm -rf /var/lib/apt/lists/*

# ========== 6. 安装 tzdata 并设置时区（支持 TZ 环境变量）==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y tzdata && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

ENV TZ=Asia/Shanghai

# ========== 7. 安装 git（用于启动时拉取源码）==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*

# ========== 8. 设置中文环境变量 ==========
ENV LANG=zh_CN.UTF-8
ENV LANGUAGE=zh_CN:zh
ENV LC_ALL=zh_CN.UTF-8

# ========== 9. 复制 entrypoint 预处理脚本 ==========
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# ========== 10. 应用目录和启动配置 ==========
WORKDIR /app
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["xsp4", "--port", "8080", "--nonstop", "--address", "0.0.0.0"]
