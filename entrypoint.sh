#!/bin/bash
set -e

echo "✅ MinIO Client 工具镜像启动完成"
echo "👉 可在容器中使用 mc 命令"
echo "🔁 容器将保持挂起运行，可用于运行初始化脚本或调试"

tail -f /dev/null
