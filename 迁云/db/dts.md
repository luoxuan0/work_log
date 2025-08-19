## 20250818

### dts同步gcp的tracking库到gcp

```sql

-- 全量

-- 源库账号授权
CREATE USER 'dts'@'%' IDENTIFIED BY 'pass';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE ON `tracking`.* TO `dts`@`%`;
-- 源库dts需要
GRANT REPLICATION CLIENT,REPLICATION SLAVE on *.* TO 'dts'@'%'

-- 目标库账号授权
CREATE USER 'dts'@'%' IDENTIFIED BY 'pass';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE ON `tracking`.* TO `dts`@`%`;


-- 几个表单独同步

-- 目标库执行（目标库不能存在同名表）
DROP TABLE tr_tracking_control_center;
DROP TABLE tr_tracking_control_center_child;
DROP TABLE tr_tracking_lines_center;
DROP TABLE tr_tracking_proxy_center;
DROP TABLE tr_tracking_secret_key;

-- 开启单独dts，每天或有需要在7天内手动开启一次

-- 清除dts账号

```

### dts同步gcp的nacos库到gcp

```sql

-- 其他授权已经有，在源和目标库授权
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE ON `nacos`.* TO `dts`@`%`;



```