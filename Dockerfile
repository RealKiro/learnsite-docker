FROM mono:latest

RUN echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get install -y mono-xsp4 ca-certificates-mono && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .
EXPOSE 9000
CMD ["xsp4", "--port", "9000", "--nonstop", "--address", "0.0.0.0"]
