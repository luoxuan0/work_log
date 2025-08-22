#!/usr/bin/env bash
# ir-python-audit.sh (Strict IR + Analyzer + Restore + Runtime Drop-in)
# - 严格现场取证（仅 runtime 改动）
# - 仅停止/恢复、严格阻断（mask --runtime + 可选 runtime drop-in）、永久清理（可回滚）
# - 依赖检查/安装/回撤、自动研判（analysis_report.md）、快照可回撤
set -euo pipefail

TS="$(date +%Y%m%d-%H%M%S)"
BASE_DIR="/var/log/ir-python/${TS}"
EVD_DIR="${BASE_DIR}/evidence"
LOG_FILE="${BASE_DIR}/run.log"
SNAPSHOT="${BASE_DIR}/snapshot.json"
DEPS_FILE="${BASE_DIR}/deps-installed.txt"
QUAR_DIR="${BASE_DIR}/quarantine"
REPORT="${BASE_DIR}/analysis_report.md"
mkdir -p "$BASE_DIR" "$EVD_DIR" "$QUAR_DIR"

timestamp(){ date +"%Y-%m-%d %H:%M:%S%z"; }
log(){ echo "[$(timestamp)] $*" | tee -a "$LOG_FILE"; }
errtrap(){ echo "[$(timestamp)] ERROR at line $1: command '$2' failed with code $3" | tee -a "$LOG_FILE"; }
trap 'errtrap $LINENO "$BASH_COMMAND" $?' ERR
die(){ log "FATAL: $*"; exit 1; }
has(){ command -v "$1" >/dev/null 2>&1; }

TARGET_UNIT="python.service"
NEUTRALIZE=0
STRICT=0
RUNTIME_DROPIN=0
AUDIT_ONLY=0
CHECK_DEPS=0
INSTALL_DEPS=0
ROLLBACK_DEPS_FILE=""
RESUME_FILE=""
RESTORE_FILE=""      # NEW: --restore
SUSPEND_ONLY=0
SINCE=""
CASE_TAG=""
ANALYZE=0

usage(){
cat <<'EOF'
用法：
  ./ir-python-audit.sh [--check-deps|--install-deps|--rollback-deps FILE]
                       [--audit-only]
                       [--neutralize] [--strict] [--runtime-dropin]
                       [--suspend | --resume SNAP.json | --restore SNAP.json]
                       [--analyze]
                       [--since "YYYY-MM-DD HH:MM:SS"] [--case-tag STR]

说明：
  --check-deps / --install-deps / --rollback-deps FILE
  --audit-only               仅取证，不处置
  --neutralize               处置（严格下为 runtime；非严格为永久清理）
  --strict                   严格模式（仅 runtime 改动）
  --runtime-dropin           和 --strict --neutralize 一起用，写 /run/.../override.conf 覆盖 ExecStart=/bin/false
  --suspend                  仅停止（可 --resume 恢复）
  --resume SNAP.json         恢复上次 --suspend 生成的快照
  --restore SNAP.json        回滚处置快照（严格/永久均可回滚）
  --analyze                  自动研判生成 analysis_report.md
  --since                    取证起点（默认取服务上次启动时间）
  --case-tag                 本次标签
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --neutralize) NEUTRALIZE=1; shift;;
    --strict) STRICT=1; shift;;
    --runtime-dropin) RUNTIME_DROPIN=1; shift;;
    --audit-only) AUDIT_ONLY=1; shift;;
    --check-deps) CHECK_DEPS=1; shift;;
    --install-deps) INSTALL_DEPS=1; shift;;
    --rollback-deps) ROLLBACK_DEPS_FILE="${2:-}"; shift 2;;
    --resume) RESUME_FILE="${2:-}"; shift 2;;
    --restore) RESTORE_FILE="${2:-}"; shift 2;;
    --suspend) SUSPEND_ONLY=1; shift;;
    --since) SINCE="${2:-}"; shift 2;;
    --case-tag) CASE_TAG="${2:-}"; shift 2;;
    --analyze) ANALYZE=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "未知参数：$1";;
  esac
done

require_root(){ [[ "$(id -u)" -eq 0 ]] || die "请以 root 运行"; }

OS_ID="unknown"; PKG_MGR="unknown"
detect_os_pm(){
  [[ -f /etc/os-release ]] && . /etc/os-release && OS_ID="${ID:-unknown}"
  if   has apt-get; then PKG_MGR="apt"
  elif has dnf;     then PKG_MGR="dnf"
  elif has yum;     then PKG_MGR="yum"
  elif has zypper;  then PKG_MGR="zypper"
  else PKG_MGR="unknown"
  fi
}
check_deps(){
  local need=( systemctl ps ss awk sed grep cut xargs find stat sha256sum md5sum tar gzip date tee cat head tail wc id readlink dirname basename strings lsof pstree journalctl crontab column )
  local opt=( jq file getcap ip uname getfacl lsattr getfattr readelf objdump gcore )
  local miss=() optmiss=()
  for c in "${need[@]}"; do has "$c" || miss+=("$c"); done
  for c in "${opt[@]}"; do has "$c" || optmiss+=("$c"); done
  log "必要命令：$( ((${#miss[@]})) && echo "缺失: ${miss[*]}" || echo "齐全" )"
  ((${#optmiss[@]})) && log "（可选）建议安装：${optmiss[*]}"
}
install_deps(){
  local pkgs
  case "$PKG_MGR" in
    apt) pkgs=( jq lsof psmisc binutils file iproute2 libcap2-bin );;
    dnf|yum) pkgs=( jq lsof psmisc binutils file iproute libcap );;
    zypper) pkgs=( jq lsof psmisc binutils file iproute libcap );;
    *) die "无法识别包管理器";;
  esac
  : > "$DEPS_FILE"
  log "包管理器：$PKG_MGR / OS=$OS_ID"
  [[ "$PKG_MGR" == "apt" ]] && { apt-get update -y >>"$LOG_FILE" 2>&1 || true; }
  for p in "${pkgs[@]}"; do
    case "$PKG_MGR" in
      apt) dpkg -s "$p" >/dev/null 2>&1 || { log "安装 $p"; apt-get install -y "$p" >>"$LOG_FILE" 2>&1 && echo "$p" >>"$DEPS_FILE" || log "安装 $p 失败"; };;
      dnf) rpm -q "$p"  >/dev/null 2>&1 || { log "安装 $p"; dnf install -y "$p"  >>"$LOG_FILE" 2>&1 && echo "$p" >>"$DEPS_FILE" || log "安装 $p 失败"; };;
      yum) rpm -q "$p"  >/dev/null 2>&1 || { log "安装 $p"; yum install -y "$p"  >>"$LOG_FILE" 2>&1 && echo "$p" >>"$DEPS_FILE" || log "安装 $p 失败"; };;
      zypper) rpm -q "$p">/dev/null 2>&1 || { log "安装 $p"; zypper -n install "$p" >>"$LOG_FILE" 2>&1 && echo "$p" >>"$DEPS_FILE" || log "安装 $p 失败"; };;
    esac
  done
  log "依赖安装完成：$DEPS_FILE"
}
rollback_deps(){
  local file="$1"; [[ -f "$file" ]] || die "依赖清单不存在：$file"
  case "$PKG_MGR" in
    apt) while read -r p; do [[ -n "$p" ]] && apt-get remove -y "$p" >>"$LOG_FILE" 2>&1 || true; done < "$file";;
    dnf) while read -r p; do [[ -n "$p" ]] && dnf remove -y "$p" >>"$LOG_FILE" 2>&1 || true; done < "$file";;
    yum) while read -r p; do [[ -n "$p" ]] && yum remove -y "$p" >>"$LOG_FILE" 2>&1 || true; done < "$file";;
    zypper) while read -r p; do [[ -n "$p" ]] && zypper -n remove "$p" >>"$LOG_FILE" 2>&1 || true; done < "$file";;
    *) die "无法识别包管理器";;
  esac
  log "依赖回撤完成。"
}

json_begin(){ echo '{"timestamp":"'"$(timestamp)"'","unit":"'"$TARGET_UNIT"'","case_tag":"'"$CASE_TAG"'","actions":[' > "$SNAPSHOT"; }
json_append(){ local json="$1"; if grep -q '"actions":\[' "$SNAPSHOT" && [[ $(tail -1 "$SNAPSHOT") != "["* ]]; then sed -i '$ s/$/,/' "$SNAPSHOT"; fi; echo "$json" >> "$SNAPSHOT"; }
json_end(){ echo ']}' >> "$SNAPSHOT"; }

derive_since(){
  [[ -n "$SINCE" ]] && { echo "$SINCE"; return; }
  local t; t=$(systemctl show -p ActiveEnterTimestamp "$TARGET_UNIT" 2>/dev/null | cut -d= -f2 || true)
  [[ -n "$t" ]] && echo "$t" || date -d "30 days ago" "+%Y-%m-%d 00:00:00" 2>/dev/null || echo "30 days ago"
}

collect_unit(){
  systemctl list-unit-files | grep -q "^${TARGET_UNIT}" || log "未发现 ${TARGET_UNIT}"
  systemctl cat "$TARGET_UNIT" > "${EVD_DIR}/${TARGET_UNIT}.unit" 2>>"$LOG_FILE" || true
  systemctl status "$TARGET_UNIT" > "${EVD_DIR}/${TARGET_UNIT}.status.txt" 2>&1 || true
  systemctl show "$TARGET_UNIT" > "${EVD_DIR}/${TARGET_UNIT}.show.txt" 2>&1 || true
}
find_exec_paths(){
  local unitfile="${EVD_DIR}/${TARGET_UNIT}.unit" arr=()
  [[ -s "$unitfile" ]] && while read -r line; do
    [[ "$line" =~ ^ExecStart= ]] || continue
    local cmd="${line#ExecStart=}"
    for tok in $cmd; do [[ -e "$tok" || -x "$tok" ]] && arr+=("$tok"); done
  done < <(grep -E '^ExecStart=' "$unitfile" || true)
  arr+=( "/usr/bin/log" "/usr/log" "/var/log/log" )
  printf "%s\n" "${arr[@]}" | awk '!a[$0]++'
}
audit_process_and_files(){
  local AUD="${EVD_DIR}/audit"; mkdir -p "$AUD"
  ps -eo pid,ppid,uid,gid,cmd,%cpu,%mem,etime --sort=pid > "${AUD}/ps_full.txt"
  mapfile -t PIDS < <(ps -eo pid,cmd | awk '/\/usr\/bin\/log|\/usr\/log|\/var\/log\/log/ {print $1}')
  printf "%s\n" "${PIDS[@]}" > "${AUD}/suspect_pids.txt"
  for pid in "${PIDS[@]}"; do
    [[ -d "/proc/$pid" ]] || continue
    mkdir -p "${AUD}/proc_${pid}"
    tr '\0' ' ' < "/proc/$pid/cmdline" > "${AUD}/proc_${pid}/cmdline.txt" || true
    tr '\0' '\n' < "/proc/$pid/environ" > "${AUD}/proc_${pid}/environ.txt" || true
    cat "/proc/$pid/status" > "${AUD}/proc_${pid}/status.txt" || true
    ( lsof -p "$pid" || true ) > "${AUD}/proc_${pid}/lsof.txt" 2>&1
    ( pmap -x "$pid" || true ) > "${AUD}/proc_${pid}/pmap.txt" 2>&1
    ( pstree -asp "$pid" || true ) > "${AUD}/proc_${pid}/pstree.txt" 2>&1
    ( ss -ptna || true ) | grep -E "(pid=$pid,|users:\(\(\".*\",pid=$pid)" > "${AUD}/proc_${pid}/ss.txt" 2>&1 || true
  done
  mapfile -t EXEC_PATHS < <(find_exec_paths)
  for f in "${EXEC_PATHS[@]}"; do
    [[ -e "$f" ]] || continue
    local base="${AUD}/file_$(echo "$f" | sed 's#/#_#g')"
    {
      echo "==== META BEFORE READ: $f ===="
      stat -c "path=%n uid=%u gid=%g mode=%a size=%s atime=%X mtime=%Y ctime=%Z" "$f" || true
      ls -l --time-style=full-iso "$f" || true
      has getfacl && getfacl -p "$f" || true
      has lsattr && lsattr "$f" || true
      has getfattr && getfattr -m - -d "$f" || true
      has file && file "$f" || true
      has getcap && getcap -v "$f" || true
      has readelf && readelf -h -S -n "$f" | head -n 200 || true
      has objdump && objdump -x "$f" | head -n 200 || true
      if has dpkg; then dpkg -S "$f" || echo "dpkg -S: no owner"; fi
      if has rpm;  then rpm -qf "$f" || echo "rpm -qf: no owner"; fi
      echo "--- HASH ---"; sha256sum "$f" || true; md5sum "$f" || true
      echo "--- STRINGS (head) ---"; strings -a "$f" | head -n 400 || true
    } > "${base}.txt" 2>&1
    dd if="$f" of="${base}.copy" bs=4M conv=noerror,sync status=none 2>>"$LOG_FILE" || true
  done
  systemctl status "$TARGET_UNIT" > "${AUD}/systemctl_status.txt" 2>&1 || true
  crontab -l > "${AUD}/root_crontab.txt" 2>&1 || true
  grep -R --line-number -E "/var/log/log|/usr/log|/usr/bin/log" /etc/cron* /var/spool/cron 2>/dev/null \
      > "${AUD}/cron_hits.txt" || true
}
collect_timeline(){
  local FOR="${EVD_DIR}/forensics"; mkdir -p "$FOR"
  local SINCE_USE; SINCE_USE="$(derive_since)"; log "取证 since=${SINCE_USE}"
  journalctl -u "$TARGET_UNIT" --since "$SINCE_USE" > "${FOR}/journal-python.txt" 2>&1 || true
  journalctl -xe --since "$SINCE_USE" > "${FOR}/journal-xe.txt" 2>&1 || true
  if [[ -f /var/log/auth.log ]]; then
    grep -Ei "Accepted|Failed|sudo|session|sshd" /var/log/auth.log* > "${FOR}/authlog.txt" 2>&1 || true
  elif [[ -f /var/log/secure ]]; then
    grep -Ei "Accepted|Failed|sudo|session|sshd" /var/log/secure* > "${FOR}/authlog.txt" 2>&1 || true
  fi
  last -F | head -n 200 > "${FOR}/last.txt" 2>&1 || true
  lastb -F | head -n 200 > "${FOR}/lastb.txt" 2>&1 || true
  mkdir -p "${FOR}/ssh"
  cp -a /etc/ssh/sshd_config "${FOR}/ssh/" 2>/dev/null || true
  for d in /root /home/*; do [[ -d "$d/.ssh" ]] && tar -czf "${FOR}/ssh/$(basename "$d")_ssh.tgz" -C "$d" .ssh >/dev/null 2>&1 || true; done
  if has dpkg; then
    cp -a /var/log/dpkg.log* "${FOR}/" 2>/dev/null || true
    zgrep -h " install " /var/log/dpkg.log* > "${FOR}/dpkg_install_timeline.txt" 2>/dev/null || true
  elif has rpm; then
    rpm -qa --last > "${FOR}/rpm_qa_last.txt" 2>&1 || true
    { has dnf && dnf history || has yum && yum history || true; } > "${FOR}/pkg_history.txt" 2>&1
  fi
  { ss -ptna || true; } > "${FOR}/ss_all.txt" 2>&1
  has ip && { ip addr show > "${FOR}/ip_addr.txt" 2>&1 || true; ip route show > "${FOR}/ip_route.txt" 2>&1 || true; }
  { iptables -S || true; ip6tables -S || true; nft list ruleset || true; } > "${FOR}/fw.txt" 2>&1
  local ref="/etc/systemd/system/${TARGET_UNIT}" REFT=""
  [[ -f "$ref" ]] && REFT="$(stat -c %y "$ref" | cut -d'.' -f1)"
  [[ -z "$REFT" ]] && while read -r p; do [[ -f "$p" ]] && { REFT="$(stat -c %y "$p" | cut -d'.' -f1)"; break; } done < <(find_exec_paths)
  if [[ -n "$REFT" ]]; then
    local start end
    start="$(date -d "$REFT -1 day" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$REFT")"
    end="$(date -d "$REFT +1 day" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")"
    echo "参考时间：$REFT；窗口：[$start, $end]" > "${FOR}/mtime_window.txt"
    find / -xdev -type f -newermt "$start" ! -newermt "$end" \
      -printf "%TY-%Tm-%Td %TH:%TM:%TS %u %g %m %s %p\n" 2>/dev/null | sort > "${FOR}/files_around_ref.txt" || true
  fi
}

# 处置 & 回滚
snap_begin(){ echo '{"timestamp":"'"$(timestamp)"'","unit":"'"$TARGET_UNIT"'","case_tag":"'"$CASE_TAG"'","actions":[' > "$SNAPSHOT"; }
snap_append(){ local j="$1"; if grep -q '"actions":\[' "$SNAPSHOT" && [[ $(tail -1 "$SNAPSHOT") != "["* ]]; then sed -i '$ s/$/,/' "$SNAPSHOT"; fi; echo "$j" >> "$SNAPSHOT"; }
snap_end(){ echo "]}" >> "$SNAPSHOT"; }

stop_service(){
  local was_active was_failed
  was_active=$(systemctl is-active "$TARGET_UNIT" 2>/dev/null || echo "unknown")
  was_failed=$(systemctl is-failed "$TARGET_UNIT" 2>/dev/null || echo "not-failed")
  systemctl stop "$TARGET_UNIT" 2>>"$LOG_FILE" || true
  systemctl reset-failed "$TARGET_UNIT" 2>>"$LOG_FILE" || true
  snap_append "$(jq -n --arg a service_stop_only --arg w "$was_active" --arg f "$was_failed" '{action:$a,was_active:$w,was_failed:$f}')"
  log "已停止 ${TARGET_UNIT}（was_active=${was_active}）"
}
resume_from_snapshot(){
  local file="$1"; [[ -f "$file" ]] || die "快照不存在：$file"
  has jq || die "恢复需要 jq（可先 --install-deps）"
  local U w
  U=$(jq -r '.unit // empty' "$file"); [[ -z "$U" ]] && U="$TARGET_UNIT"
  w=$(grep -o '"was_active":"[^"]*' "$file" | head -1 | cut -d'"' -f4 || echo "")
  [[ "$w" == "active" ]] && { systemctl start "$U" 2>>"$LOG_FILE" || true; log "已恢复启动 ${U}"; } || log "上次非运行态/未知，不自动启动（unit=$U）"
}

neutralize_strict(){
  local was_active; was_active=$(systemctl is-active "$TARGET_UNIT" 2>/dev/null || echo "unknown")
  systemctl stop "$TARGET_UNIT" 2>>"$LOG_FILE" || true
  systemctl mask --runtime "$TARGET_UNIT" 2>>"$LOG_FILE" || true
  snap_append "$(jq -n --arg a strict_runtime_mask --arg w "$was_active" '{action:$a,was_active:$w}')"
  log "严格处置：stop + mask --runtime（重启后不保留）"
}
runtime_dropin_apply(){
  local d="/run/systemd/system/${TARGET_UNIT}.d"
  mkdir -p "$d"
  cat > "${d}/override.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=/bin/false
EOF
  systemctl daemon-reload 2>>"$LOG_FILE" || true
  snap_append "$(jq -n --arg a strict_runtime_dropin --arg d "$d/override.conf" '{action:$a,dropin:$d}')"
  log "runtime drop-in 已写入：${d}/override.conf"
}
neutralize_standard(){
  local was_enabled was_active unit_path unit_bak
  was_enabled=$(systemctl is-enabled "$TARGET_UNIT" 2>/dev/null || echo "unknown")
  was_active=$(systemctl is-active "$TARGET_UNIT" 2>/dev/null || echo "inactive")
  unit_path="/etc/systemd/system/${TARGET_UNIT}"
  unit_bak=""
  systemctl stop "$TARGET_UNIT" 2>>"$LOG_FILE" || true
  systemctl disable "$TARGET_UNIT" 2>>"$LOG_FILE" || true
  [[ -f "$unit_path" ]] && { unit_bak="${QUAR_DIR}/${TARGET_UNIT}.$(date +%s).bak"; cp -a "$unit_path" "$unit_bak"; }
  snap_append "$(jq -n --arg a service_standard --arg we "$was_enabled" --arg wa "$was_active" --arg up "$unit_path" --arg ub "$unit_bak" '{action:$a,was_enabled:$we,was_active:$wa,unit_path:$up,unit_backup:$ub}')"

  local before="${QUAR_DIR}/root.cron.before.$(date +%s)" after="${QUAR_DIR}/root.cron.after.$(date +%s)"
  (crontab -l || true) > "$before" 2>>"$LOG_FILE" || true
  if grep -qE "/var/log/log|/usr/log|/usr/bin/log" "$before"; then
    sed '/\/var\/log\/log/d;/\/usr\/log/d;/\/usr\/bin\/log/d' "$before" > "$after"
    crontab "$after" 2>>"$LOG_FILE" || true
    snap_append "$(jq -n --arg a crontab_clean --arg before "$before" --arg after "$after" '{action:$a,before:$before,after:$after}')"
  fi

  mapfile -t EXEC_PATHS < <(find_exec_paths)
  for f in "${EXEC_PATHS[@]}"; do
    [[ -f "$f" ]] || continue
    local sum new; sum="$(sha256sum "$f" | awk '{print $1}')"
    new="${QUAR_DIR}/$(basename "$f").${sum}.quar"
    cp -a "$f" "$new"
    : > "$f"; chmod 000 "$f" || true
    snap_append "$(jq -n --arg a file_quarantine --arg src "$f" --arg dst "$new" --arg sha "$sum" '{action:$a,src:$src,dst:$dst,sha256:$sha}')"
    log "隔离：$f -> $new（源置空）"
  done
}
restore_from_snapshot(){
  local file="$1"; [[ -f "$file" ]] || die "快照不存在：$file"
  has jq || die "回滚需要 jq（可先 --install-deps）"
  local U; U=$(jq -r '.unit // empty' "$file"); [[ -z "$U" ]] && U="$TARGET_UNIT"
  log "从快照回滚：$file (unit=$U)"
  mapfile -t actions < <(jq -c '.actions[]' "$file")
  for a in "${actions[@]}"; do
    local act; act=$(echo "$a" | jq -r '.action')
    case "$act" in
      service_stop_only) : ;;
      strict_runtime_mask) systemctl unmask --runtime "$U" 2>>"$LOG_FILE" || true ;;
      strict_runtime_dropin)
        local drop="/run/systemd/system/${U}.d/override.conf"
        [[ -f "$drop" ]] && { rm -f "$drop"; rmdir "$(dirname "$drop")" 2>/dev/null || true; systemctl daemon-reload || true; }
        ;;
      service_standard)
        local unit_backup unit_path was_enabled was_active
        unit_backup=$(echo "$a" | jq -r '.unit_backup'); unit_path=$(echo "$a" | jq -r '.unit_path')
        was_enabled=$(echo "$a" | jq -r '.was_enabled'); was_active=$(echo "$a" | jq -r '.was_active')
        [[ -f "$unit_backup" && -n "$unit_path" ]] && cp -af "$unit_backup" "$unit_path" || true
        [[ "$was_enabled" == "enabled" ]] && systemctl enable "$U" || systemctl disable "$U" || true
        [[ "$was_active" == "active"  ]] && systemctl start "$U"  || systemctl stop "$U"  || true
        systemctl daemon-reload || true
        ;;
      crontab_clean)
        local before; before=$(echo "$a" | jq -r '.before')
        [[ -f "$before" ]] && crontab "$before" || true
        ;;
      file_quarantine)
        local src dst; src=$(echo "$a" | jq -r '.src'); dst=$(echo "$a" | jq -r '.dst')
        [[ -f "$dst" ]] && { cp -af "$dst" "$src" || true; chmod 755 "$src" || true; }
        ;;
    esac
  done
  log "回滚完成。"
}

analyze(){
  log "开始自动研判 (--analyze)"
  local AUD="${EVD_DIR}/audit"; local SHOW="${EVD_DIR}/${TARGET_UNIT}.show.txt"
  local score=0 reasons=() verdict="Unclear"
  echo "# Incident Analysis Report" > "$REPORT"
  echo "" >> "$REPORT"
  echo "- Host tag: ${CASE_TAG:-n/a}" >> "$REPORT"
  echo "- Unit: $TARGET_UNIT" >> "$REPORT"
  echo "- Timestamp: $(timestamp)" >> "$REPORT"
  echo "- Working dir: $BASE_DIR" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "## Findings" >> "$REPORT"

  mapfile -t EXEC_PATHS < <(find_exec_paths)
  local exec_list=""
  for f in "${EXEC_PATHS[@]}"; do
    [[ -e "$f" ]] || continue
    local base="${AUD}/file_$(echo "$f" | sed 's#/#_#g').txt"
    local sha_line; sha_line=$(grep -m1 -E '^[0-9a-f]{64}\s' "$base" 2>/dev/null || true)
    local sha; sha=$(echo "$sha_line" | awk '{print $1}')
    echo "- Exec: \`$f\`  SHA256: \`${sha:-unknown}\`" >> "$REPORT"
    exec_list+="$f "
  done
  [[ -z "$exec_list" ]] && echo "- Exec: (not found on disk)" >> "$REPORT"

  if echo "$exec_list" | grep -Eq '(/var/log/log|/usr/log|/usr/bin/log)'; then
    score=$((score+30)); reasons+=("非常规可执行路径（/var/log 或伪装 log）(+30)")
  fi
  if [[ -n "$exec_list" ]]; then
    local mismatch=0; for f in $exec_list; do [[ "$(basename "$f")" =~ ^python ]] || mismatch=1; done
    (( mismatch==1 )) && { score=$((score+10)); reasons+=("unit 名与二进制不符 (+10)"); }
  fi
  [[ -s "${AUD}/root_crontab.txt" ]] && grep -Eq '/var/log/log|/usr/log|/usr/bin/log' "${AUD}/root_crontab.txt" && { score=$((score+20)); reasons+=("root crontab 可疑 (+20)"); }
  [[ -s "${AUD}/cron_hits.txt"     ]] && { score=$((score+10)); reasons+=("系统 cron 命中可疑 (+10)"); }
  for f in $exec_list; do
    local base="${AUD}/file_$(echo "$f" | sed 's#/#_#g').txt"
    grep -qE 'dpkg -S: no owner|rpm -qf: no owner' "$base" 2>/dev/null && { score=$((score+15)); reasons+=("可执行不归属包 (+15)"); break; }
  done
  local net_hit=0
  if [[ -s "${AUD}/suspect_pids.txt" ]]; then
    while read -r pid; do [[ -s "${AUD}/proc_${pid}/ss.txt" ]] && grep -Eq 'ESTAB|LISTEN' "${AUD}/proc_${pid}/ss.txt" && { net_hit=1; break; }; done < "${AUD}/suspect_pids.txt"
  fi
  (( net_hit==1 )) && { score=$((score+10)); reasons+=("可疑进程网络活动 (+10)"); }
  local mem_big=0
  if [[ -s "${AUD}/suspect_pids.txt" ]]; then
    while read -r pid; do
      if [[ -s "${AUD}/proc_${pid}/status.txt" ]]; then
        local rss_kb; rss_kb=$(awk '/VmRSS:/{print $2}' "${AUD}/proc_${pid}/status.txt" 2>/dev/null || echo 0)
        (( rss_kb>204800 )) && { mem_big=2; break; }
        (( rss_kb>51200 ))  && { mem_big=1; }
      fi
    done < "${AUD}/suspect_pids.txt"
  fi
  (( mem_big==2 )) && { score=$((score+10)); reasons+=("单进程内存 >200MB (+10)"); }
  (( mem_big==1 )) && { score=$((score+5)); reasons+=("单进程内存 50~200MB (+5)"); }
  for f in $exec_list; do
    local base="${AUD}/file_$(echo "$f" | sed 's#/#_#g').txt"
    grep -Eqi 'curl|wget|http://|https://|base64|eval|/tmp|/dev/shm|nohup|chattr|xmrig|minerd|crypto' "$base" && { score=$((score+10)); reasons+=("strings 可疑关键字 (+10)"); break; }
  done
  [[ -s "$SHOW" ]] && grep -q 'FragmentPath=/etc/systemd/system/' "$SHOW" && { score=$((score+5)); reasons+=("unit 为本地自建（/etc/systemd/system）(+5)"); }

  local verdict="Unclear"; (( score>=60 )) && verdict="Malicious likely"; (( score>=30 )) && verdict="Suspicious"

  {
    echo ""
    echo "### Rule hits & reasons"
    for r in "${reasons[@]}"; do echo "- $r"; done
    echo ""
    echo "### Score"
    echo "- Total score: **$score** (>=60: Malicious likely, 30-59: Suspicious, <30: Unclear/Benign)"
    echo ""
    echo "## Verdict"
    echo "- **$verdict**"
    echo ""
    echo "## Recommended actions"
    if [[ "$verdict" == "Malicious likely" ]]; then
      cat <<'RMD'
1. **立即阻断（不改现场）：** `--strict --neutralize --runtime-dropin`
2. **永久清理（可回滚）：** `--neutralize`
3. **凭据轮换**、**横向排查**、**日志复盘**、**离线样本分析**。
RMD
    elif [[ "$verdict" == "Suspicious" ]]; then
      cat <<'RMD'
1. 先 `--suspend` 观察，必要时 `--resume`。
2. 证据增强后转 `--strict --neutralize`；窗口期做 `--neutralize` 永久清理。
RMD
    else
      cat <<'RMD'
证据不足以定性。建议扩大 `--since` 窗口与基线比对，保持 `--suspend` 观察。
RMD
    fi
  } >> "$REPORT"
  log "分析报告已生成：$REPORT"
}

############################################
# 主流程
############################################
require_root
detect_os_pm

if (( CHECK_DEPS )); then check_deps; exit 0; fi
if (( INSTALL_DEPS )); then install_deps; exit 0; fi
[[ -n "$ROLLBACK_DEPS_FILE" ]] && { rollback_deps "$ROLLBACK_DEPS_FILE"; exit 0; }

log "IR start unit=${TARGET_UNIT} strict=${STRICT} runtime-dropin=${RUNTIME_DROPIN} neutralize=${NEUTRALIZE} suspend=${SUSPEND_ONLY} resume=${RESUME_FILE:+yes} restore=${RESTORE_FILE:+yes} analyze=${ANALYZE} tag=${CASE_TAG:-none}"
log "输出目录：${BASE_DIR}"

collect_unit
audit_process_and_files
collect_timeline

if (( AUDIT_ONLY )); then
  log "按 --audit-only：不进行处置。"
else
  if (( SUSPEND_ONLY )); then
    json_begin; stop_service; json_end
    log "仅停止动作完成。使用：--resume ${SNAPSHOT} 进行恢复。"
  elif (( NEUTRALIZE )); then
    json_begin
    if (( STRICT )); then
      neutralize_strict
      (( RUNTIME_DROPIN )) && runtime_dropin_apply
    else
      neutralize_standard
    fi
    json_end
    log "处置完成。快照：$SNAPSHOT"
  fi
fi

[[ -n "$RESUME_FILE" ]]  && resume_from_snapshot "$RESUME_FILE"
[[ -n "$RESTORE_FILE" ]] && restore_from_snapshot "$RESTORE_FILE"
(( ANALYZE )) && analyze

TAR="${BASE_DIR}/ir-python${CASE_TAG:+-$CASE_TAG}-${TS}.tar.gz"
tar -czf "$TAR" -C "$(dirname "$BASE_DIR")" "$(basename "$BASE_DIR")" >/dev/null 2>&1 || true
log "归档完成：$TAR"
log "全部完成。"
exit 0
