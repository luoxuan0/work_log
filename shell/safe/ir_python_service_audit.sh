#!/usr/bin/env bash
# ir_python_service_audit.sh
# 目的：
#  1) 审计 python.service（可疑伪装：/usr/bin/log、/usr/log、/var/log/log）
#  2) 取证收集（不破坏现场，尽量只读；同时保存 unit、二进制、内存映射、网络连接、持久化点等）
#  3) 安全处置（停止/禁用服务，隔离二进制与持久化入口），并生成可回滚快照
#  4) 回滚（恢复原服务启停状态与文件路径）
#
# 日志：/var/log/ir-python-service.log
# 快照：/var/lib/ir-python-service/state-*.json
# 取证包：/root/ir_artifacts/ir-*.tar.gz
#
# 风险提示：
# - neutralize 会停止并禁用 python.service，移动可疑二进制到隔离区；如确属业务误报，可通过 --rollback 恢复
# - 取证优先：建议先 --collect，再 --neutralize
set -euo pipefail

LOG="/var/log/ir-python-service.log"
STATE_DIR="/var/lib/ir-python-service"
ART_DIR="/root/ir_artifacts"
TS="$(date +%Y%m%d-%H%M%S)"
HOST="$(hostname -f 2>/dev/null || hostname)"
mkdir -p "$(dirname "$LOG")" "$STATE_DIR" "$ART_DIR"

SVC="python.service"
# IOC 路径（根据你现场）：
IOC_BIN1="/usr/bin/log"
IOC_BIN2="/usr/log"
IOC_BIN3="/var/log/log"
IOC_PATHS=("$IOC_BIN1" "$IOC_BIN2" "$IOC_BIN3")

# 安全隔离目录
QUAR="/root/quarantine_ir/$TS"
mkdir -p "$QUAR"

log() { echo "[$(date '+%F %T%z')] $*" | tee -a "$LOG"; }
run() { log "+ $*"; eval "$@" 2>&1 | tee -a "$LOG"; }

usage() {
  cat <<'EOF'
用法：
  /root/ir_python_service_audit.sh            # 仅审计（默认，不改动系统）
  /root/ir_python_service_audit.sh --collect  # 取证收集并打包证据
  /root/ir_python_service_audit.sh --neutralize   # 处置（停止/禁用/隔离）并取证
  /root/ir_python_service_audit.sh --rollback /var/lib/ir-python-service/state-xxxx.json  # 回滚

说明：
  --collect：生成取证包（不改变系统状态），路径 /root/ir_artifacts/ir-*.tar.gz
  --neutralize：在完成取证后，停止并禁用 python.service，隔离可疑二进制和持久化入口，保存回滚快照
  --rollback：使用之前 neutralize 生成的 state-*.json 恢复文件与服务状态
EOF
}

MODE="audit"
ROLLBACK_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --collect) MODE="collect"; shift;;
    --neutralize) MODE="neutralize"; shift;;
    --rollback) MODE="rollback"; ROLLBACK_FILE="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) log "未知参数：$1"; usage; exit 1;;
  esac
done

# 统一的取证输出目录（本轮）
ROUND_DIR="$ART_DIR/round-$TS"
mkdir -p "$ROUND_DIR"

# ---- 基础信息 ----
log "=== IR START host=$HOST ts=$TS mode=$MODE ==="
log "日志：$LOG"
log "取证目录：$ROUND_DIR"
log "隔离目录：$QUAR"

# ---- 函数：采集系统与进程证据（不改变状态）----
collect_evidence() {
  log "[COLLECT] 开始取证收集（只读）"

  # 1) systemd unit 与状态
  run "systemctl status $SVC || true" | sed -e 's/\x1b\[[0-9;]*m//g' > "$ROUND_DIR/${SVC}.status.txt"
  run "systemctl cat $SVC || true" > "$ROUND_DIR/${SVC}.unit.txt"
  run "systemctl show $SVC || true" > "$ROUND_DIR/${SVC}.show.txt"
  run "journalctl -u $SVC --no-pager --since '3 months ago' || true" > "$ROUND_DIR/${SVC}.journal.txt"

  # 2) Cron/持久化入口
  run "crontab -l || true" > "$ROUND_DIR/cron_user_root.txt"
  for d in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
    [[ -d "$d" ]] && run "ls -la $d" > "$ROUND_DIR/ls$(echo $d | tr '/' '_').txt"
  done
  run "grep -R --line-number --binary-files=without-match -E 'log -sshd|/usr/log|/var/log/log|/usr/bin/log' /etc 2>/dev/null || true" \
    > "$ROUND_DIR/persistence_grep_etc.txt"

  # 3) 相关二进制与哈希、元数据
  for p in "${IOC_PATHS[@]}"; do
    if [[ -e "$p" ]]; then
      run "ls -la --full-time '$p'" > "$ROUND_DIR$(echo "$p" | tr '/' '_').ls.txt"
      run "file '$p' || true" > "$ROUND_DIR$(echo "$p" | tr '/' '_').file.txt"
      run "sha256sum '$p' || true" > "$ROUND_DIR$(echo "$p" | tr '/' '_').sha256.txt"
      # 尝试复制二进制（保持原始 mtime/权限）
      cp -a "$p" "$ROUND_DIR"/ 2>/dev/null || true
      # strings 作为参考（注意隐私，可按需删）
      command -v strings >/dev/null 2>&1 && \
        strings "$p" | head -n 2000 > "$ROUND_DIR$(echo "$p" | tr '/' '_').strings.head.txt" || true
    fi
  done

  # 4) 进程树、网络、句柄（定位 C2/落地）
  run "ps -efww" > "$ROUND_DIR/ps_ef.txt"
  run "pstree -ap 2>/dev/null || true" > "$ROUND_DIR/pstree.txt"
  run "ss -lntup || true" > "$ROUND_DIR/ss_lntup.txt"
  run "ss -antup || true" > "$ROUND_DIR/ss_antup.txt"
  run "lsof -n -p \$(pgrep -x log || true) 2>/dev/null || true" > "$ROUND_DIR/lsof_logproc.txt"
  run "netstat -plant 2>/dev/null || true" > "$ROUND_DIR/netstat_plant.txt"

  # 5) 针对 python.service 的进程 /proc 取证
  mapfile -t PIDS < <(pgrep -f "/usr/bin/log -sshd|/usr/log|/var/log/log" || true)
  for pid in "${PIDS[@]:-}"; do
    OUT="$ROUND_DIR/proc_$pid"
    mkdir -p "$OUT"
    run "cat /proc/$pid/cmdline 2>/dev/null | tr '\\0' ' '" > "$OUT/cmdline.txt" || true
    run "cat /proc/$pid/environ 2>/dev/null | tr '\\0' '\\n'" > "$OUT/environ.txt" || true
    run "cat /proc/$pid/maps 2>/dev/null" > "$OUT/maps.txt" || true
    run "ls -la /proc/$pid/fd 2>/dev/null" > "$OUT/fd.ls.txt" || true
    run "readlink -f /proc/$pid/exe 2>/dev/null" > "$OUT/exe.readlink.txt" || true
    run "pwdx $pid 2>/dev/null" > "$OUT/pwdx.txt" || true
  done

  # 6) 用户/认证/最近登录，sudo 记录（辅助判断入侵链路）
  run "last -Faiwx 2>/dev/null || true" > "$ROUND_DIR/last.txt"
  run "lastlog 2>/dev/null || true" > "$ROUND_DIR/lastlog.txt"
  run "grep -iE 'sshd|Accepted|Failed|invalid user|sudo' /var/log/auth.log* /var/log/secure* 2>/dev/null || true" \
    > "$ROUND_DIR/authlog_grep.txt"
  run "grep -iE 'sudo' /var/log/auth.log* /var/log/secure* 2>/dev/null || true" \
    > "$ROUND_DIR/sudo_grep.txt"
  run "id 2>/dev/null || true" > "$ROUND_DIR/whoami_id.txt"

  # 7) SSH 持久化检查
  for uhome in /root /home/*; do
    [[ -d "$uhome/.ssh" ]] || continue
    mkdir -p "$ROUND_DIR/ssh$(echo "$uhome" | tr '/' '_')"
    run "ls -la $uhome/.ssh" > "$ROUND_DIR/ssh$(echo "$uhome" | tr '/' '_')/ls.txt"
    [[ -f "$uhome/.ssh/authorized_keys" ]] && \
      run "cat $uhome/.ssh/authorized_keys" > "$ROUND_DIR/ssh$(echo "$uhome" | tr '/' '_')/authorized_keys.txt"
  done

  # 8) 可疑新 SUID（近30天）
  run "find / -xdev -perm /4000 -type f -mtime -30 2>/dev/null" > "$ROUND_DIR/suid_recent.txt"

  # 9) 系统清单与内核信息
  run "uname -a" > "$ROUND_DIR/uname.txt"
  run "cat /etc/os-release 2>/dev/null || true" > "$ROUND_DIR/os-release.txt"
  run "systemctl list-unit-files --state=enabled 2>/dev/null || true" > "$ROUND_DIR/unit_enabled.txt"

  # 10) 打包
  TAR="$ART_DIR/ir-$HOST-$TS.tar.gz"
  (cd "$ART_DIR" && tar -zcf "$(basename "$TAR")" "round-$TS") && log "[COLLECT] 取证包：$TAR"
}

# ---- 函数：处置（可回滚）----
neutralize() {
  log "[NEUTRALIZE] 开始处置（将同时调用 collect_evidence 做取证）"
  collect_evidence

  # 保存回滚快照
  SNAP="$STATE_DIR/state-$TS.json"
  : > "$SNAP"
  {
    echo "{"
    echo "  \"service\":\"$SVC\","
    echo "  \"was_enabled\":\"$(systemctl is-enabled "$SVC" 2>/dev/null || echo unknown)\","
    echo "  \"was_active\":\"$(systemctl is-active "$SVC" 2>/dev/null || echo inactive)\","
    echo "  \"files\":["
  } >> "$SNAP"

  # 停止/禁用服务（先停 unit，再禁用）
  run "systemctl stop $SVC || true"
  run "systemctl disable $SVC || true"

  # 隔离可疑文件（记录原路径，用于回滚）
  i=0
  for p in "${IOC_PATHS[@]}"; do
    if [[ -e "$p" ]]; then
      base="$(basename "$p")"
      dst="$QUAR/${base}.${TS}"
      run "mv -f '$p' '$dst'"
      [[ $i -gt 0 ]] && echo "," >> "$SNAP"
      echo "    {\"src\":\"$p\",\"dst\":\"$dst\"}" >> "$SNAP"
      ((i++))
    fi
  done

  # 移除持久化入口（只处理本次确认的 IOC；其它改动不做，避免过度破坏现场）
  # 1) 单元文件若非软链接，备份后注释化处理
  UNIT_FILE="$(systemctl cat $SVC 2>/dev/null | sed -n '1s/^# //p;1q')"
  # 上行拿到 "### Unit file: /etc/systemd/system/python.service" 的路径；保险起见再定位
  if [[ -z "$UNIT_FILE" || ! -f "$UNIT_FILE" ]]; then
    # 直接猜测常见位置
    [[ -f /etc/systemd/system/python.service ]] && UNIT_FILE=/etc/systemd/system/python.service || true
  fi
  if [[ -n "${UNIT_FILE:-}" && -f "$UNIT_FILE" ]]; then
    run "cp -a '$UNIT_FILE' '$QUAR/python.service.${TS}.bak'"
    # 注释掉 ExecStart 并添加备注
    run "awk 'BEGIN{c=0} /^ExecStart=/{print \"# [neutralized-\" ENVIRON[\"TS\"] \"] \" \$0; print \"ExecStart=/bin/false\"; c=1; next} {print} END{if(c==0) print \"# [neutralized-\" ENVIRON[\"TS\"] \"] (no ExecStart found)\"}' '$UNIT_FILE' > '$UNIT_FILE.tmp'"
    run "mv '$UNIT_FILE.tmp' '$UNIT_FILE'"
    run "systemctl daemon-reload"
  fi

  # 2) root crontab 的 @reboot 项（仅注释包含 IOC 的行）
  if crontab -l >/dev/null 2>&1; then
    run "crontab -l | sed -e 's#^\\(@reboot.*\\(/usr/log\\|/var/log/log\\)\\)#\\# [neutralized-$TS] \\1#' | crontab -"
  fi

  echo "  ]" >> "$SNAP"
  echo "}" >> "$SNAP"
  log "[NEUTRALIZE] 处置完成，回滚快照：$SNAP"
  log "可用：/root/ir_python_service_audit.sh --rollback $SNAP 进行回滚"
}

# ---- 函数：回滚 ----
rollback() {
  local snap="$1"
  [[ -f "$snap" ]] || { log "[ROLLBACK] 快照不存在：$snap"; exit 1; }
  log "[ROLLBACK] 使用快照：$snap"

  local was_enabled was_active
  was_enabled=$(jq -r '.was_enabled' "$snap")
  was_active=$(jq -r '.was_active' "$snap")

  # 还原文件
  jq -c '.files[]' "$snap" | while read -r item; do
    src=$(echo "$item" | jq -r '.src')
    dst=$(echo "$item" | jq -r '.dst')
    if [[ -f "$dst" ]]; then
      run "mkdir -p \"$(dirname "$src")\""
      run "mv -f \"$dst\" \"$src\""
    else
      log "[WARN] 隔离文件已不在：$dst"
    fi
  done

  # 恢复 unit（如果我们改过）
  if [[ -f "$QUAR/python.service.${TS}.bak" ]]; then
    run "mv -f \"$QUAR/python.service.${TS}.bak\" /etc/systemd/system/python.service"
    run "systemctl daemon-reload"
  fi

  # 恢复 enable 状态
  if [[ "$was_enabled" == "enabled" ]]; then
    run "systemctl enable $SVC || true"
  else
    run "systemctl disable $SVC || true"
  fi

  # 恢复 active 状态
  if [[ "$was_active" == "active" ]]; then
    run "systemctl start $SVC || true"
  else
    run "systemctl stop $SVC || true"
  fi

  log "[ROLLBACK] 完成。"
}

# ---- 主流程 ----
case "$MODE" in
  audit)
    log "[AUDIT] 仅审计模式（不做改动）"
    collect_evidence
    log "[AUDIT] 审计结束。取证目录：$ROUND_DIR"
    ;;
  collect)
    log "[COLLECT] 启动"
    collect_evidence
    ;;
  neutralize)
    neutralize
    ;;
  rollback)
    rollback "$ROLLBACK_FILE"
    ;;
  *)
    usage; exit 1;;
esac

log "=== IR END mode=$MODE ==="
