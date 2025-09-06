```bash
#!/bin/bash
#sudo su -
. /etc/bashrc

# 设置默认值为www_TM
# 国外使用说明：
# 先执行 sh server/nginx/conf/vhost/nginx.sh www_TM ，确认配置文件是否正确
# 再执行 sh server/nginx/conf/vhost/nginx.sh www_TM reload ，进行配置文件重载
# 然后将输出结果进行记录

# 封装函数，如果有报错则输出上一个执行命令和报错，并中断脚本执行，除了$?，把报错内容也输出
function check_error() {
	local exit_code=$?
	local error_output="$2"
	if [ $exit_code -ne 0 ]; then
		echo "Error: $exit_code"
		echo "Command: $1"
		if [ -n "$error_output" ]; then
			echo "Error output: $error_output"
		fi
		exit 1
	fi
}

# 执行命令并捕获错误输出的函数
function run_command() {
	local cmd="$1"
	local output
	echo "$(date '+%Y-%m-%d %H:%M:%S') - Executing: $cmd"
	output=$(eval "$cmd" 2>&1)
	local exit_code=$?
	if [ $exit_code -ne 0 ]; then
		check_error "$cmd" "$output"
	fi
	echo "$output"
}

# 设置默认值为www_TM
host=${1:-www_TM}
# 设置默认值为1
reload=${2:-noReload}

if [[ $host == 'api_51' ]]; then

	# 20240920 下午
	# 除了163
	conf=api.51tracking.com.conf
	nginx_host_dir=/usr/local/nginx/conf/vhost/
	vhost_dir=/home/wwwroot/www.trackingmore.com/server/nginx/conf/vhost/
	vhost_conf=${vhost_dir}${conf}
	nginx_vhost_conf=${nginx_host_dir}${conf}

	d=`date +%Y%m%d`
	# 查看提交的配置文件
	ls -l ${vhost_dir}
	# 备份原配置文件
	/bin/cp ${nginx_vhost_conf} ${nginx_vhost_conf}.${d}
	# 拷贝新配置文件替换原配置文件
	/bin/cp ${vhost_conf} ${nginx_vhost_conf}
	# 对比
	/bin/diff ${nginx_vhost_conf} ${nginx_vhost_conf}.${d}
	# 语法检查
	/usr/local/nginx/sbin/nginx -t
	# 如果没有报错，则重载配置
	if [ $? -eq 0 ]; then
		# 重载配置
		/usr/local/nginx/sbin/nginx -s reload
	fi
	# sleep 1s后，确认nginx进程reload
	sleep 1s
	ps -ef | grep nginx
	# 测试确认，验收完成
elif [[ $host == 'www_TM' ]]; then
	if [ $reload = 'reload' ]; then
		# 确认nginx进程
		run_command "ps -ef | grep nginx"
		# 重载配置
		run_command "/usr/local/nginx/sbin/nginx -s reload"
		# sleep 2s后，确认nginx进程reload
		sleep 2s
		# 测试确认，验收完成
		run_command "ps -ef | grep nginx"
		exit 0
	fi

	conf=www.trackingmore.com.conf
	nginx_host_dir=/usr/local/nginx/conf/vhost/
	vhost_dir=/home/wwwroot/www.trackingmore.com/server/nginx/conf/vhost/
	nginx_vhost_conf=${nginx_host_dir}${conf}
	# 外网IP获取
	ip=$(run_command "curl icanhazip.com -s")
	# 获取 $ip 最后一个.后的字符
	ip_suffix=${ip##*.}
	nginx_vhost_conf_new=${vhost_dir}${ip_suffix}.${conf}
	today=`date '+%Y%m%d'`
	# 当天操作超过1次，且不在同一小时中，使用如下
	# today=`date '+%Y%m%d.%H'`
	# 备份
	run_command "/bin/cp -f ${nginx_vhost_conf} ${nginx_vhost_conf}.${today}"
	# 备份确认
	ls -lh ${nginx_vhost_conf}.${today}
	check_error "ls -lh ${nginx_vhost_conf}.${today}"

	# 配置修改前确认（规则是否冲突等）（在本地已经要完成）
	#grep -C1 '172' ${nginx_vhost_conf}


	# 对比配置文件
	run_command "/usr/bin/diff ${nginx_vhost_conf_new} ${nginx_vhost_conf}"
	# 配置修改
	run_command "/bin/cp -f ${nginx_vhost_conf_new} ${nginx_vhost_conf}"

	# 确认配置修改差异
	run_command "/usr/bin/diff ${nginx_vhost_conf_new} ${nginx_vhost_conf}"
	# 语法测试
	run_command "/usr/local/nginx/sbin/nginx -t"
fi
```

phpVersionChangeTemp.sh

```shell

#!/bin/bash

###############################################################################
# 脚本名称: phpVersionChangeTemp.sh
# 功能说明:
#   本脚本用于将 /usr/local/php7/bin/php 切换为 php7.0.33 版本，解决迁云gcp数据库连接异常问题。
#   操作流程如下：
#     1. 备份原有 php 可执行文件，防止误操作导致无法恢复。
#     2. 删除当前有迁云gcp数据库连接异常的 php 可执行文件。
#     3. 建立软连接，将 php7.0.33 作为新的 php7 版本。
#
# 使用说明:
#   1. 请确保有 root 权限执行本脚本。
#   2. 所有操作均通过 run_command 封装，遇到错误会自动中断并输出详细日志，便于排查。
#   3. 备份文件名自动带上当前日期，避免覆盖历史备份。
#
# 流程展示:
#   ┌──────────────┐
#   │ 备份原php文件 │
#   └─────┬────────┘
#         │
#   ┌─────▼────────┐
#   │ 删除异常php   │
#   └─────┬────────┘
#         │
#   ┌─────▼──────────────┐
#   │ 建立新php软连接     │
#   └────────────────────┘
###############################################################################

log_date=$(date +%Y%m%d)
# 备注：/data/audit/ 为操作审计目录，如不存在则创建
audit_dir="/data/audit"
if [ ! -d "$audit_dir" ]; then
    mkdir -p "$audit_dir"
fi
log_file="${audit_dir}/phpVersionChangeTemp.${log_date}.log"

{
    bash_path=$(ps -p $$ -o comm=)
    cmd="$0"
    echo "执行脚本的bash: $bash_path"
    echo "脚本执行完整命令: $bash_path $cmd $*"

    # 引入通用工具函数
    # source "$(dirname "$0")/../../common/shell-utils.sh"
    source "/home/wwwroot/www.trackingmore.com/common/shell-utils.sh"

    echo "========== PHP 版本切换流程开始 =========="

    # 1. 备份原有 php 可执行文件，防止误操作导致无法恢复
    echo "[1/3] 备份原有 php 可执行文件..."
    run_command "rsync -avz /usr/local/php7/bin/php /usr/local/php7/bin/php.\$(date +%Y%m%d)"

    # 2. 删除当前有迁云gcp数据库连接异常的 php 可执行文件
    echo "[2/3] 删除当前有迁云gcp数据库连接异常的 php 可执行文件..."
    run_command "rm -f /usr/local/php7/bin/php"

    # 3. 建立软连接，将 php7.0.33 作为新的 php7 版本
    echo "[3/3] 建立软连接，将 php7.0.33 作为新的 php7 版本..."
    run_command "ln -s /usr/local/php7.0.33/bin/php /usr/local/php7/bin/php"

    echo "========== PHP 版本切换流程完成 =========="
} >> "$log_file" 2>&1


```