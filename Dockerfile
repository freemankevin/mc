FROM alpine:latest

# 安装常用工具 和 MinIO 客户端
RUN apk add --no-cache \
    curl \
    bash \
    sed \
    gawk \
    iputils \
    jq \
    netcat-openbsd \
    coreutils \
    bind-tools \
    && curl -sSL https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/bin/mc \
    && chmod +x /usr/bin/mc

# 添加入口脚本  
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
