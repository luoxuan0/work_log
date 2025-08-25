#!/bin/bash
# set -euo pipefail 详解：
# -e: 一旦脚本中的任何命令以非零状态退出（即发生错误），整个脚本立即终止，防止错误被忽略。
# -u: 使用未定义的变量时，脚本会报错并退出，避免因拼写错误或变量未赋值导致的不可预期行为。
# -o pipefail: 只要管道（|）中的任一命令失败（返回非零），整个管道的返回值即为失败，脚本也会据此终止，防止只检查最后一个命令而漏掉前面步骤的错误。
set -euo pipefail

###############################################################################
# 日志归档与清理脚本
# 说明：
#   - 自动查找并压缩指定目录下超过一定天数的 mailgun 日志文件
#   - 压缩成功后删除原始日志，仅保留 zip 包
#   - 归档操作、校验、失败处理均有详细输出
#   - 每条日志操作均带有时间戳，便于追踪
#   - 可根据需要调整 LOG_DIR、DAYS_KEEP 等参数
#   - 本脚本日志按月归档，便于长期追溯
#   - 异常操作单独记录，便于后续告警接入
# 作者：YourName
# 日期：$(date "+%Y-%m-%d")
###############################################################################

CURRENT_YEAR=$(date +%Y)  # 自动获取当前年份，如需指定可手动赋值
CURRENT_MONTH=$(date +%m)
LOG_DIR="/home/data/logs/mail/logs/tripartiteWebhook/mailgun/${CURRENT_YEAR}"
LOG_PATTERN="mailgun${CURRENT_YEAR}*log"
DAYS_KEEP=7

# 日志文件按月归档
SCRIPT_LOG_DIR="/var/log/mailgun_archive"
mkdir -p "$SCRIPT_LOG_DIR"
SCRIPT_LOG_FILE="${SCRIPT_LOG_DIR}/archive_$(date +%Y-%m).log"
SCRIPT_ERR_FILE="${SCRIPT_LOG_DIR}/archive_error_$(date +%Y-%m).log"

log() {
  # 输出带时间戳的日志，写入月度日志文件
  local msg="[$(date '+%F %T')] $*"
  echo "$msg" | tee -a "$SCRIPT_LOG_FILE"
}

log_error() {
  # 输出带时间戳的异常日志，写入单独的异常日志文件
  local msg="[$(date '+%F %T')] $*"
  echo "$msg" | tee -a "$SCRIPT_ERR_FILE"
}

# 捕获未处理的异常，记录到异常日志
trap 'log_error "脚本异常退出，退出码：$?，请检查主日志 $SCRIPT_LOG_FILE 和异常日志 $SCRIPT_ERR_FILE"' ERR

log "脚本启动，当前年份：$CURRENT_YEAR"
log "日志目录：$LOG_DIR"
log "日志文件模式：$LOG_PATTERN"
log "归档阈值：保留最近 $DAYS_KEEP 天内日志"

# 查找需归档的日志文件
if ! mapfile -t LOG_FILES < <(find "$LOG_DIR" -name "$LOG_PATTERN" -type f -mtime +$DAYS_KEEP 2>>"$SCRIPT_ERR_FILE"); then
  log_error "查找日志文件时发生异常，请检查目录权限或路径设置。"
  exit 1
fi

if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
  log "没有需要归档的日志文件。"
  exit 0
fi

log "待归档文件列表："
for f in "${LOG_FILES[@]}"; do log "  $f"; done

# 归档并校验
for file in "${LOG_FILES[@]}"; do
  ZIP_FILE="${file}.zip"
  if [[ -f "$ZIP_FILE" ]]; then
    log "压缩包已存在：$ZIP_FILE，跳过。"
    continue
  fi

  log "开始压缩 $file ..."
  if zip -j "$ZIP_FILE" "$file" >/dev/null 2>>"$SCRIPT_ERR_FILE"; then
    # 校验压缩包是否可用
    if unzip -tq "$ZIP_FILE" >/dev/null 2>>"$SCRIPT_ERR_FILE"; then
      log "压缩并校验成功，删除原文件：$file"
      if ! rm -f "$file" 2>>"$SCRIPT_ERR_FILE"; then
        log_error "删除原文件失败：$file"
      fi
    else
      log_error "压缩包校验失败，保留原文件：$file，删除无效压缩包：$ZIP_FILE"
      rm -f "$ZIP_FILE" 2>>"$SCRIPT_ERR_FILE" || log_error "删除无效压缩包失败：$ZIP_FILE"
    fi
  else
    log_error "压缩失败：$file"
    # 若压缩失败，尝试删除可能生成的不完整压缩包
    [[ -f "$ZIP_FILE" ]] && rm -f "$ZIP_FILE" 2>>"$SCRIPT_ERR_FILE"
  fi
done

log "日志归档与清理完成。"