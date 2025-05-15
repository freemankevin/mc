FROM alpine:latest

# 安装工具
RUN apk add --no-cache \
    curl \
    bash \
    sed \
    gawk \
    iputils \
    jq \
    netcat-openbsd \
    coreutils \
    bind-tools

# 安装 mc 客户端
RUN case $(uname -m) in \
        x86_64) ARCH=amd64 ;; \
        aarch64) ARCH=arm64 ;; \
        *) echo "Unsupported architecture"; exit 1 ;; \
    esac && \
    curl -sSL https://dl.min.io/client/mc/release/linux-${ARCH}/mc -o /usr/bin/mc && \
    chmod +x /usr/bin/mc

# 添加入口脚本  
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
