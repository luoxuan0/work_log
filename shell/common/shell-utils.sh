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