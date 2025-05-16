#!/bin/bash

# 严格模式：错误、未定义变量、管道失败时退出
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# 更丰富的图标集
ICON_INFO="🌐"
ICON_SUCCESS="✨"
ICON_WARNING="⚠️"
ICON_ERROR="💥"
ICON_DEBUG="🐞"
ICON_WAIT="⏳"
ICON_CLEAN="🧹"
ICON_CONFIG="⚙️"
ICON_NETWORK="📡"
ICON_START="🚀"
ICON_READY="✅"
ICON_FINISH="🎉"

# 增强版日志函数（优化颜色处理）
log() {
  local level=$1 message=$2
  local color icon timestamp
  timestamp=$(date -u '+%H:%M:%S')
  
  case $level in
    INFO)    color="$GREEN"  icon="$ICON_INFO" ;;
    SUCCESS) color="$GREEN"  icon="$ICON_SUCCESS" ;;
    WARN)    color="$YELLOW" icon="$ICON_WARNING" ;;
    ERROR)   color="$RED"    icon="$ICON_ERROR" ;;
    DEBUG)   color="$BLUE"   icon="$ICON_DEBUG" ;;
    WAIT)    color="$MAGENTA" icon="$ICON_WAIT" ;;
    *)       color="$CYAN"   icon="$ICON_INFO" ;;
  esac

  # 直接输出消息，避免嵌套格式化问题
  printf "${color}%s %-7s\t%s${RESET}\n" "$timestamp $icon" "[$level]" "$message"
}

# 简洁标题样式（改为 === 标题 === 形式）
header() {
  if [ "$2" = "MinIO 站点复制初始化" ]; then
    printf "\n\n${MAGENTA}███╗   ███╗██╗███╗   ██╗██╗ ██████╗     ███╗   ███╗ ██████╗\n████╗ ████║██║████╗  ██║██║██╔═══██╗    ████╗ ████║██╔════╝\n██╔████╔██║██║██╔██╗ ██║██║██║   ██║    ██╔████╔██║██║     \n██║╚██╔╝██║██║██║╚██╗██║██║██║   ██║    ██║╚██╔╝██║██║     \n██║ ╚═╝ ██║██║██║ ╚████║██║╚██████╔╝    ██║ ╚═╝ ██║╚██████╗\n╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝     ╚═╝     ╚═╝ ╚═════╝\n\n>> %s %s${RESET}\n" "$1" "$2"
    printf "\n"
  else
    printf "\n${CYAN}[ TASK %d ] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n>> %s %s${RESET}\n" "$task_number" "$1" "$2"
    printf "\n"
    task_number=$((task_number + 1))
  fi
}

# 初始化任务计数器
task_number=1

# 等待服务就绪（合并为一个任务）
wait_for_services() {
  local retries=15 delay=2 attempt=1
  local spinner=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
  local all_ready=0

  header "$ICON_WAIT" "等待 MinIO 服务就绪"

  for site in "${!SITES[@]}"; do
    local alias="HEALTHCHECK_$site"
    local url="${SITES[$site]}"
    local attempt=1
    local all_ready=0



    log INFO "检查服务: $url"
    while [ $attempt -le $retries ]; do
      if /usr/bin/mc alias set "$alias" "$url" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null 2>&1 && \
         /usr/bin/mc ls "$alias" >/dev/null 2>&1; then
        log SUCCESS "服务已就绪: $url"
        all_ready=1
        if [ "$site" = "SITE1" ]; then
          printf "${CYAN}%s${RESET}\n" "$(for i in $(seq 1 61); do printf "-"; done)"
        fi
        break
      fi

      printf "\r%-80s" " "
      printf "\r${YELLOW}%s 尝试 %2d/%-2d 检查服务 %s 中...${RESET}" \
        "${spinner[$((attempt % ${#spinner[@]}))]}" \
        $attempt $retries "$url"
      sleep $delay
      ((attempt++))
      delay=$((delay * 2 > 8 ? 8 : delay * 2))
    done

    if [ $all_ready -eq 0 ]; then
      log ERROR "服务 $url 在 $retries 次尝试后仍未就绪"
      exit 1
    fi
  done
  echo ""
}

# 配置别名（优化颜色格式）
configure_aliases() {
  header "$ICON_CONFIG" "配置 MinIO 站点别名"
  for site in "${!SITES[@]}"; do
    local url="${SITES[$site]}"
    /usr/bin/mc alias remove "$site" 2>/dev/null || true
    if /usr/bin/mc alias set "$site" "$url" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null 2>&1; then
      log SUCCESS "别名配置成功: ${site} → ${url}"
    else
      log ERROR "无法配置别名: $site → $url"
      return 1
    fi
  done
  echo ""
}

# 检查复制配置状态
check_replication_status() {
  /usr/bin/mc admin replicate info SITE1 2>&1 | grep -q "SiteReplication enabled"
}

# 清除原复制配置
cleanup_old_replication() {
  header "$ICON_CLEAN" "清理原有复制配置"
  for site in "${!SITES[@]}"; do
    log INFO "正在清理 $site 的复制配置..."
    if /usr/bin/mc admin replicate rm --all "$site" --force 2>/dev/null; then
      log SUCCESS "成功清理 $site 的配置"
    else
      log WARN "$site 无配置可清理或清理失败"
    fi
  done
  sleep 2
  if check_replication_status; then
    log ERROR "复制配置仍存在，请手动检查"
    return 1
  fi
  log SUCCESS "所有站点复制配置已清理完成"
  echo ""
}

# 可靠的bucket删除函数
delete_all_buckets() {
  local site=$1
  log WARN "即将清空 ${site} 的所有bucket..."
  local buckets
  buckets=$(/usr/bin/mc ls "$site" --json | jq -r .key | tr -d '/' | grep -v '^$')
  if [ -z "$buckets" ]; then
    log INFO "没有 bucket 需要删除"
    return 0
  fi
  echo "$buckets" | while read -r bucket; do
    log INFO "正在删除 ${site}/${bucket}..."
    if /usr/bin/mc rb --force "${site}/${bucket}" >/dev/null 2>&1; then
      log SUCCESS "删除成功: ${site}/${bucket}"
    else
      log ERROR "删除失败: ${site}/${bucket}"
      return 1
    fi
  done
  if /usr/bin/mc ls "$site" | grep -q .; then
    log ERROR "${site} 中仍有bucket存在"
    return 1
  fi
  log SUCCESS "${site} 已完全清空"
}

# 设置复制配置
setup_replication() {
  header "$ICON_NETWORK" "设置站点复制"
  local retries=5 delay=2 attempt=1
  local site_list=("${!SITES[@]}")
  while [ $attempt -le $retries ]; do
    log WAIT "尝试配置复制 (${attempt}/${retries})..."
    output=$(/usr/bin/mc admin replicate add "${site_list[@]}" 2>&1)
    if [ $? -eq 0 ]; then
      log SUCCESS "站点复制配置成功!"
      echo ""
      return 0
    fi
    if [[ $output == *"only one cluster may have data"* ]]; then
      log WARN "检测到 SITE2 中已有数据，违反复制要求"
      if ! delete_all_buckets "SITE2"; then
        log ERROR "清空 SITE2 失败，无法继续"
        return 1
      fi
      log INFO "等待 ${delay} 秒让系统完成清理..."
      sleep $delay
    else
      log ERROR "复制配置失败: $(echo "$output" | head -n1)"
      log DEBUG "完整错误: $output"
    fi
    ((attempt++))
    delay=$((delay * 2 > 8 ? 8 : delay * 2))
  done
  log ERROR "经过 ${retries} 次尝试后仍无法配置复制"
  return 1
}

# 优化状态验证表格
verify_status() {
  header "$ICON_NETWORK" "复制状态验证"
  for site in "${!SITES[@]}"; do
    printf "${GREEN}%s [SUCCESS]   查询成功: %s → %s${RESET}\n" "$ICON_SUCCESS" "$site" "${SITES[$site]}"
    printf "${CYAN}%s${RESET}\n" "$(for i in $(seq 1 160); do printf "-"; done)"
    status_output=$(/usr/bin/mc admin replicate info "$site" 2>&1)
    if echo "$status_output" | grep -q "SiteReplication enabled"; then
      printf "${GREEN}%s${RESET}\n" "$status_output"
    else
      printf "${RED}%s${RESET}\n" "$status_output"
    fi
    echo ""
  done
}

# 主流程控制
main() {
  : "${SITE1_URL:?需要 SITE1_URL 环境变量}"
  : "${SITE2_URL:?需要 SITE2_URL 环境变量}"
  : "${MINIO_ACCESS_KEY:?需要 MINIO_ACCESS_KEY 环境变量}"
  : "${MINIO_SECRET_KEY:?需要 MINIO_SECRET_KEY 环境变量}"
  declare -A SITES=(["SITE1"]="$SITE1_URL" ["SITE2"]="$SITE2_URL")
  header "$ICON_START" "MinIO 站点复制初始化"
  wait_for_services
  configure_aliases || exit 1
  cleanup_old_replication || exit 1
  setup_replication || exit 1
  verify_status
  header "$ICON_FINISH" "MinIO 站点复制已就绪"
  log SUCCESS "所有配置已完成，服务运行中..."
  log INFO "按 Ctrl+C 停止服务"
  exec tail -f /dev/null
}

trap 'log INFO "收到终止信号，正在关闭..."; exit 0' SIGTERM SIGINT
main