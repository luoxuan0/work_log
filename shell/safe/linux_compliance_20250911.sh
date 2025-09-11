#!/usr/bin/env bash

# ==============================
# 统一文件存放配置 - 全部放到 /var/backups/compliance 下
# ==============================

# 基础目录
COMPLIANCE_ROOT="/var/backups/compliance"

# 时间相关变量
TS="$(date +%Y%m%d%H%M%S)"
DATE_TAG="$(date +%Y%m%d)"
YEAR_MONTH="$(date +%Y/%m)"

# 统一目录结构
COMPLIANCE_DIR="${COMPLIANCE_ROOT}/${YEAR_MONTH}"
SESSION_DIR="${COMPLIANCE_DIR}/compliance_${TS}"

# 具体文件路径
LOG_FILE="${SESSION_DIR}/compliance_fix_${TS}.log"
BACKUP_DIR="${SESSION_DIR}/backups"
STATE_DIR="${SESSION_DIR}/state"
CONFIG_DIR="${SESSION_DIR}/config"
DEPS_REC="${STATE_DIR}/deps_installed_${TS}.list"

# 创建必要目录
ensure_directories() {
    local dirs=("$SESSION_DIR" "$BACKUP_DIR" "$STATE_DIR" "$CONFIG_DIR")
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && run "mkdir -p '$dir'"
    done
}

# 设置目录权限
set_permissions() {
    # 基础目录权限
    chmod 755 "$COMPLIANCE_ROOT" 2>/dev/null || true
    chmod 755 "$COMPLIANCE_DIR" 2>/dev/null || true
    
    # 会话目录权限（包含敏感信息）
    chmod 700 "$SESSION_DIR" 2>/dev/null || true
    
    # 日志文件权限
    [[ -f "$LOG_FILE" ]] && chmod 644 "$LOG_FILE" 2>/dev/null || true
    
    # 依赖记录权限
    [[ -f "$DEPS_REC" ]] && chmod 600 "$DEPS_REC" 2>/dev/null || true
}

# 清理旧文件（保留最近N个月）
cleanup_old_files() {
    local keep_months=${1:-12}  # 默认保留12个月
    log "清理${keep_months}个月前的旧文件"
    
    # 计算保留的月份
    local cutoff_date=$(date -d "${keep_months} months ago" +%Y/%m 2>/dev/null || date -v-${keep_months}m +%Y/%m 2>/dev/null || echo "")
    
    if [[ -n "$cutoff_date" ]]; then
        # 删除旧的月份目录
        find "$COMPLIANCE_ROOT" -type d -name "20*" | while read dir; do
            local dir_date=$(basename "$(dirname "$dir")")/$(basename "$dir")
            if [[ "$dir_date" < "$cutoff_date" ]]; then
                log "删除旧目录：$dir"
                rm -rf "$dir" 2>/dev/null || true
            fi
        done
    fi
    
    # 清理临时文件
    find /tmp -name "pwq_*_${TS}.log" -mtime +1 -delete 2>/dev/null || true
}

# 磁盘空间检查
check_disk_space() {
    local threshold=85  # 85%阈值
    local usage=$(df "$COMPLIANCE_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $usage -gt $threshold ]]; then
        log "警告：磁盘使用率 ${usage}% 超过阈值 ${threshold}%"
        log "建议执行清理：$0 --cleanup"
    fi
}

# 显示存储使用情况
show_storage_usage() {
    log "=== 存储使用情况 ==="
    log "合规文件根目录：$COMPLIANCE_ROOT"
    
    if [[ -d "$COMPLIANCE_ROOT" ]]; then
        local total_size=$(du -sh "$COMPLIANCE_ROOT" 2>/dev/null | cut -f1)
        log "总使用空间：$total_size"
        
        log "按月份统计："
        find "$COMPLIANCE_ROOT" -maxdepth 1 -type d -name "20*" | sort | while read dir; do
            local month=$(basename "$dir")
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local count=$(find "$dir" -type d -name "compliance_*" | wc -l)
            log "  $month: $size (${count}个会话)"
        done
    else
        log "目录不存在"
    fi
}

# ==============================
# Linux 合规整改脚本（精简版/分步版）
#
# 本脚本用于自动化修复常见的等保合规项，包括：
#   1. 配置密码复杂度策略（pam_pwquality，长度>=12，含大小写/数字/特殊字符，重试3，root生效）
#   2. 配置日志轮转策略（logrotate，按月轮转，保留7个月）
#   3. 限制历史命令条数（/etc/profile，HISTSIZE=29）
#
# 使用方法（示例）：
#   1. 预览整改变更（不实际修改，仅显示diff）：
#        sudo bash linux_compliance_1.sh --preview
#   2. 执行整改（自动备份原文件，实际修改）：
#        sudo bash linux_compliance_1.sh --apply
#   3. 校验整改项（仅检查当前配置是否合规）：
#        sudo bash linux_compliance_1.sh --verify
#   4. 显示变更内容（与备份对比diff）：
#        sudo bash linux_compliance_1.sh --show-changes [会话目录]
#   5. 检查依赖（如rsync/expect/pam_pwquality等）：
#        sudo bash linux_compliance_1.sh --check-deps
#   6. 安装依赖（自动安装缺失依赖）：
#        sudo bash linux_compliance_1.sh --install-deps
#   7. 回撤依赖（卸载本脚本安装的依赖）：
#        sudo bash linux_compliance_1.sh --rollback-deps
#   8. 回滚整改（恢复指定备份目录）：
#        sudo bash linux_compliance_1.sh --rollback [会话目录]
#   9. 清理旧文件（保留指定月数）：
#        sudo bash linux_compliance_1.sh --cleanup [月数]
#   10. 显示存储使用情况：
#        sudo bash linux_compliance_1.sh --storage-usage
#
# 文件存放结构：
#   /var/backups/compliance/YYYY/MM/compliance_时间戳/
#   ├── compliance_fix_时间戳.log          # 执行日志
#   ├── backups/                           # 系统文件备份
#   │   ├── etc/pam.d/system-auth
#   │   ├── etc/pam.d/common-password
#   │   ├── etc/logrotate.conf
#   │   └── etc/profile
#   ├── state/                             # 状态文件
#   │   └── deps_installed_时间戳.list     # 依赖安装记录
#   └── config/                            # 配置文件
#
# 适用系统：主流RHEL/CentOS/Rocky/AlmaLinux/Debian/Ubuntu
#
# 详细合规项及整改建议请参考 safe/等保/不符合项.md
# ==============================

set -euo pipefail

# 使用新的统一路径
LOG="$LOG_FILE"
BACKUP_ROOT="$BACKUP_DIR"
MODE="${1:-}"

log(){ printf '[%s] %s\n' "$(date +'%F %T%z')" "$*" | tee -a "$LOG"; }
run(){ echo "+ $*" | tee -a "$LOG"; eval "$@" | tee -a "$LOG"; }
need(){ command -v "$1" >/dev/null 2>&1 || { log "缺少依赖：$1"; return 1; }; }
die(){ log "错误：$*"; exit 1; }

trap 'log "发生错误；查看 $LOG。备份目录（若已创建）：$BACKUP_DIR"' ERR

distro_family(){
  . /etc/os-release 2>/dev/null || true
  local fam="other"
  if [[ "${ID_LIKE:-}${ID:-}" =~ (rhel|centos|fedora|rocky|almalinux) ]]; then fam="rhel"; fi
  if [[ "${ID_LIKE:-}${ID:-}" =~ (debian|ubuntu) ]]; then fam="debian"; fi
  echo "$fam"
}

pkg_mgr(){
  if command -v apt-get >/dev/null; then echo "apt"; return; fi
  if command -v dnf >/dev/null; then echo "dnf"; return; fi
  if command -v yum >/dev/null; then echo "yum"; return; fi
  echo "none"
}

pwquality_so_path(){
  # 常见路径枚举
  for p in \
    /lib/security/pam_pwquality.so \
    /usr/lib/security/pam_pwquality.so \
    /lib/x86_64-linux-gnu/security/pam_pwquality.so \
    /usr/lib64/security/pam_pwquality.so; do
    [[ -f "$p" ]] && { echo "$p"; return; }
  done
  echo ""
}

ensure_backup_root(){ 
    ensure_directories
    set_permissions
}

resolve_symlink(){ # 打印真实路径（若存在）
  local f="$1"
  if [[ -L "$f" ]]; then readlink -f "$f" || true; else echo "$f"; fi
}

# 新增：获取原始文件路径和符号链接状态
get_real_and_link_status() {
  local f="$1"
  local real
  if [[ -L "$f" ]]; then
    real="$(readlink -f "$f" || echo "$f")"
    echo "$real symlink"
  else
    echo "$f regular"
  fi
}

rsync_backup(){
  local src="$1" rel="$2"
  local real_src; real_src="$(resolve_symlink "$src")"
  [[ -e "$real_src" ]] || return 0
  local dest="${BACKUP_DIR}${rel}"
  run "mkdir -p '$(dirname "$dest")'"
  run "rsync -a --numeric-ids --inplace '$real_src' '$dest'"
}

preview_diff(){
  local orig="$1" temp="$2"
  local real_orig; real_orig="$(resolve_symlink "$orig")"
  if [[ -f "$real_orig" ]]; then
    diff -u "$real_orig" "$temp" || true
  else
    echo "（新增文件）$orig"
    cat "$temp"
  fi
}

comment_and_replace_line(){
  local f="$1" regex="$2" newline="$3" remark="$4"
  awk -v r="$regex" -v nl="$newline" -v rm="$remark" '
    BEGIN{done=0}
    {
      if ($0 ~ r && $0 !~ /^[[:space:]]*#/) {
        print "# " rm
        print "# " $0
        print nl
        done=1
      } else {
        print $0
      }
    }
    END{
      if (done==0) {
        print "# " rm
        print nl
      }
    }
  ' "$f"
}

# ---------- 依赖相关 ----------
check_deps(){
  log "开始依赖检查"
  need rsync
  local fam; fam="$(distro_family)"
  local mgr; mgr="$(pkg_mgr)"
  [[ "$mgr" != "none" ]] || die "未识别包管理器（apt/dnf/yum）"
  log "包管理器：$mgr；发行版族：$fam"

  local so; so="$(pwquality_so_path)"
  if [[ -n "$so" ]]; then
    log "pam_pwquality.so 存在：$so"
  else
    log "pam_pwquality.so 不存在，需要安装对应软件包"
  fi
  log "依赖检查完成"
}

install_deps(){
  log "安装依赖开始"
  local mgr; mgr="$(pkg_mgr)"; [[ "$mgr" != "none" ]] || die "未识别包管理器"
  local fam; fam="$(distro_family)"
  local pkgs=()
  if [[ "$fam" == "debian" ]]; then
    pkgs+=(libpam-pwquality)
  else
    pkgs+=(pam_pwquality)
  fi

  # 记录"需要安装且当前尚未安装"的包
  : > "$DEPS_REC.tmp"
  for p in "${pkgs[@]}"; do
    if dpkg -s "$p" >/dev/null 2>&1 || rpm -q "$p" >/dev/null 2>&1; then
      log "已安装：$p"
    else
      echo "$p" >> "$DEPS_REC.tmp"
    fi
  done

  if [[ -s "$DEPS_REC.tmp" ]]; then
    case "$mgr" in
      apt)
        run "apt-get update"
        run "DEBIAN_FRONTEND=noninteractive apt-get install -y $(tr '\n' ' ' < "$DEPS_REC.tmp")"
        ;;
      dnf) run "dnf install -y $(tr '\n' ' ' < "$DEPS_REC.tmp")" ;;
      yum) run "yum install -y $(tr '\n' ' ' < "$DEPS_REC.tmp")" ;;
    esac
    # 合并记录（累积）
    touch "$DEPS_REC"
    cat "$DEPS_REC.tmp" >> "$DEPS_REC"
    sort -u -o "$DEPS_REC" "$DEPS_REC"
    log "依赖安装完成；记录于 $DEPS_REC"
  else
    log "依赖均已满足，无需安装"
  fi
  rm -f "$DEPS_REC.tmp"
}

rollback_deps(){
  log "仅回撤依赖开始"
  [[ -f "$DEPS_REC" ]] || die "找不到依赖记录：$DEPS_REC"
  local mgr; mgr="$(pkg_mgr)"; [[ "$mgr" != "none" ]] || die "未识别包管理器"
  local list; list="$(tr '\n' ' ' < "$DEPS_REC")"
  [[ -n "$list" ]] || { log "记录为空，无需回撤"; return 0; }
  case "$mgr" in
    apt) run "apt-get remove -y $list" ;;
    dnf) run "dnf remove -y $list" ;;
    yum) run "yum remove -y $list" ;;
  esac
  run "rm -f '$DEPS_REC'"
  log "依赖已回撤"
}

# ---------- 变更目标 ----------
fix_pam_pwquality(){
  local fam; fam="$(distro_family)"
  local file
  if [[ "$fam" == "rhel" ]]; then file="/etc/pam.d/system-auth"; else file="/etc/pam.d/common-password"; fi
  [[ -f "$file" ]] || { log "跳过：未找到 $file"; return 0; }

  # 获取真实文件路径和符号链接状态
  local realfile linktype
  read realfile linktype < <(get_real_and_link_status "$file")

  local tmp; tmp="$(mktemp)"
  local remark="合规需要整改-pam_pwquality策略增强（长度>=12，含大小写/数字/特殊字符，重试3，root生效）-${DATE_TAG}"
  local new="password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 minlen=12 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1 enforce_for_root"

  if [[ "$MODE" == "--preview" ]]; then
    comment_and_replace_line "$realfile" "pam_pwquality[.]so" "$new" "$remark" > "$tmp"
    echo "== PAM 变更预览：$file =="
    preview_diff "$realfile" "$tmp"
    rm -f "$tmp"
    return 0
  fi

  ensure_backup_root
  rsync_backup "$realfile" "$file"
  comment_and_replace_line "$realfile" "pam_pwquality[.]so" "$new" "$remark" > "$tmp"
  run "install -m 0644 -o root -g root '$tmp' '$realfile'"
  rm -f "$tmp"
}

fix_logrotate(){
  local file="/etc/logrotate.conf"
  [[ -f "$file" ]] || { log "跳过：未找到 $file"; return 0; }

  # 获取真实文件路径和符号链接状态
  local realfile linktype
  read realfile linktype < <(get_real_and_link_status "$file")

  local tmp; tmp="$(mktemp)"
  awk -v d="$DATE_TAG" '
    function r1(){print "# 合规需要整改-日志保留至少6个月，当前为按月，轮转7，保留即7个月-" d}
    function r2(){print "# 合规需要整改-rotate修改为7（按实际）-" d}
    {
      if ($0 ~ /^[[:space:]]*weekly[[:space:]]*$/) { print r1(); print "# " $0; print "monthly" }
      else if ($0 ~ /^[[:space:]]*rotate[[:space:]]+[0-9]+[[:space:]]*$/) { print r2(); print "# " $0; print "rotate 7" }
      else { print $0 }
    }
  ' "$realfile" > "$tmp"

  if [[ "$MODE" == "--preview" ]]; then
    echo "== logrotate 变更预览：$file =="
    preview_diff "$realfile" "$tmp"
    rm -f "$tmp"; return 0
  fi

  ensure_backup_root
  rsync_backup "$realfile" "$file"
  run "install -m 0644 -o root -g root '$tmp' '$realfile'"
  rm -f "$tmp"
}

fix_histsize(){
  local file="/etc/profile"
  [[ -f "$file" ]] || { log "跳过：未找到 $file"; return 0; }

  # 获取真实文件路径和符号链接状态
  local realfile linktype
  read realfile linktype < <(get_real_and_link_status "$file")

  local tmp; tmp="$(mktemp)"
  local remark="合规需要整改-HISTSIZE修改为29即历史命令保留29条-${DATE_TAG}"
  local new="HISTSIZE=29"

  awk -v rm="$remark" -v nl="$new" '
    BEGIN { found=0 }
    {
      if ($0 ~ /^[[:space:]]*HISTSIZE[[:space:]]*=/ && $0 !~ /^[[:space:]]*#/) {
        print "# " rm; print "# " $0; print nl; found=1
      } else { print $0 }
    }
    END{ if (found==0) { print ""; print "# " rm; print nl } }
  ' "$realfile" > "$tmp"

  if [[ "$MODE" == "--preview" ]]; then
    echo "== HISTSIZE 变更预览：$file =="
    preview_diff "$realfile" "$tmp"
    rm -f "$tmp"; return 0
  fi

  ensure_backup_root
  rsync_backup "$realfile" "$file"
  run "install -m 0644 -o root -g root '$tmp' '$realfile'"
  rm -f "$tmp"
}

do_apply(){
  log "开始合规整改（日志：$LOG）"
  need rsync || die "请先安装 rsync"
  fix_pam_pwquality
  fix_logrotate
  fix_histsize
  log "整改完成。备份目录：$BACKUP_DIR"
}

do_preview(){ log "仅预览，不落盘"; fix_pam_pwquality; fix_logrotate; fix_histsize; log "预览完成"; }

# ---------- 验证（临时用户改密） ----------
verify_changes(){
  log "开始验证（临时用户改密）"
  local test_user="_pwq_test_${TS}"
  local weak="abc123"
  local strong='Kj8#mN2$pQ9@vX5'
  
  # 清理可能存在的测试用户
  if id "$test_user" >/dev/null 2>&1; then 
    set +e
    userdel -r "$test_user" 2>/dev/null || true
    set -e
  fi
  
  # 创建用户（不设置初始密码）
  run "useradd -m '$test_user'"
  
  # 方法1：直接使用 passwd 命令测试密码复杂度
  log "测试弱密码（应被拒绝）：$weak"
  set +e
  echo -e "${weak}\n${weak}\n" | passwd "$test_user" >/tmp/pwq_weak_${TS}.log 2>&1
  local weak_rc=$?
  set -e
  
  if [[ $weak_rc -eq 0 ]]; then
    log "⚠️ 弱密码设置意外成功，可能未触发pam_pwquality"
  else
    log "弱密码被拒绝（符合预期）✅"
    # 查看详细错误信息
    if [[ -f /tmp/pwq_weak_${TS}.log ]]; then
      log "弱密码错误详情："
      tail -5 /tmp/pwq_weak_${TS}.log | while read line; do log "  $line"; done
    fi
  fi

  # 方法2：测试强密码（应成功）
  log "测试强密码（应成功）：$strong"
  set +e
  echo -e "${strong}\n${strong}\n" | passwd "$test_user" >/tmp/pwq_strong_${TS}.log 2>&1
  local strong_rc=$?
  set -e
  
  if [[ $strong_rc -eq 0 ]]; then
    log "强密码设置成功（符合预期）✅"
  else
    log "❌ 强密码设置失败，请检查pam配置"
    # 查看详细错误信息
    if [[ -f /tmp/pwq_strong_${TS}.log ]]; then
      log "强密码错误详情："
      tail -5 /tmp/pwq_strong_${TS}.log | while read line; do log "  $line"; done
    fi
  fi

  # 清理测试用户
  set +e
  userdel -r "$test_user" 2>/dev/null || {
    log "警告：清理测试用户失败，可能需要手动删除：$test_user"
  }
  set -e
  
  log "验证结束。详细日志：/tmp/pwq_weak_${TS}.log /tmp/pwq_strong_${TS}.log"
  
  # 显示关键日志内容
  echo "=== 验证结果摘要 ==="
  echo "弱密码测试：$([[ $weak_rc -eq 0 ]] && echo "❌ 失败" || echo "✅ 成功")"
  echo "强密码测试：$([[ $strong_rc -eq 0 ]] && echo "✅ 成功" || echo "❌ 失败")"
}

# ---------- 仅展示变更（与备份对比） ----------
latest_backup(){
  find "$COMPLIANCE_ROOT" -type d -name "compliance_*" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
}

show_changes(){
  local b="${2:-$(latest_backup)}"
  [[ -n "$b" && -d "$b" ]] || die "找不到备份目录，请指定：$0 --show-changes <会话目录>"
  log "对比当前文件与备份：$b"
  for f in /etc/pam.d/system-auth /etc/pam.d/common-password /etc/logrotate.conf /etc/profile; do
    local real; real="$(resolve_symlink "$f")"
    local bak="${b}/backups${f}"
    if [[ -f "$real" && -f "$bak" ]]; then
      echo "==== $f ===="
      # 统一上下文 diff，用户可直观看到 +/- 行
      diff -u "$bak" "$real" || true
    fi
  done
}

do_rollback(){
  local b="${2:-}"; [[ -n "$b" ]] || die "用法：$0 --rollback <会话目录>"
  [[ -d "$b" ]] || die "会话目录不存在：$b"
  log "回滚自备份：$b"
  for f in /etc/pam.d/system-auth /etc/pam.d/common-password /etc/logrotate.conf /etc/profile; do
    local real; real="$(resolve_symlink "$f")"
    if [[ -f "$real" && -f "${b}/backups${f}" ]]; then
      run "rsync -a --numeric-ids --inplace '${b}/backups${f}' '$real'"
    fi
  done
  log "回滚完成"
}

case "$MODE" in
  --preview)        do_preview ;;
  --apply)          do_apply ;;
  --verify)         verify_changes ;;
  --show-changes)   show_changes "$@" ;;
  --rollback)       do_rollback "$@" ;;
  --check-deps)     check_deps ;;
  --install-deps)   install_deps ;;
  --rollback-deps)  rollback_deps ;;
  --cleanup)        cleanup_old_files "${2:-12}" ;;
  --storage-usage)  show_storage_usage ;;
  *) echo "用法: $0 --preview | --apply | --verify | --show-changes [会话目录] | --rollback <会话目录> | --check-deps | --install-deps | --rollback-deps | --cleanup [月数] | --storage-usage"; exit 1 ;;
esac
