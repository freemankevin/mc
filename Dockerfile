FROM minio/mc:latest

# 安装常用工具
RUN dnf install -y \
    curl \
    bash \
    sed \
    gawk \
    iputils \
    jq \
    nc \
    coreutils \
    bind-utils \
    && dnf clean all

# 添加入口脚本  
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
