# MySQL 账号权限同步脚本使用说明-未调通

## 问题

```txt

2025-09-06 18:31:15] [INFO] 脚本启动: mysql_user_sync.sh 
[2025-09-06 18:31:15] [INFO] 日志文件: ./logs/mysql_sync_20250906_183115.log
[2025-09-06 18:31:15] [INFO] 读取配置文件: ./mysql_sync.conf
[2025-09-06 18:31:15] [INFO] 配置文件读取成功
[2025-09-06 18:31:15] [INFO] ========== 预览模式开始 ==========
[2025-09-06 18:31:15] [INFO] 测试源数据库连接...
[2025-09-06 18:31:15] [INFO] 执行命令: echo "SELECT 1;" | [2025-09-06 18:31:15] [INFO] 使用alias命令: msql_root
[2025-09-06 18:31:15] [INFO] 从alias获取到命令: msql_root -> /usr/bin/mysql -h pc-0xi02p6760lwd5qa3.rwlb.rds.aliyuncs.com -u root -p"pass" -P3306 -A
/usr/bin/mysql -h pc-0xi02p6760lwd5qa3.rwlb.rds.aliyuncs.com -u root -p"pass" -P3306 -A > /dev/null

为什么执行到这里就停止了

```

## 功能特性

- ✅ 比较两个MySQL实例的用户差异
- ✅ 比较用户权限差异
- ✅ 创建缺失的用户
- ✅ 同步用户权限
- ✅ 支持预览和执行模式
- ✅ 支持回滚操作
- ✅ 完整的日志记录
- ✅ 支持配置文件和命令行参数

## 安装依赖

确保系统已安装以下工具：
- mysql-client
- bash 4.0+

## 配置文件

创建配置文件 `mysql_sync.conf`：

```ini
[source]
host=localhost
port=3306
user=root
password=your_source_password
database=mysql

[target]
host=remote_host
port=3306
user=root
password=your_target_password
database=mysql
```

## 使用方法

### 1. 预览差异

```bash
# 使用默认配置文件
bash mysql_user_sync.sh --preview

# 指定配置文件
bash mysql_user_sync.sh --config ./mysql_sync.conf --preview

# 指定日志目录
bash mysql_user_sync.sh --config ./mysql_sync.conf --preview --log-dir ./logs
```

### 2. 执行同步

```bash
# 执行同步
bash mysql_user_sync.sh --config ./mysql_sync.conf --apply

# 指定日志目录
bash mysql_user_sync.sh --config ./mysql_sync.conf --apply --log-dir ./logs
```

### 3. 回滚操作

```bash
# 回滚到指定备份
bash mysql_user_sync.sh --rollback ./logs/backups/20240101_120000
```

## 输出说明

### 日志文件

- 位置：`<log-dir>/mysql_sync_YYYYMMDD_HHMMSS.log`
- 内容：详细的操作日志和错误信息

### 差异文件

- 用户差异：`<log-dir>/user_diff_YYYYMMDD_HHMMSS.*`
- 权限差异：`<log-dir>/privilege_diff_YYYYMMDD_HHMMSS/`

### 备份文件

- 位置：`<log-dir>/backups/YYYYMMDD_HHMMSS/`
- 内容：目标数据库用户信息备份

## 注意事项

1. 确保有足够的权限访问源和目标数据库
2. 建议先在测试环境验证
3. 执行前务必备份重要数据
4. 检查网络连接和防火墙设置

## 故障排除

### 连接失败

- 检查数据库地址和端口
- 验证用户名和密码
- 确认网络连通性

### 权限不足

- 确保用户有足够的权限
- 检查数据库用户权限设置

### 脚本错误

- 查看详细日志文件
- 检查配置文件格式
- 验证依赖工具是否安装
