#!/bin/bash

# MySQL 账号权限同步脚本使用示例

# 引入环境配置
. /etc/bashrc

# 定义MySQL连接别名
alias msql_root='/usr/bin/mysql -h localhost -u root -p"password" -P3306 -A'
alias msql_gcp_root='/usr/bin/mysql -h 10.19.16.14 -u root -p"pass" -P3306 -A'

# 示例1: 使用alias预览差异
echo "=== 示例1: 使用alias预览差异 ==="
bash mysql_user_sync.sh --source-alias msql_root --target-alias msql_gcp_root --preview

# 示例2: 使用alias执行同步
echo "=== 示例2: 使用alias执行同步 ==="
bash mysql_user_sync.sh --source-alias msql_root --target-alias msql_gcp_root --apply

# 示例3: 使用配置文件预览差异
echo "=== 示例3: 使用配置文件预览差异 ==="
bash mysql_user_sync.sh --config ./mysql_sync.conf --preview

# 示例4: 指定日志目录
echo "=== 示例4: 指定日志目录 ==="
bash mysql_user_sync.sh --source-alias msql_root --target-alias msql_gcp_root --preview --log-dir ./logs

# 示例5: 回滚操作
echo "=== 示例5: 回滚操作 ==="
bash mysql_user_sync.sh --rollback ./logs/backups/20240101_120000
