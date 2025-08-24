#!/usr/bin/env bash

# ==============================
# Linux 合规整改脚本
# 
# 本脚本用于自动化修复常见的等保合规项，包括：
#   1. 配置密码复杂度策略（pam_pwquality，长度>=12，含大小写/数字/特殊字符，重试3，root生效）
#   2. 配置日志轮转策略（logrotate，按月轮转，保留7个月）
#   3. 限制历史命令条数（/etc/profile，HISTSIZE=10）
#
# 使用方法：
#   1. 预览整改变更（不实际修改，仅显示diff）：
#        sudo bash linux_compliance.sh --preview
#   2. 执行整改（自动备份原文件，实际修改）：
#        sudo bash linux_compliance.sh --apply
#   3. 回滚整改（恢复指定备份目录）：
#        sudo bash linux_compliance.sh --rollback <备份目录>
#   4. 安装依赖（如缺少rsync/expect等）：
#        sudo bash linux_compliance.sh --deps-install
#
# 日志文件：/var/log/compliance_fix.log
# 备份目录：/var/backups/compliance_时间戳/
#
# 适用系统：主流RHEL/CentOS/Rocky/AlmaLinux/Debian/Ubuntu
#
# 详细合规项及整改建议请参考 safe/等保/不符合项.md
# ==============================


set -euo pipefail

LOG="/var/log/compliance_fix.log"
BACKUP_ROOT="/var/backups"
TS="$(date +%Y%m%d%H%M%S)"
DATE_TAG="$(date +%Y%m%d)"
BACKUP_DIR="${BACKUP_ROOT}/compliance_${TS}"
MODE="${1:-}"

log(){ printf '[%s] %s\n' "$(date +'%F %T%z')" "$*" | tee -a "$LOG"; }
run(){ echo "+ $*" | tee -a "$LOG"; eval "$@" | tee -a "$LOG"; }
need(){ command -v "$1" >/dev/null 2>&1; }
trap 'log "发生错误，请查看日志：$LOG；备份目录（若已创建）：$BACKUP_DIR"' ERR

detect_distro(){
  . /etc/os-release || true
  local fam="other"
  [[ "${ID_LIKE:-}${ID:-}" =~ (rhel|centos|fedora|rocky|almalinux) ]] && fam="rhel"
  [[ "${ID_LIKE:-}${ID:-}" =~ (debian|ubuntu) ]] && fam="debian"
  echo "$fam"
}

# ---------- 依赖管理 ----------
PKGS_NEED_DEBIAN=(rsync expect libpam-pwquality)
PKGS_NEED_RHEL=(rsync expect pam_pwquality)

is_pkg_installed(){
  local fam="$1" pkg="$2"
  if [[ "$fam" == "debian" ]]; then dpkg -s "$pkg" >/dev/null 2>&1
  elif [[ "$fam" == "rhel" ]]; then rpm -q "$pkg" >/dev/null 2>&1
  else return 1; fi
}

install_pkgs(){
  local fam; fam="$(detect_distro)"
  local -a wants=()
  if [[ "$fam" == "debian" ]]; then wants=("${PKGS_NEED_DEBIAN[@]}")
  else wants=("${PKGS_NEED_RHEL[@]}"); fi

  mkdir -p "$BACKUP_DIR"
  local meta="$BACKUP_DIR/meta_installed_by_script.txt"
  : > "$meta"

  local -a to_install=()
  for p in "${wants[@]}"; do
    if ! is_pkg_installed "$fam" "$p"; then to_install+=("$p"); fi
  done
  if [[ ${#to_install[@]} -eq 0 ]]; then
    log "依赖齐全，无需安装。"
    return 0
  fi
  log "需要安装：${to_install[*]}"

  if [[ "$fam" == "debian" ]]; then
    run "apt-get update"
    run "DEBIAN_FRONTEND=noninteractive apt-get install -y ${to_install[*]}"
  else
    if command -v dnf >/dev/null 2>&1; then
      run "dnf install -y ${to_install[*]}"
    else
      run "yum install -y ${to_install[*]}"
    fi
  fi
  printf '%s\n' "${to_install[@]}" > "$meta"
  log "记录已由脚本安装的包：$meta"
}

deps_check(){
  local fam; fam="$(detect_distro)"
  local ok=true
  for b in rsync expect; do
    if need "$b"; then log "依赖存在：$b"; else log "缺少依赖：$b"; ok=false; fi
  done
  # 检查 pam_pwquality 模块文件
  local mod_found=""; for d in /lib/security /lib64/security /usr/lib/security /usr/lib64/security /lib/x86_64-linux-gnu/security; do
    [[ -f "$d/pam_pwquality.so" ]] && mod_found="$d/pam_pwquality.so" && break
  done
  if [[ -n "$mod_found" ]]; then log "检测到 pam_pwquality 模块：$mod_found"; else log "未发现 pam_pwquality.so，请安装包（debian: libpam-pwquality / rhel: pam_pwquality）"; ok=false; fi

  # 包层面检查
  if [[ "$fam" == "debian" ]]; then
    for p in "${PKGS_NEED_DEBIAN[@]}"; do is_pkg_installed "$fam" "$p" && log "包已安装：$p" || { log "缺包：$p"; ok=false; }; done
  else
    for p in "${PKGS_NEED_RHEL[@]}"; do is_pkg_installed "$fam" "$p" && log "包已安装：$p" || { log "缺包：$p"; ok=false; }; done
  fi
  $ok && log "依赖检查通过" || { log "依赖不完整"; return 1; }
}

deps_rollback(){
  local b="$2"; [[ -n "$b" && -d "$b" ]] || { log "用法：$0 --deps-rollback <备份目录>"; exit 1; }
  local meta="$b/meta_installed_by_script.txt"
  [[ -f "$meta" ]] || { log "未找到 $meta，无法判断由脚本安装的包"; exit 1; }
  local fam; fam="$(detect_distro)"
  mapfile -t pkgs < "$meta"
  if [[ ${#pkgs[@]} -eq 0 ]]; then log "没有记录需卸载的包"; return 0; fi
  log "准备卸载由脚本安装的包：${pkgs[*]}"
  if [[ "$fam" == "debian" ]]; then
    run "apt-get remove -y ${pkgs[*]}"
    run "apt-get autoremove -y"
  else
    if command -v dnf >/dev/null 2>&1; then run "dnf remove -y ${pkgs[*]}"; else run "yum remove -y ${pkgs[*]}"; fi
  fi
  log "依赖回撤完成"
}

# ---------- 通用工具 ----------
ensure_backup(){ run "mkdir -p '$BACKUP_DIR'"; }
rsync_backup(){
  local src="$1" rel="$1"
  local dest="${BACKUP_DIR}${rel}"
  run "mkdir -p '$(dirname "$dest")'"
  run "rsync -a --numeric-ids --inplace '$src' '$dest'"
}
preview_diff(){
  local orig="$1" temp="$2"
  if [[ -f "$orig" ]]; then diff -u "$orig" "$temp" || true; else echo "（新增文件）$orig"; cat "$temp"; fi
}

comment_and_replace_line(){
  # $1: file  $2: match_regex  $3: new_line  $4: remark
  awk -v r="$2" -v nl="$3" -v rm="$4" '
    BEGIN{done=0}
    {
      if ($0 ~ r && $0 !~ /^[[:space:]]*#/) {
        print "# " rm
        print "# " $0
        print nl
        done=1
      } else { print $0 }
    }
    END{
      if (done==0) {
        print "# " rm
        print nl
      }
    }
  ' "$1"
}

# ---------- 具体整改 ----------
fix_pam_pwquality(){
  local fam file
  fam="$(detect_distro)"
  if [[ "$fam" == "rhel" ]]; then file="/etc/pam.d/system-auth"; else file="/etc/pam.d/common-password"; fi
  [[ -f "$file" ]] || { log "跳过：未找到 $file"; return 0; }
  local tmp; tmp="$(mktemp)"
  local remark="合规需要整改-pam_pwquality策略增强（长度>=12，含大小写/数字/特殊字符，重试3，root生效）-${DATE_TAG}"
  local new="password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 minlen=12 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root"

  comment_and_replace_line "$file" "pam_pwquality[.]so" "$new" "$remark" > "$tmp"

  if [[ "$MODE" == "--preview" ]]; then
    echo "== PAM 变更预览：$file =="; preview_diff "$file" "$tmp"; rm -f "$tmp"; return 0
  fi
  ensure_backup; rsync_backup "$file"
  run "install -m 0644 -o root -g root '$tmp' '$file'"; rm -f "$tmp"
}

fix_logrotate(){
  local file="/etc/logrotate.conf"; [[ -f "$file" ]] || { log "跳过：未找到 $file"; return 0; }
  local tmp; tmp="$(mktemp)"
  awk -v d="$DATE_TAG" '
    function rw(){print "# 合规需要整改-日志保留至少6个月，当前为按月，轮转7，保留即7个月-" d}
    function rr(){print "# 合规需要整改-rotate修改为7（按实际）-" d}
    {
      if ($0 ~ /^[[:space:]]*weekly[[:space:]]*$/) { print rw(); print "# " $0; print "monthly" }
      else if ($0 ~ /^[[:space:]]*rotate[[:space:]]+[0-9]+[[:space:]]*$/) { print rr(); print "# " $0; print "rotate 7" }
      else { print $0 }
    }
  ' "$file" > "$tmp"

  if [[ "$MODE" == "--preview" ]]; then
    echo "== logrotate 预览：$file =="; preview_diff "$file" "$tmp"; rm -f "$tmp"; return 0
  fi
  ensure_backup; rsync_backup "$file"
  run "install -m 0644 -o root -g root '$tmp' '$file'"; rm -f "$tmp"
}

fix_histsize(){
  local file="/etc/profile"; [[ -f "$file" ]] || { log "跳过：未找到 $file"; return 0; }
  local tmp; tmp="$(mktemp)"
  local remark="合规需要整改-HISTSIZE修改为10即历史命令保留10条-${DATE_TAG}"
  local new="HISTSIZE=10"
  awk -v rm="$remark" -v nl="$new" '
    BEGIN{found=0}
    {
      if ($0 ~ /^[[:space:]]*HISTSIZE[[:space:]]*=/ && $0 !~ /^[[:space:]]*#/) {
        print "# " rm; print "# " $0; print nl; found=1
      } else { print $0 }
    }
    END{ if(found==0){ print ""; print "# " rm; print nl } }
  ' "$file" > "$tmp"

  if [[ "$MODE" == "--preview" ]]; then
    echo "== HISTSIZE 预览：$file =="; preview_diff "$file" "$tmp"; rm -f "$tmp"; return 0
  fi
  ensure_backup; rsync_backup "$file"
  run "install -m 0644 -o root -g root '$tmp' '$file'"; rm -f "$tmp"
}

do_preview(){ log "仅预览"; fix_pam_pwquality; fix_logrotate; fix_histsize; log "预览完成"; }
do_apply(){
  log "开始合规整改（日志：$LOG）"
  need rsync || { log "缺少 rsync；可执行：$0 --deps-install"; exit 1; }
  fix_pam_pwquality
  fix_logrotate
  fix_histsize
  log "整改完成。备份目录：$BACKUP_DIR"
}
do_rollback(){
  local b="${2:-}"; [[ -n "$b" && -d "$b" ]] || { log "用法：$0 --rollback <备份目录>"; exit 1; }
  log "回滚：$b"
  for f in /etc/pam.d/system-auth /etc/pam.d/common-password /etc/logrotate.conf /etc/profile; do
    if [[ -f "$f" && -f "${b}${f}" ]]; then run "rsync -a --numeric-ids --inplace '${b}${f}' '$f'"; fi
  done
  log "回滚完成"
}

# ---------- 改后验证 ----------
verify_policy(){
  # 前置检查
  deps_check || true
  need expect || { log "缺少 expect；请先 $0 --deps-install"; exit 1; }

  local fam file
  fam="$(detect_distro)"
  if [[ "$fam" == "rhel" ]]; then file="/etc/pam.d/system-auth"; else file="/etc/pam.d/common-password"; fi
  grep -q 'pam_pwquality' "$file" || log "警告：$file 未包含 pam_pwquality（验证可能无效）"

  local user="complytest_${TS}"
  local shell="/usr/sbin/nologin"; [[ -x "$shell" ]] || shell="/sbin/nologin"; [[ -x "$shell" ]] || shell="/bin/false"

  run "useradd -m -s '$shell' '$user'"

  # 预期失败的弱口令（<12 且无复杂字符）
  local weak="abc123"
  # 预期成功的强口令（>=12，含大小写/数字/特殊字符）
  local strong="Abcdef12!@#$(head -c2 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c2)"

  cat > /tmp/pass_try_weak.exp <<'EOF'
#!/usr/bin/expect -f
set timeout 10
set user [lindex $argv 0]
set pwd  [lindex $argv 1]
spawn passwd $user
expect "New password:"
send -- "$pwd\r"
expect "Retype new password:"
send -- "$pwd\r"
expect {
  -re "(BAD PASSWORD|password.*too.*simple|short|not.*complex)" { exit 3 }
  -re "updated successfully" { exit 0 }
  timeout { exit 2 }
}
EOF
  chmod +x /tmp/pass_try_weak.exp

  cat > /tmp/pass_try_strong.exp <<'EOF'
#!/usr/bin/expect -f
set timeout 10
set user [lindex $argv 0]
set pwd  [lindex $argv 1]
spawn passwd $user
expect "New password:"
send -- "$pwd\r"
expect "Retype new password:"
send -- "$pwd\r"
expect {
  -re "updated successfully" { exit 0 }
  -re "(BAD PASSWORD|not.*complex|short)" { exit 3 }
  timeout { exit 2 }
}
EOF
  chmod +x /tmp/pass_try_strong.exp

  log "尝试设置弱口令，应当失败：$weak"
  set +e
  /tmp/pass_try_weak.exp "$user" "$weak"; rc_w=$?
  set -e
  if [[ $rc_w -eq 3 ]]; then log "弱口令验证：按预期被拒绝 ✅"
  else log "弱口令验证：未被拒绝（rc=$rc_w）⚠️，请检查 PAM 配置"; fi

  log "尝试设置强口令，应当成功（长度>=12，含大小写/数字/特殊字符）"
  set +e
  /tmp/pass_try_strong.exp "$user" "$strong"; rc_s=$?
  set -e
  if [[ $rc_s -eq 0 ]]; then log "强口令验证：成功 ✅"
  else log "强口令验证：失败（rc=$rc_s）❌，请检查 pam_pwquality 参数"; fi

  run "userdel -r '$user' || true"
  rm -f /tmp/pass_try_weak.exp /tmp/pass_try_strong.exp
  log "策略验证完成"
}

# ---------- 备份对比（显示 +/-） ----------
do_diff(){
  local b="${2:-}"; [[ -n "$b" && -d "$b" ]] || { log "用法：$0 --diff <备份目录>"; exit 1; }
  for f in /etc/pam.d/system-auth /etc/pam.d/common-password /etc/logrotate.conf /etc/profile; do
    if [[ -f "$f" && -f "${b}${f}" ]]; then
      echo "==== diff: $f vs ${b}${f} ====" | tee -a "$LOG"
      diff -u "${b}${f}" "$f" || true
    fi
  done
  log "对比完成（以上 diff 显示 - 为备份旧行，+ 为当前新行）"
}

# ---------- 入口 ----------
case "$MODE" in
  --deps-check) deps_check ;;
  --deps-install) install_pkgs ;;
  --deps-rollback) deps_rollback "$@" ;;
  --preview) do_preview ;;
  --apply) do_apply ;;
  --rollback) do_rollback "$@" ;;
  --verify-policy) verify_policy ;;
  --diff) do_diff "$@" ;;
  *) echo "用法:
  $0 --deps-check | --deps-install | --deps-rollback <备份目录>
  $0 --preview | --apply | --rollback <备份目录>
  $0 --verify-policy | --diff <备份目录>
"; exit 1 ;;
esac
