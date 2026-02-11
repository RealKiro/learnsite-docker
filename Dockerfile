FROM mono:latest

RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y mono-xsp4 ca-certificates-mono && \
    # 安装并配置中文语言环境
    sed -i 's/^# *\(zh_CN.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/*

# 设置中文环境变量
ENV LANG zh_CN.UTF-8
ENV LC_ALL zh_CN.UTF-8
ENV LANGUAGE zh_CN:zh

WORKDIR /app
COPY . .
EXPOSE 9000
CMD ["xsp4", "--port", "9000", "--nonstop", "--address", "0.0.0.0"]
