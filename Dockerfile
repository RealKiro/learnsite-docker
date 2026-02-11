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

# ========== 4. 安装 curl（用于 Docker 健康检查）==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*

# ========== 5. 安装中文字体（解决界面/PDF/图片中文方块）==========
RUN apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y --no-install-recommends \
        fonts-wqy-microhei \
        fonts-wqy-zenhei && \
    rm -rf /var/lib/apt/lists/*

# ========== 6. 设置中文环境变量 ==========
ENV LANG zh_CN.UTF-8
ENV LANGUAGE zh_CN:zh
ENV LC_ALL zh_CN.UTF-8

# ========== 7. 应用目录和启动配置 ==========
WORKDIR /app
COPY . .
EXPOSE 9000
CMD ["xsp4", "--port", "9000", "--nonstop", "--address", "0.0.0.0"]
