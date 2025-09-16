## 迁云切换

## 20250904

官网下线

```shell
# 切换到 nginx 配置目录下
cd /usr/local/nginx/conf/vhost
# 将原配置文件备份
cp mailwebhooken.trackingmore.com.conf mailwebhooken.trackingmore.com.conf.20250904
# 创建一个新的文件
vim mailwebhooken.trackingmore.com.conf.20250904.test
# 覆盖原文件
cp mailwebhooken.trackingmore.com.conf.20250904.test mailwebhooken.trackingmore.com.conf
/usr/local/nginx/sbin/nginx -t
/usr/local/nginx/sbin/nginx -s reload

```

问题解决

```shell
# k8s进入pod
 tm-api-5855bbbbbd-nsx99
kubectl exec -it tm-api-7b89bb6bf4-ztqhf -n fjny-tm-api-pro -- /bin/sh
kubectl exec -it tm-api-5855bbbbbd-nsx99 -n fjny-tm-api-pro -- /bin/sh

/root/riot-standalone-4.3.0-linux-x86_64/bin/riot replicate --threads 8 --batch 100 --source-pass ${oriPass} --target-pass ${tarPass} --skip=always --mode live --progress log 10.1.0.35:6379 10.19.17.21:6379


# 后续需要再处理

# 105 crontab 停掉
#*/1 * * * * /usr/local/php7/bin/php -q /home/wwwroot/www.trackingmore.com/script/statistic_retrack_record.php > /dev/null 2>&1
# 145-44-35 crontab 停掉
#*/2 * * * * sh redis.cpu.sh > /dev/null 2>&1
# 174-77 crontab 停掉
#*/1 * * * *  /usr/local/php7/bin/php -q /home/wwwroot/www.trackingmore.com/script/warning_track.php

# k8s安装命令
apk add screen
# centos
command -v screen &> /dev/null || sudo yum install -y screen
# ubuntu
command -v screen &> /dev/null || sudo apt-get update && sudo apt-get install -y screen


# 带高危redis命令脚本，做调整
script/delete.php
tmzohocrm/app/Command/CountCostTimeEveryDay.php
trunk/script/autoUpdateNumber/queue_update_limit_key.php
crontab -l | grep -v '#' | grep 'delete.php\|CountCostTimeEveryDay.php\|queue_update_limit_key.php\|del_resqueJob.php'
ps -ef | grep 'delete.php\|CountCostTimeEveryDay.php\|queue_update_limit_key.php\|del_resqueJob.php'
# keys *_UpdateNumber 定位redis命令

```

gcloud redis instances describe my-redis-instance --region=us-central1 --format=json
gcloud redis instances describe fjny-tm-redis-pro --region=us-east4 --format=json


咨询ai

帮忙看下，从这里看，gcp的redis使用 了什么持久化方案
{
  "alternativeLocationId": "us-east4-a",
  "authEnabled": true,
  "authorizedNetwork": "projects/track-463207/global/networks/tm-vpc",
  "availableMaintenanceVersions": [
    "20250326_00_00",
    "20250701_00_01",
    "20250806_01_00"
  ],
  "connectMode": "PRIVATE_SERVICE_ACCESS",
  "createTime": "2025-06-18T07:22:25.161584920Z",
  "displayName": "redis pro",
  "host": "10.1.1.1",
  "locationId": "us-east4-c",
  "maintenancePolicy": {
    "createTime": "2025-06-18T07:22:24.680356Z",
    "updateTime": "2025-06-18T07:22:24.680356Z",
    "weeklyMaintenanceWindow": [
      {
        "day": "MONDAY",
        "duration": "3600s",
        "startTime": {
          "hours": 6
        }
      }
    ]
  },
  "maintenanceVersion": "20241107_00_00",
  "memorySizeGb": 38,
  "name": "projects/track-1/locations/us-east4/instances/fjny-tm-redis-pro",
  "nodes": [
    {
      "id": "node-0",
      "zone": "us-east4-c"
    },
    {
      "id": "node-1",
      "zone": "us-east4-a"
    }
  ],
  "persistenceConfig": {
    "persistenceMode": "DISABLED"
  },
  "persistenceIamIdentity": "serviceAccount:service-385382699791@cloud-redis.iam.gserviceaccount.com",
  "port": 6379,
  "readEndpoint": "10.1.1.20",
  "readEndpointPort": 6379,
  "readReplicasMode": "READ_REPLICAS_ENABLED",
  "redisVersion": "REDIS_7_0",
  "replicaCount": 1,
  "reservedIpRange": "10.1.1.16/28",
  "satisfiesPzi": true,
  "state": "UPDATING",
  "tier": "STANDARD_HA",
  "transitEncryptionMode": "DISABLED"
}

好的，我来帮您分析这段配置。

根据您提供的 JSON 配置，**这个 GCP Redis 实例没有启用任何数据持久化方案**。

### 核心结论

**持久化状态：未启用（纯内存）**

这意味着如果实例发生重启、故障转移或维护，**存储在其中的所有数据都将会丢失**。

### 详细分析

关键证据在于配置中的 `persistenceConfig` 部分：

```json
  "persistenceConfig": {
    "persistenceMode": "DISABLED"  // <-- 这是最关键的一行
  },
```

*   **`"persistenceMode": "DISABLED"`**：这明确表示 **RDB 快照（基于磁盘的持久化）功能已被禁用**。GCP 不会自动为您的数据创建任何周期性的快照。

此外，配置中**完全没有出现 `aofConfig` 字段**。在 GCP Redis 的 API 中，如果 AOF（仅追加文件）持久化没有被启用，这个字段通常会被省略。如果它被启用，你会看到类似 `"aofConfig": { "aofMode": "AOF_MODE_ENABLED" }` 的配置。

### 其他相关信息

尽管没有启用持久化，但从配置中可以看出这是一个配置较高的实例：

*   **`"tier": "STANDARD_HA"`**：这是一个**标准层级的高可用性**实例。它支持持久化功能，但当前未被启用。
*   **`"replicaCount": 1`**：它有一个副本节点（`node-1`），配置在另一个可用区（`us-east4-a`）。这提供了**高可用性**，即主节点发生故障时，副本节点会自动接管，**但这不是持久化**。
    *   **重要区别**：高可用性可以防止**节点故障**，数据会从主节点复制到副本节点。但如果发生**用户误删除**、**应用程序错误写入**或者需要**跨地域恢复**，副本节点上的数据也会同样被破坏或丢失。只有持久化（备份/快照）才能从这种情况中恢复。

### 总结与建议

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **RDB 持久化** | **❌ 禁用** | 无周期性的数据快照 |
| **AOF 持久化** | **❌ 禁用** | 未启用追加日志 |
| **高可用性 (HA)** | **✅ 启用** | 拥有一个备用副本，可自动故障转移 |

**建议：**
如果您的应用数据是重要的、不允许丢失的，**强烈建议您立即启用持久化功能**。

您可以在 GCP 控制台中编辑此 Redis 实例，在“配置”部分：
1.  将 **持久性** 从“仅内存”更改为“基于磁盘的持久性”，并选择一个快照频率（例如每1小时）。
2.  根据对数据安全性和性能的综合考量，决定是否同时启用 **仅追加文件 (AOF)**。

启用持久化会产生额外的存储成本，但这是保证数据安全所必需的。

## 20250905

### 切换后php连接数据库异常

```shell

# PHP 7.0.0 异常
# PHP 7.0.33 正常

# phpVersionChangeTemp.sh

# 独立更新没有7.0.33
# 从145-44-35获取 ， 172.16.21.212 类似操作
rsync -avz /usr/local/php7.0.33 root@172.16.21.190:/usr/local/

/usr/local/php7.0.33/bin/php -v
/usr/local/php7.0.33/bin/php: error while loading shared libraries: libltdl.so.7: cannot open shared object file: No such file or directory

# 这个错误是因为系统缺少 PHP 运行所需的 libltdl.so.7 共享库文件
# 安装 libltdl7
# 对于 Ubuntu/Debian 系统
sudo apt update
sudo apt install libltdl7

# 对于 CentOS/RHEL 系统
sudo yum install libtool-ltdl

# 对于 Fedora
sudo dnf install libtool-ltdl

# 依旧报错
/usr/local/php7.0.33/bin/php -v
PHP Warning:  PHP Startup: Unable to load dynamic library '/usr/local/php7.0.33/lib/php/extensions/no-debug-non-zts-20151012/rdkafka.so' - librdkafka.so.1: cannot open shared object file: No such file or directory in Unknown on line 0
PHP 7.0.33 (cli) (built: Oct 16 2020 14:10:41) ( NTS )
Copyright (c) 1997-2017 The PHP Group
Zend Engine v3.0.0, Copyright (c) 1998-2017 Zend Technologies
    with Zend OPcache v7.0.33, Copyright (c) 1999-2017, by Zend Technologies


/usr/local/php7.0.33/lib/php.ini
;切换gcp后php连接数据库异常，从其他服务器复制过来 7.0.33 但是 缺乏扩展，查询队列不用kafka，将其注释-20250905
;extension=rdkafka.so



```

## 20250916

- 启动激活中关于服务器CPU和内存余量的判断去掉
  - gcp上k8s的pod中无法获取pod本身 CPU 内存
