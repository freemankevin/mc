# MinIO 站点复制管理工具

[![Docker Publish](https://github.com/freemankevin/mc/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/your-username/mc/actions/workflows/docker-publish.yml)

## 项目简介

这是一个用于初始化和管理 MinIO 多站点复制配置。该工具具有以下特点：

- 🚀 自动化配置：一键完成 MinIO 站点复制的初始化
- 🔄 健康检查：自动检测服务可用性
- 🧹 配置清理：安全地清理现有复制配置
- 📡 状态监控：实时显示复制状态
- 🎨 美观的界面：彩色输出和进度显示

## 环境要求

- Docker 环境
- MinIO 服务器（至少两个站点）

## 快速开始

### 使用 Docker 运行

```bash
# 拉取镜像
docker pull ghcr.io/freemankevin/mc:latest
```

### 使用 Docker Compose

```yaml
services:
  minio:
    image: "${MINIO_IMAGE}"
    deploy:
      resources:
        limits:
          memory: 4096M
    networks:
      - middleware 
    container_name: minio
    ports:
      - "${MINIO_PORT}:9000"
      - "${MINIO_CONSOLE_PORT}:9001"
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: "${MINIO_ROOT_USER}"
      MINIO_ROOT_PASSWORD: "${MINIO_ROOT_PASSWORD}"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./data/minio/data:/data
    restart: always

  mc:
    image: ghcr.io/freemankevin/mc:latest
    container_name: mc
    networks:
      - middleware 
    environment:
      SITE1_URL: "${SITE1_URL}"
      SITE2_URL: "${SITE2_URL}"
      MINIO_ROOT_USER: "${MINIO_ROOT_USER}"
      MINIO_ROOT_PASSWORD: "${MINIO_ROOT_PASSWORD}"
    volumes:
      - ./site-replication.sh:/site-replication.sh
    entrypoint: ["/bin/bash", "/site-replication.sh"]
    healthcheck:
      test: ["CMD-SHELL", "mc --version >/dev/null 2>&1"]
      interval: 30s
      timeout: 10s
      start_period: 10s
      retries: 3
    restart: always

networks:
  middleware:
    driver: bridge
```

## 环境变量配置

| 变量名 | 描述 | 示例值 | 必填 |
|--------|------|--------|------|
| MINIO_PORT | MinIO 服务端口 | 9000 | 是 |
| MINIO_CONSOLE_PORT | MinIO 控制台端口 | 9001 | 是 |
| MINIO_ROOT_USER | MinIO 管理员用户名 | admin | 是 |
| MINIO_ROOT_PASSWORD | MinIO 管理员密码 | Admin@123.com | 是 |
| MINIO_IMAGE | MinIO 镜像版本 | minio/minio:RELEASE.2025-04-22T22-12-26Z | 是 |
| SITE1_URL | 第一个 MinIO 站点的 URL | http://192.168.199.145:9000 | 是 |
| SITE2_URL | 第二个 MinIO 站点的 URL | http://192.168.199.147:9000 | 是 |


## 功能说明

### 1. 服务健康检查
- 自动检测 MinIO 服务可用性
- 重试机制确保服务就绪
- 优雅的进度显示

### 2. 站点别名配置
- 自动设置站点别名
- 安全的凭证管理
- 清晰的状态反馈

### 3. 复制配置管理
- 安全清理现有配置
- 自动设置站点复制
- 详细的状态验证

## 贡献指南

欢迎提交 Issue 和 Pull Request 来帮助改进这个项目。

## 许可证

本项目采用 Apache-2.0 许可证 - 详见 [LICENSE](LICENSE) 文件。