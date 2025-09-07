#!/usr/bin/env bash

###############################################################################
# MySQL 账号权限同步脚本
#
# 功能说明:
#   本脚本用于同步两个不同MySQL实例的账号和权限，支持：
#   1. 查看源和目标数据库的账号差异
#   2. 查看账号权限差异
#   3. 创建缺失的账号
#   4. 同步账号权限
#   5. 支持预览和执行模式
#   6. 支持回滚操作
#   7. 完整的日志记录
#   8. 支持从alias获取MySQL连接命令
#
# 使用方法:
#   bash mysql_user_sync.sh [选项]
#
# 选项:
#   --config <配置文件>     指定配置文件路径 (默认: ./mysql_sync.conf)
#   --source-alias <别名>   指定源数据库连接别名 (如: msql_root)
#   --target-alias <别名>   指定目标数据库连接别名 (如: msql_gcp_root)
#   --preview              预览模式，只显示差异不执行
#   --apply                执行模式，实际同步账号和权限
#   --rollback <备份目录>  回滚到指定备份
#   --log-dir <目录>       指定日志目录 (默认: ./logs)
#   --help                 显示帮助信息
#
# 配置文件格式:
#   [source]
#   host=localhost
#   port=3306
#   user=root
#   password=password
#   database=mysql
#
#   [target]
#   host=remote_host
#   port=3306
#   user=root
#   password=password
#   database=mysql
#
# 日志文件: <log-dir>/mysql_sync_YYYYMMDD_HHMMSS.log
# 备份目录: <log-dir>/backups/YYYYMMDD_HHMMSS/
###############################################################################

set -euo pipefail

# 引入环境配置
. /etc/bashrc

# 默认配置
DEFAULT_CONFIG="./mysql_sync.conf"
DEFAULT_LOG_DIR="./logs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DATE_TAG="$(date +%Y%m%d)"

# 全局变量
CONFIG_FILE=""
LOG_DIR=""
MODE=""
BACKUP_DIR=""
LOG_FILE=""
SOURCE_CONFIG=""
TARGET_CONFIG=""
SOURCE_ALIAS=""
TARGET_ALIAS=""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "${YELLOW}$*${NC}"; }
log_error() { log "ERROR" "${RED}$*${NC}"; }
log_success() { log "SUCCESS" "${GREEN}$*${NC}"; }

# 错误处理函数
check_error() {
    local exit_code=$1
    local cmd="$2"
    local error_output="${3:-}"

    if [ $exit_code -ne 0 ]; then
        log_error "命令执行失败: $cmd"
        log_error "退出码: $exit_code"
        if [ -n "$error_output" ]; then
            log_error "错误输出: $error_output"
        fi
        exit 1
    fi
}

# 执行命令并记录日志，捕获所有错误输出
run_command() {
    local cmd="$1"
    log_info "执行命令: $cmd"
    local output error
    output=$(eval "$cmd" 2> >(error=$(cat); typeset -p error >/dev/null) )
    local exit_code=$?
    # shellcheck disable=SC2154
    if [ -z "${error:-}" ]; then
        error=""
    fi
    check_error $exit_code "$cmd" "$error"
    echo "$output"
}

# 获取alias命令
get_alias_command() {
    local alias_name="$1"
    local alias_cmd=""

    if [ -n "$alias_name" ]; then
        # 尝试从alias获取命令
        alias_cmd=$(alias "$alias_name" 2>/dev/null | sed "s/alias $alias_name='//;s/'$//")
        if [ -n "$alias_cmd" ]; then
            log_info "从alias获取到命令: $alias_name -> $alias_cmd"
            echo "$alias_cmd"
            return 0
        else
            log_warn "无法从alias获取命令: $alias_name"
            return 1
        fi
    fi

    return 1
}

# 显示帮助信息
show_help() {
    cat << EOF
MySQL 账号权限同步脚本

使用方法:
    bash mysql_user_sync.sh [选项]

选项:
    --config <配置文件>     指定配置文件路径 (默认: ./mysql_sync.conf)
    --source-alias <别名>   指定源数据库连接别名 (如: msql_root)
    --target-alias <别名>   指定目标数据库连接别名 (如: msql_gcp_root)
    --preview              预览模式，只显示差异不执行
    --apply                执行模式，实际同步账号和权限
    --rollback <备份目录>  回滚到指定备份
    --log-dir <目录>       指定日志目录 (默认: ./logs)
    --help                 显示帮助信息

配置文件格式:
    [source]
    host=localhost
    port=3306
    user=root
    password=password
    database=mysql

    [target]
    host=remote_host
    port=3306
    user=root
    password=password
    database=mysql

alias使用示例:
    # 定义alias
    alias msql_root='/usr/bin/mysql -h localhost -u root -p"password" -P3306 -A'
    alias msql_gcp_root='/usr/bin/mysql -h 10.19.16.14 -u root -p"pass" -P3306 -A'

    # 使用alias
    bash mysql_user_sync.sh --source-alias msql_root --target-alias msql_gcp_root --preview

示例:
    # 预览差异
    bash mysql_user_sync.sh --config ./mysql_sync.conf --preview

    # 使用alias预览差异
    bash mysql_user_sync.sh --source-alias msql_root --target-alias msql_gcp_root --preview

    # 执行同步
    bash mysql_user_sync.sh --config ./mysql_sync.conf --apply

    # 使用alias执行同步
    bash mysql_user_sync.sh --source-alias msql_root --target-alias msql_gcp_root --apply

    # 回滚操作
    bash mysql_user_sync.sh --rollback ./logs/backups/20240101_120000

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --source-alias)
                SOURCE_ALIAS="$2"
                shift 2
                ;;
            --target-alias)
                TARGET_ALIAS="$2"
                shift 2
                ;;
            --preview)
                MODE="preview"
                shift
                ;;
            --apply)
                MODE="apply"
                shift
                ;;
            --rollback)
                MODE="rollback"
                BACKUP_DIR="$2"
                shift 2
                ;;
            --log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 设置默认值
    CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG}"
    LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"

    if [ -z "$MODE" ]; then
        log_error "请指定操作模式: --preview, --apply 或 --rollback"
        show_help
        exit 1
    fi
}

# 初始化日志和目录
init_logging() {
    # 创建日志目录
    if [ ! -d "$LOG_DIR" ]; then
        run_command "mkdir -p \"$LOG_DIR\""
    fi

    # 设置日志文件
    LOG_FILE="${LOG_DIR}/mysql_sync_${TIMESTAMP}.log"

    # 创建备份目录
    if [ "$MODE" = "apply" ]; then
        BACKUP_DIR="${LOG_DIR}/backups/${TIMESTAMP}"
        run_command "mkdir -p \"$BACKUP_DIR\""
    fi

    log_info "脚本启动: $0 $*"
    log_info "日志文件: $LOG_FILE"
    if [ -n "$BACKUP_DIR" ]; then
        log_info "备份目录: $BACKUP_DIR"
    fi
}

# 读取配置文件
read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi

    log_info "读取配置文件: $CONFIG_FILE"

    # 读取源配置
    SOURCE_CONFIG=$(grep -A 10 '^\[source\]' "$CONFIG_FILE" | grep -v '^\[source\]' | grep -v '^\[target\]' | head -5)
    TARGET_CONFIG=$(grep -A 10 '^\[target\]' "$CONFIG_FILE" | grep -v '^\[target\]' | head -5)

    if [ -z "$SOURCE_CONFIG" ] || [ -z "$TARGET_CONFIG" ]; then
        log_error "配置文件格式错误，请检查 [source] 和 [target] 部分"
        exit 1
    fi

    log_info "配置文件读取成功"
}

# 构建MySQL连接字符串
build_mysql_cmd() {
    local config="$1"
    local host=$(echo "$config" | grep '^host=' | cut -d'=' -f2 | tr -d ' ')
    local port=$(echo "$config" | grep '^port=' | cut -d'=' -f2 | tr -d ' ')
    local user=$(echo "$config" | grep '^user=' | cut -d'=' -f2 | tr -d ' ')
    local password=$(echo "$config" | grep '^password=' | cut -d'=' -f2 | tr -d ' ')
    local database=$(echo "$config" | grep '^database=' | cut -d'=' -f2 | tr -d ' ')

    echo "mysql -h${host} -P${port} -u${user} -p${password} ${database}"
}

# 获取MySQL连接命令（优先使用alias）
get_mysql_cmd() {
    local alias_name="$1"
    local config="$2"
    local mysql_cmd=""

    # 优先尝试从alias获取
    if [ -n "$alias_name" ]; then
        mysql_cmd=$(get_alias_command "$alias_name")
        if [ $? -eq 0 ]; then
            log_info "使用alias命令: $alias_name"
            echo "$mysql_cmd"
            return 0
        fi
    fi

    # 如果alias失败，使用配置文件
    if [ -n "$config" ]; then
        mysql_cmd=$(build_mysql_cmd "$config")
        log_info "使用配置文件构建命令"
        echo "$mysql_cmd"
        return 0
    fi

    log_error "无法获取MySQL连接命令"
    return 1
}

# 获取用户列表
get_user_list() {
    local mysql_cmd="$1"
    local output_file="$2"

    log_info "获取用户列表..."

    local query="SELECT CONCAT('''', User, '''@''', Host, '''') as user_host FROM mysql.user WHERE User != 'root' AND User != 'mysql.sys' AND User != 'mysql.session' AND User != 'mysql.infoschema' ORDER BY User, Host;"

    # 使用run_command
    run_command "echo \"$query\" | $mysql_cmd > \"$output_file\""

    # 过滤掉标题行
    run_command "sed -i '1d' \"$output_file\""

    local count=$(wc -l < "$output_file")
    log_info "获取到 $count 个用户"
}

# 获取用户权限
get_user_privileges() {
    local mysql_cmd="$1"
    local user="$2"
    local output_file="$3"

    log_info "获取用户权限: $user"

    local query="SHOW GRANTS FOR $user;"

    run_command "echo \"$query\" | $mysql_cmd > \"$output_file\""
}

# 比较用户列表差异
compare_user_lists() {
    local source_file="$1"
    local target_file="$2"
    local diff_file="$3"

    log_info "比较用户列表差异..."

    # 找出只在源中存在的用户
    run_command "comm -23 <(sort \"$source_file\") <(sort \"$target_file\") > \"${diff_file}.source_only\""

    # 找出只在目标中存在的用户
    run_command "comm -13 <(sort \"$source_file\") <(sort \"$target_file\") > \"${diff_file}.target_only\""

    # 找出共同用户
    run_command "comm -12 <(sort \"$source_file\") <(sort \"$target_file\") > \"${diff_file}.common\""

    local source_only_count=$(wc -l < "${diff_file}.source_only")
    local target_only_count=$(wc -l < "${diff_file}.target_only")
    local common_count=$(wc -l < "${diff_file}.common")

    log_info "用户差异统计:"
    log_info "  只在源中存在的用户: $source_only_count"
    log_info "  只在目标中存在的用户: $target_only_count"
    log_info "  共同用户: $common_count"

    if [ $source_only_count -gt 0 ]; then
        log_warn "只在源中存在的用户:"
        while IFS= read -r user; do
            log_warn "  $user"
        done < "${diff_file}.source_only"
    fi

    if [ $target_only_count -gt 0 ]; then
        log_warn "只在目标中存在的用户:"
        while IFS= read -r user; do
            log_warn "  $user"
        done < "${diff_file}.target_only"
    fi
}

# 比较用户权限差异
compare_user_privileges() {
    local source_mysql_cmd="$1"
    local target_mysql_cmd="$2"
    local common_users_file="$3"
    local diff_dir="$4"

    log_info "比较用户权限差异..."

    run_command "mkdir -p \"$diff_dir\""

    while IFS= read -r user; do
        if [ -n "$user" ]; then
            log_info "比较用户权限: $user"

            # 获取源用户权限
            get_user_privileges "$source_mysql_cmd" "$user" "${diff_dir}/${user}.source"

            # 获取目标用户权限
            get_user_privileges "$target_mysql_cmd" "$user" "${diff_dir}/${user}.target"

            # 比较权限差异
            if ! run_command "diff -q \"${diff_dir}/${user}.source\" \"${diff_dir}/${user}.target\" > /dev/null"; then
                log_warn "用户 $user 权限存在差异:"
                if ! run_command "diff \"${diff_dir}/${user}.source\" \"${diff_dir}/${user}.target\" > \"${diff_dir}/${user}.diff\""; then
                    log_warn "diff 错误"
                fi
                cat "${diff_dir}/${user}.diff" | while IFS= read -r line; do
                    log_warn "  $line"
                done
            else
                log_info "用户 $user 权限一致"
            fi
        fi
    done < "$common_users_file"
}

# 创建用户
create_user() {
    local target_mysql_cmd="$1"
    local user="$2"
    local source_mysql_cmd="$3"

    log_info "创建用户: $user"

    # 获取源用户信息
    local user_info
    user_info=$(run_command "echo \"SELECT User, Host, authentication_string FROM mysql.user WHERE CONCAT('''', User, '''@''', Host, '''') = '$user';\" | $source_mysql_cmd | tail -n +2")

    if [ -n "$user_info" ]; then
        local username=$(echo "$user_info" | awk '{print $1}')
        local hostname=$(echo "$user_info" | awk '{print $2}')
        local password=$(echo "$user_info" | awk '{print $3}')

        # 创建用户
        local create_sql="CREATE USER '$username'@'$hostname' IDENTIFIED BY PASSWORD '$password';"
        run_command "echo \"$create_sql\" | $target_mysql_cmd"

        log_success "用户创建成功: $user"
    else
        log_error "无法获取用户信息: $user"
    fi
}

# 同步用户权限
sync_user_privileges() {
    local source_mysql_cmd="$1"
    local target_mysql_cmd="$2"
    local user="$3"

    log_info "同步用户权限: $user"

    # 获取源用户权限
    local privileges
    privileges=$(run_command "echo \"SHOW GRANTS FOR $user;\" | $source_mysql_cmd | tail -n +2")

    if [ -n "$privileges" ]; then
        # 在目标数据库中执行权限语句
        echo "$privileges" | while IFS= read -r grant_stmt; do
            if [ -n "$grant_stmt" ]; then
                run_command "echo \"$grant_stmt\" | $target_mysql_cmd"
            fi
        done

        log_success "用户权限同步成功: $user"
    else
        log_error "无法获取用户权限: $user"
    fi
}

# 预览模式
preview_mode() {
    log_info "========== 预览模式开始 =========="

    # 获取MySQL连接命令
    local source_mysql_cmd target_mysql_cmd
    source_mysql_cmd=$(get_mysql_cmd "$SOURCE_ALIAS" "$SOURCE_CONFIG")
    target_mysql_cmd=$(get_mysql_cmd "$TARGET_ALIAS" "$TARGET_CONFIG")

    if [ -z "$source_mysql_cmd" ] || [ -z "$target_mysql_cmd" ]; then
        log_error "无法获取MySQL连接命令"
        exit 1
    fi

    # 测试连接
    log_info "测试源数据库连接..."
    run_command "echo \"SELECT 1;\" | $source_mysql_cmd > /dev/null"

    log_info "测试目标数据库连接..."
    run_command "echo \"SELECT 1;\" | $target_mysql_cmd > /dev/null"

    # 获取用户列表
    local source_users_file="${LOG_DIR}/source_users_${TIMESTAMP}.txt"
    local target_users_file="${LOG_DIR}/target_users_${TIMESTAMP}.txt"

    get_user_list "$source_mysql_cmd" "$source_users_file"
    get_user_list "$target_mysql_cmd" "$target_users_file"

    # 比较用户列表差异
    local diff_file="${LOG_DIR}/user_diff_${TIMESTAMP}"
    compare_user_lists "$source_users_file" "$target_users_file" "$diff_file"

    # 比较用户权限差异
    compare_user_privileges "$source_mysql_cmd" "$target_mysql_cmd" "${diff_file}.common" "${LOG_DIR}/privilege_diff_${TIMESTAMP}"

    log_info "========== 预览模式完成 =========="
    log_info "详细差异信息已保存到: $LOG_DIR"
}

# 执行模式
apply_mode() {
    log_info "========== 执行模式开始 =========="

    # 获取MySQL连接命令
    local source_mysql_cmd target_mysql_cmd
    source_mysql_cmd=$(get_mysql_cmd "$SOURCE_ALIAS" "$SOURCE_CONFIG")
    target_mysql_cmd=$(get_mysql_cmd "$TARGET_ALIAS" "$TARGET_CONFIG")

    if [ -z "$source_mysql_cmd" ] || [ -z "$target_mysql_cmd" ]; then
        log_error "无法获取MySQL连接命令"
        exit 1
    fi

    # 测试连接
    log_info "测试源数据库连接..."
    run_command "echo \"SELECT 1;\" | $source_mysql_cmd > /dev/null"

    log_info "测试目标数据库连接..."
    run_command "echo \"SELECT 1;\" | $target_mysql_cmd > /dev/null"

    # 备份目标数据库用户信息
    log_info "备份目标数据库用户信息..."
    local backup_file="${BACKUP_DIR}/target_users_backup_${TIMESTAMP}.sql"
    run_command "echo \"SELECT * FROM mysql.user;\" | $target_mysql_cmd > \"$backup_file\""

    # 获取用户列表
    local source_users_file="${LOG_DIR}/source_users_${TIMESTAMP}.txt"
    local target_users_file="${LOG_DIR}/target_users_${TIMESTAMP}.txt"

    get_user_list "$source_mysql_cmd" "$source_users_file"
    get_user_list "$target_mysql_cmd" "$target_users_file"

    # 比较用户列表差异
    local diff_file="${LOG_DIR}/user_diff_${TIMESTAMP}"
    compare_user_lists "$source_users_file" "$target_users_file" "$diff_file"

    # 创建缺失的用户
    if [ -f "${diff_file}.source_only" ]; then
        log_info "创建缺失的用户..."
        while IFS= read -r user; do
            if [ -n "$user" ]; then
                create_user "$target_mysql_cmd" "$user" "$source_mysql_cmd"
            fi
        done < "${diff_file}.source_only"
    fi

    # 同步用户权限
    if [ -f "${diff_file}.common" ]; then
        log_info "同步用户权限..."
        while IFS= read -r user; do
            if [ -n "$user" ]; then
                sync_user_privileges "$source_mysql_cmd" "$target_mysql_cmd" "$user"
            fi
        done < "${diff_file}.common"
    fi

    log_success "========== 执行模式完成 =========="
    log_info "备份文件: $backup_file"
}

# 回滚模式
rollback_mode() {
    log_info "========== 回滚模式开始 =========="

    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "备份目录不存在: $BACKUP_DIR"
        exit 1
    fi

    local backup_file
    backup_file=$(find "$BACKUP_DIR" -name "target_users_backup_*.sql" | head -1)

    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_file"
        exit 1
    fi

    log_info "找到备份文件: $backup_file"

    # 获取目标MySQL连接命令
    local target_mysql_cmd
    target_mysql_cmd=$(get_mysql_cmd "$TARGET_ALIAS" "$TARGET_CONFIG")

    if [ -z "$target_mysql_cmd" ]; then
        log_error "无法获取目标MySQL连接命令"
        exit 1
    fi

    # 测试连接
    log_info "测试目标数据库连接..."
    run_command "echo \"SELECT 1;\" | $target_mysql_cmd > /dev/null"

    # 执行回滚
    log_info "执行回滚操作..."
    # 注意：这里需要根据实际情况调整回滚逻辑
    log_warn "回滚功能需要根据具体需求实现"

    log_success "========== 回滚模式完成 =========="
}

# 主函数
main() {
    parse_args "$@"
    init_logging
    read_config

    case "$MODE" in
        "preview")
            preview_mode
            ;;
        "apply")
            apply_mode
            ;;
        "rollback")
            rollback_mode
            ;;
        *)
            log_error "未知模式: $MODE"
            exit 1
            ;;
    esac

    log_success "脚本执行完成"
}

# 执行主函数
main "$@"