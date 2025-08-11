## 20250731

gcp提供
```txt
https://stackoverflow.com/questions/52519434/elasticsearch-restore-single-index-from-snapshot


{
  "indices": "index_1,index_2",
  "ignore_unavailable": true,
  "include_global_state": false,
  "metadata": {
    "taken_by": "user123",
    "taken_because": "backup before upgrading"
  }
}

https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-snapshot-create


https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-snapshot-restore


{
  "indices": "index_1,index_2",
  "ignore_unavailable": true,
  "include_global_state": false,
  "rename_pattern": "index_(.+)",
  "rename_replacement": "restored_index_$1",
  "include_aliases": false
}


看起来有单独备份恢复一个index的api。另外官方论坛里也有给这样的步骤，
https://discuss.elastic.co/t/proper-way-to-dump-indices-from-elasticsearch-and-import-to-another-elasticsearch-instance/310938

```

咨询gpt
```md
下面是基于你提供链接及官方文档整理的 **完整数据迁移方案**，涵盖 **Elasticsearch Snapshot+Restore** 方式适用于私网隔离环境（参照 Elastic 官方及社区建议）：

---

## 🚀 方法一：Snapshot + Restore（适合私有网络隔离或跨实例迁移）

### 步骤与必要条件详解

#### ✅ 步骤 1：在源集群 A 创建并 unregister snapshot 存储库

* **条件检查**

  * Elastic 版本兼容：源集群和目标集群版本需兼容 snapshot 恢复（查阅官方版本兼容矩阵）。
  * 有可访问的共享存储路径（fs、s3 等）。
  * 源集群服务可写入该路径，且权限验证通过。

* **命令**

  ```shell
  PUT /_snapshot/my_backup
  {
    "type": "fs",
    "settings": { "location": "/path/to/repo" }
  }
  ```

  ```shell
  PUT /_snapshot/my_backup/snapshot_20250729?wait_for_completion=true
  ```

* **完成后**：用 API `DELETE /_snapshot/my_backup` 注销该 repository。确保重新挂载之前不被访问 ([Discuss the Elastic Stack][1], [Elastic][2], [GitHub][3])。

---

#### ✅ 步骤 2：复制 snapshot 存储目录文件

* **条件检查**

  * 本地或网络路径 `/path/to/repo` 下 snapshot 文件完整。
  * 有权限读取，并有空间存储快照文件。
  * 网络隔离时，使用 U 盘或安全传输方式。

* **操作**

  * 将整个 repository 目录复制至目标机器。

---

#### ✅ 步骤 3：在目标集群 B 准备 repository，粘贴目录并注册

* **条件检查**

  * 目标集群版本兼容。
  * 目标主机 `/path/to/repo_B` 可写入，权限正确。
  * Elasticsearch 节点读写该目录。

* **操作**

  * 首先不要注册 repository；
  * 粘贴目录文件到目标 `/path/to/repo_B`；
  * 然后执行：

    ```shell
    PUT /_snapshot/my_backup
    {
      "type": "fs",
      "settings": { "location": "/path/to/repo_B" }
    }
    ```
  * 重启 Elasticsearch（如果需要），确认 repository 被成功识别 ([docs.uipath.com][4])。

---

#### ✅ 步骤 4：在目标集群执行恢复操作

* **条件检查**

  * `my_backup` 仓库已成功注册，索引 snapshot 可以列出：`GET /_snapshot/my_backup/_all`。
  * 目标集群中尚未有同名索引（避免冲突）。
  * 某些内部 system 索引如 `.kibana` 若需恢复，必须使用 feature-state 模式。

* **命令**

  ```shell
  POST /_snapshot/my_backup/snapshot_20250729/_restore
  {
    "indices": "index_2022.07.29",
    "ignore_unavailable": false,
    "include_aliases": true
  }
  ```

* **恢复后检查**

  * 用 `GET index_2022.07.29/_search?size=0` 检查文档数；
  * 核对映射、setting 是否与源一致 ([Elastic][2], [Discuss the Elastic Stack][1])。

---

#### ✅ 步骤 5：重复导出多个索引时的注意

* 对于后续索引（如 index\_2022.07.28）：

  * 在源上重新 register → snapshot → unregister；
  * 在目标上 unregister（旧仓库）、删除旧文件、粘贴对应目录、register → restore；
  * 最后删除 snapshot（可选）防止积累多个 snapshot 导致混淆 ([Discuss the Elastic Stack][1])。

---

## 🛠 方法二：elasticdump 工具（适合在线可访问或需导出到本地文件传输的场景）

### 安装与条件

* Node.js 环境（推荐 ≥ v16），npm 已安装。
* 源 ES 与目标 ES 都可 HTTP 访问，须有用户名密码（若启用安全认证）。

```bash
npm install -g elasticdump
```

---

### 使用流程

#### 导出设置 (settings)

```bash
elasticdump \
  --input=http://user:pass@src:9200/my_index \
  --output=my_index_settings.json \
  --type=settings
```

#### 导出映射 (mapping)

```bash
elasticdump \
  --input=http://.../my_index \
  --output=my_index_mapping.json \
  --type=mapping
```

#### 导出数据 (data)

```bash
elasticdump \
  --input=http://.../my_index \
  --output=my_index_data.json \
  --type=data
```

* **检查点**

  * `_source` 必须为 `true`，否则数据无法导出 ([Stack Overflow][5], [Elastic][2])。
  * 确保 scroll API 没问题，可导出大批量数据。

---

### 在目标集群导入

```bash
elasticdump \
  --input=my_index_settings.json \
  --output=http://user:pass@dst:9200/my_index \
  --type=settings
```

```bash
elasticdump \
  --input=my_index_mapping.json \
  --output=http://... \
  --type=mapping
```

```bash
elasticdump \
  --input=my_index_data.json \
  --output=http://... \
  --type=data
```

* **验证**

  * 确认 index 存在并有正确映射；
  * 使用 `_search?size=0` 核对文档数量；
  * 若启用安全审计或别名，确保额外设置。

---

## 📊 总结对比

| 方法                 | 优点                                    | 必要条件                         | 适用场景                |
| ------------------ | ------------------------------------- | ---------------------------- | ------------------- |
| Snapshot + Restore | 保留 settings/mappings/system 索引，官方推荐流程 | 版本兼容、共享存储可复制、权限正确            | 私网隔离或完整迁移           |
| elasticdump        | 可指定导出查询，生成 JSON 文件，跨网络可操作             | 源/目标可 HTTP 访问、`_source=true` | 小规模、非 snapshot 支持环境 |

---

如你环境中 Elasticsearch 版本较老、系统索引也需迁移，推荐第一种 snapshot 方案；若只需几个用户索引或源不可 snapshot，则第二种工具方式即可。
你如果提供具体版本号、网络结构或平台（Docker、Cloud、K8s 等），我可以针对性地帮你调整脚本和命令模板。

[1]: https://discuss.elastic.co/t/proper-way-to-dump-indices-from-elasticsearch-and-import-to-another-elasticsearch-instance/310938?utm_source=chatgpt.com "Proper way to dump indices from Elasticsearch and import to ..."
[2]: https://www.elastic.co/docs/manage-data/migrate?utm_source=chatgpt.com "Migrate your Elasticsearch data | Elastic Docs"
[3]: https://github.com/elasticsearch-dump/elasticsearch-dump?utm_source=chatgpt.com "elasticsearch-dump/elasticsearch-dump: Import and export tools for ..."
[4]: https://docs.uipath.com/orchestrator/standalone/2024.10/installation-guide/migrating-elasticsearch-indices?utm_source=chatgpt.com "Orchestrator - Migrating Elasticsearch Indices - UiPath Documentation"
[5]: https://stackoverflow.com/questions/25144034/how-to-copy-some-elasticsearch-data-to-a-new-index/69387486?utm_source=chatgpt.com "How to copy some ElasticSearch data to a new index - Stack Overflow"

```

关于指定存储，咨询deepseek
```md
# 关于 elasticdump 的安装和卸载

## 指定目录安装

使用 `npm install -g` 安装全局包时，默认会安装到 npm 的全局目录中。如果你想指定安装目录，可以使用以下方法：

1. **使用 `--prefix` 参数**：
   ```bash
   npm install -g elasticdump --prefix=/path/to/your/directory
   ```

2. **修改 npm 全局目录**（永久改变）：
   ```bash
   npm config set prefix '/path/to/your/directory'
   npm config set prefix 'F:/temp-data/project/temp/migrate'
   npm install -g elasticdump
   ```

3. **使用本地安装**（非全局）：
   ```bash
   mkdir your_project && cd your_project
   npm init -y
   npm install elasticdump
   ```
   这样会安装在当前项目的 `node_modules` 目录中

## 卸载并释放空间

要卸载 elasticdump 并释放空间：

1. **卸载全局安装的 elasticdump**：
   ```bash
   npm uninstall -g elasticdump
   ```

2. **如果你想彻底清理 npm 缓存**：
   ```bash
   npm cache clean --force
   ```

3. **检查全局安装的包**：
   ```bash
   npm list -g --depth=0
   ```

4. **如果你想完全移除 npm 全局安装的所有包**（谨慎操作）：
   ```bash
   rm -rf $(npm root -g)/*
   ```

## 注意事项

- 使用 `--prefix` 安装后，确保将指定的目录添加到系统的 PATH 环境变量中，否则可能无法直接运行命令
- 全局安装通常需要管理员权限（在 Linux/Mac 上可能需要 `sudo`）
- 如果空间紧张，考虑使用本地安装而非全局安装

希望这些信息对你有帮助！

```

```md

## 在git中测试
elasticdump \
  --input=http://elasticsearch:pass@es-cn-nwy3go68w00059lv8.public.elasticsearch.aliyuncs.com:9200/my_index \
  --output=my_index_settings.json \
  --type=settings


elasticdump \
  --input=http://elasticsearch:${ES_PASS}@es-cn-cqf2xh6nd0001wben.public.elasticsearch.aliyuncs.com:9200/my_index \
  --output=my_index_settings.json \
  --type=settings

bash: elasticdump: command not found

/f/temp-data/project/temp/migrate/node_modules/.bin/elasticdump.cmd \
  --input=http://elasticsearch:${ES_PASS}@es-cn-cqf2xh6nd0001wben.public.elasticsearch.aliyuncs.com:9200/my_index \
  --output=my_index_settings.json \
  --type=settings

Tue, 05 Aug 2025 10:25:33 GMT | starting dump
F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:15
      err = new Error(response.body)
            ^

UNAUTHORIZED: {"error":{"root_cause":[{"type":"security_exception","reason":"unable to authenticate user [elasticsearch] for REST request [/]","header":{"WWW-Authenticate":"Basic realm=\"security\" charset=\"UTF-8\""}}],"type":"security_exception","reason":"unable to authenticate user [elasticsearch] for REST request [/]","header":{"WWW-Authenticate":"Basic realm=\"security\" charset=\"UTF-8\""}},"status":401}
    at Proxy.handleError (F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:15:13)
    at Proxy._parseVersion (F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:57:22)
    at Request.<anonymous> (F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:105:29)
    at Request._callback (F:\temp-data\project\temp\migrate\node_modules\lodash\lodash.js:10118:25)
    at Request.requestRetryReply [as reply] (F:\temp-data\project\temp\migrate\node_modules\requestretry\index.js:151:19)
    at Request.<anonymous> (F:\temp-data\project\temp\migrate\node_modules\requestretry\index.js:192:10)
    at process.processTicksAndRejections (node:internal/process/task_queues:95:5) {
  statusCode: 401
}

Node.js v20.17.0

/f/temp-data/project/temp/migrate/node_modules/.bin/elasticdump.cmd \
  --input=http://elasticsearch:${ES_PASS}@es-cn-cqf2xh6nd0001wben.public.elasticsearch.aliyuncs.com:9200/tracking_webhook \
  --output=my_index_settings.json \
  --type=settings

Tue, 05 Aug 2025 10:34:41 GMT | starting dump
F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:15
      err = new Error(response.body)
            ^

UNAUTHORIZED: {"error":{"root_cause":[{"type":"security_exception","reason":"unable to authenticate user [elasticsearch] for REST request [/]","header":{"WWW-Authenticate":"Basic realm=\"security\" charset=\"UTF-8\""}}],"type":"security_exception","reason":"unable to authenticate user [elasticsearch] for REST request [/]","header":{"WWW-Authenticate":"Basic realm=\"security\" charset=\"UTF-8\""}},"status":401}
    at Proxy.handleError (F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:15:13)
    at Proxy._parseVersion (F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:57:22)
    at Request.<anonymous> (F:\temp-data\project\temp\migrate\node_modules\elasticdump\lib\transports\__es__\_base.js:105:29)
    at Request._callback (F:\temp-data\project\temp\migrate\node_modules\lodash\lodash.js:10118:25)
    at Request.requestRetryReply [as reply] (F:\temp-data\project\temp\migrate\node_modules\requestretry\index.js:151:19)
    at Request.<anonymous> (F:\temp-data\project\temp\migrate\node_modules\requestretry\index.js:192:10)
    at process.processTicksAndRejections (node:internal/process/task_queues:95:5) {
  statusCode: 401
}

Node.js v20.17.0


```

## 20250806

```bash

# 测试
# curl -u elastic:${ES_PASS} http://es-cn-cqf2xh6nd0001wben.public.elasticsearch.aliyuncs.com:9200/
# sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS} /usr/local/nodejs/bin/elasticdump es-cn-cqf2xh6nd0001wben.elasticsearch.aliyuncs.com


# # 阿里云导出
# sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS} /usr/local/nodejs/bin/elasticdump es-cn-cqf2xh6nd0001wben.elasticsearch.aliyuncs.com '' tracking_webhook
# sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS} /usr/local/nodejs/bin/elasticdump es-cn-cqf2xh6nd0001wben.elasticsearch.aliyuncs.com output tracking_webhook '' /temp/elastic &>> /temp/elastic/tracking_webhook.20250806.log &

# # gcp测试环境导出导入
# sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS_GCP_TEST} /usr/local/nodejs/bin/elasticdump 10.26.2.10
# sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS_GCP_TEST} /usr/local/nodejs/bin/elasticdump 10.26.2.10 output tracking_webhook
# sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS_GCP_TEST} /usr/local/nodejs/bin/elasticdump 10.26.2.10 input tracking_webhook tracking_webhook_test_20250806

# # gcp测正式境导出备份
# sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS_GCP_TEST} /usr/local/nodejs/bin/elasticdump 10.26.1.8 output tracking_webhook
# 环境变量说明

# 阿里云生产环境
export ES_URL=es-cn-cqf2xh6nd0001wben.elasticsearch.aliyuncs.com
export ES_PASS=Tps2GyFQ6FtMNGpiue

# gcp测试环境
export GCP_ES_POD_0_TEST=10.26.2.10
export GCP_ES_PASS_TEST=F7C93iSY4s4S310jziRA2Fp0

# gcp原生产环境
export GCP_ES_POD_0_OLD=10.26.2.59
export GCP_ES_POD_1_OLD=10.26.1.44
export GCP_ES_POD_2_OLD=10.26.4.239
export GCP_ES_PASS_OLD_20250808=4K53GXE2B5M8X23aIu01bOLZ
export GCP_ES_PASS_OLD=7CRhR6y717USiE5l4I90Yf5o

# gcp现生产环境
export GCP_ES_URL=10.26.1.25
export GCP_ES_POD_0=10.26.2.59
export GCP_ES_POD_1=10.26.1.44
export GCP_ES_POD_2=10.26.4.239
export GCP_ES_PASS=2R2EouqS8t1p1854Jz1ADrE8

# gcp tracking_webhook 索引用生产环境
# export GCP_TRACKING_WEBHOOK_ES_POD_0=
# export GCP_TRACKING_WEBHOOK_ES_POD_1=
# export GCP_TRACKING_WEBHOOK_ES_POD_2=
# export GCP_TRACKING_WEBHOOK_ES_PASS=

# 传入参数
espasswd=$1
elasticdump=$2
esurl=$3
# type默认input
type=$4
index_name=$5
index_name_input=$6
dir=$7
# limit默认100，可传入参数调到1000~5000提高效率
limit="${8:-100}"
# search_body_id 默认0
search_body_id="${9:-0}"
search_body_max="${10:-1}"
search_body='{"slice":{"id":'${search_body_id}',"max":'${search_body_max}'},"sort":["_doc"]}'
search_body_gte="${11:-}"
search_body_lt="${12:-}"
search_body_out="${search_body}"
search_body_time=''
concurrency=20
# 时间范围查询不为空时，才进行查询
if [ -n "${search_body_gte}" ] && [ -n "${search_body_lt}" ]; then
  query_body='"query":{"range":{"create_time":{"gte":"'${search_body_gte}'","lt":"'${search_body_lt}'"}}}'
  search_body_out='{"slice":{"id":'${search_body_id}',"max":'${search_body_max}'},"sort":["_doc"],'${query_body}'}'
  search_body_time=_${search_body_gte}_${search_body_lt}
fi

file=${dir}/${index_name}_data${search_body_time}_slice_${search_body_id}_max_${search_body_max}.json
# ${elasticdump} \
#   --input=http://elastic:${espasswd}@${esurl}:9200/${index_name} \
#   --output=${index_name}.json \
#   --type=settings

# 执行前先打印
echo "curl -u elastic:${espasswd} http://${esurl}:9200/"
curl -u elastic:${espasswd} http://${esurl}:9200/
# 该接口会返回诸如 docs.count、store.size_in_bytes、total_size_in_bytes（包含字段数据等更全面指标）等信息
# curl -u elastic:${espasswd} http://${esurl}:9200/${index_name}/_stats
# 会以人类可读形式展示各索引占用的磁盘空间
curl -u elastic:${espasswd} http://${esurl}:9200/_cat/indices?v&h=index,store.size

# 通过测试


if [ "$type" = "output" ]; then
  if [ ${search_body_id} -eq 0 ]; then
    # settings：索引配置基础设置
    # 导出内容：包括分片数量、复制因子、刷新间隔、最大结果窗口等索引级别的配置参数；
    ${elasticdump} \
      --input=http://elastic:${espasswd}@${esurl}:9200/${index_name} \
      --output=${dir}/${index_name}_settings.json \
      --type=settings \
      --limit=${limit}

    # mapping：字段与类型定义（索引映射）
    # 导出内容：索引字段结构，包括字段名、类型（text、keyword、integer 等）、analyzer、nested/object、format 等属性；
    ${elasticdump} \
      --input=http://elastic:${espasswd}@${esurl}:9200/${index_name} \
      --output=${dir}/${index_name}_mapping.json \
      --type=mapping \
      --limit=${limit}
  fi

  # data：文档内容本身
  # 导出内容：索引中的所有文档 _source 内容，包括字段值；
  # 导出前 打印执行的命令
  echo "${elasticdump} --input=http://elastic:${espasswd}@${esurl}:9200/${index_name} --output=${file} --type=data --limit=${limit} --searchBody=${search_body}"
  ${elasticdump} \
    --input=http://elastic:${espasswd}@${esurl}:9200/${index_name} \
    --output=${file} \
    --type=data \
    --limit=${limit} \
    --searchBody=${search_body}
fi

# 检查点
# _source 必须为 true，否则数据无法导出 
# 确保 scroll API 没问题，可导出大批量数据。

if [ "$type" = "input" ]; then
  # 导入
  if [ ${search_body_id} -eq 0 ]; then
    ${elasticdump} --input=${dir}/${index_name}_settings.json --output=http://elastic:${espasswd}@${esurl}:9200/${index_name_input} --type=settings --limit=${limit}
    ${elasticdump} --input=${dir}/${index_name}_mapping.json  --output=http://elastic:${espasswd}@${esurl}:9200/${index_name_input} --type=mapping --limit=${limit}
  fi
  ${elasticdump} --input=${file}     --output=http://elastic:${espasswd}@${esurl}:9200/${index_name_input} --type=data --limit=${limit}
fi
# 验证
# 确认 index 存在并有正确映射；
# 使用 _search?size=0 核对文档数量；
# 若启用安全审计或别名，确保额外设置。


```

```md

前提条件
目标 ES 集群，在 gke 中的pod，Kubernetes Engine / Workloads / Pods，找到Exposing services中es-lb-svc进入，可以找到 Serving pods 中对应的IP 10.26.4.8，10.26.1.8，10.26.2.12，打通阿里云到gcp的VPN，需要在route中增加路由 10.26.0.0/16
![alt text](image.png)

在阿里云服务器上测试能ping通
ping 10.26.1.8
PING 10.26.1.8 (10.26.1.8) 56(84) bytes of data.
64 bytes from 10.26.1.8: icmp_seq=1 ttl=61 time=3.97 ms
64 bytes from 10.26.1.8: icmp_seq=2 ttl=61 time=2.96 ms
^C
--- 10.26.1.8 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 2.961/3.468/3.975/0.507 ms

目标 ES 集群，在 kibana 中创建索引
在目标集群创建测试索引
https://gcp-kibana.trackingmore.com/app/dev_tools#/console

PUT /tracking_webhook_test_20250806
{
  "settings": {  
    "number_of_shards": 3,  
    "number_of_replicas": 0  
  },  
  "mappings": {
    "properties": {
      "courier": {
        "type": "keyword"
      },
      "track_number": {
        "type": "keyword"
      },
      "uuid": {
        "type": "keyword"
      },
      "webhook_id": {
        "type": "integer"
      },
      "origin_info": {
        "type": "text",
        "index": false
      },
      "parse_info": {
        "type": "text",
        "index": false
      },
      "is_test": {
        "type": "boolean"
      },
      "create_time": {
        "type": "long"
      },
      "update_time": {
        "type": "long"
      },
      "parse_update_time": {
        "type": "long"
      }
    }
  }
}

进行测试

curl -XPOST "http://<自建Elasticsearch主机>:<端口>/_reindex?pretty" -H "Content-Type: application/json" -d'
{
  "source": {
    "remote": {
      "host": "http://<阿里云Elasticsearch实例ID>.elasticsearch.aliyuncs.com:9200",
      "username": "elastic",
      "password": "<密码>"
    },
    "index": "<源索引名>",
    "size": 1000,
    "slice": {
      "id": 0,
      "max": 5
    }
  },
  "dest": {
    "index": "<目标索引名>"
  }
}'

curl -XPOST "http://10.26.1.8:9200/_reindex?pretty" -H "Content-Type: application/json" -d'
{
  "source": {
    "remote": {
      "host": "http://es-cn-cqf2xh6nd0001wben.elasticsearch.aliyuncs.com:9200",
      "username": "elastic",
      "password": "<密码>"
    },
    "index": "tracking_webhook",
    "size": 1000,
    "slice": {
      "id": 0,
      "max": 5
    }
  },
  "dest": {
    "index": "tracking_webhook_test_20250806"
  }
}'

```

## 20250807

```bash

# 在定时任务cron中启动，会报错
/usr/bin/env: node: No such file or directory
/usr/bin/env: node: No such file or directory
/usr/bin/env: node: No such file or directory

# 使用nohup运行后台任务
nohup command &>> command.log &

# 重命名原文件备份

cd /temp/elastic/
find . -name '*json' | xargs -i mv {} {}.20250806
 ll
total 122499456
-rw-r--r-- 1 root root            0 Aug  6 19:08 elastic.log
-rw-r--r-- 1 root root          328 Aug  6 19:36 elastic.sh
-rw-r--r-- 1 root root     45880435 Aug  6 22:34 tracking_webhook.20250806.log
-rw-r--r-- 1 root root 125393530637 Aug  6 22:34 tracking_webhook_data.json.20250806
-rw-r--r-- 1 root root          467 Aug  6 19:46 tracking_webhook_mapping.json.20250806
-rw-r--r-- 1 root root          692 Aug  6 19:46 tracking_webhook_settings.json.20250806

# 使用nohup运行后台任务 导出阿里云es的tracking_webhook
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS} /usr/local/nodejs/bin/elasticdump es-cn-cqf2xh6nd0001wben.elasticsearch.aliyuncs.com output tracking_webhook '' /temp/elastic &>> /temp/elastic/tracking_webhook.20250807.log &
# 使用nohup运行后台任务 导出gcp生产es的tracking_webhook
# 查看数据
sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS} /usr/local/nodejs/bin/elasticdump 10.26.1.8 test tracking_webhook
# 正式导出
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS} /usr/local/nodejs/bin/elasticdump 10.26.1.8 output tracking_webhook '' /temp/elastic/gcp &>> /temp/elastic/tracking_webhook.output.gcp.20250807.log &

# 阿里云
# 集群配置 3个节点 500G使用率 约50% 即250G
# tracking_webhook 记录数 24169564 
# gcp
# 集群配置 3个节点 65G
# tracking_webhook 记录数 2236685 暂用磁盘 1.6G 预计 需要18G

# 查看
sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_1} test tracking_webhook
# 使用nohup运行后台任务 导入
echo `date` >> /temp/elastic/tracking_webhook.input.20250807.log
echo start >> /temp/elastic/tracking_webhook.input.20250807.log
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_1} input tracking_webhook tracking_webhook /temp/elastic &>> /temp/elastic/tracking_webhook.input.20250807.log &
echo error >> /temp/elastic/tracking_webhook.input.20250807.log
echo end >> /temp/elastic/tracking_webhook.input.20250807.log
echo `date` >> /temp/elastic/tracking_webhook.input.20250807.log

# 查看
sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_2} test tracking_webhook
# 使用nohup运行后台任务 导入
echo `date` >> /temp/elastic/tracking_webhook.input.20250807.log
echo start >> /temp/elastic/tracking_webhook.input.20250807.log
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_2} input tracking_webhook tracking_webhook /temp/elastic &>> /temp/elastic/tracking_webhook.input.20250807.log &
echo error >> /temp/elastic/tracking_webhook.input.20250807.log
echo end >> /temp/elastic/tracking_webhook.input.20250807.log
echo `date` >> /temp/elastic/tracking_webhook.input.20250807.log

```

### 咨询ai

参考 迁云/es/获取最小和最大timestamp.md

## 20250809

```bash

# 更新环境变量
# 查看修改后效果
sed -n -e 's/^\(export GCP_ES_POD_0=\).*/\110.26.2.59/p' -e 's/^\(export GCP_ES_POD_1=\).*/\110.26.1.44/p' -e 's/^\(export GCP_ES_POD_2=\).*/\110.26.4.239/p' /etc/profile.d/env.sh
# 修改
sed -i -e 's/^\(export GCP_ES_POD_0=\).*/\110.26.2.59/' -e 's/^\(export GCP_ES_POD_1=\).*/\110.26.1.44/' -e 's/^\(export GCP_ES_POD_2=\).*/\110.26.4.239/' /etc/profile.d/env.sh
# 查看修改后效果
sed -n -e 's/^\(export GCP_ES_POD_0=\).*/\110.26.2.59/p' -e 's/^\(export GCP_ES_POD_1=\).*/\110.26.1.44/p' -e 's/^\(export GCP_ES_POD_2=\).*/\110.26.4.239/p' /etc/profile.d/env.sh

```

测试limit 1000效果
```bash
day=$(date +%Y%m%d)
mkdir /temp/elastic/${day}
# 查看
sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS} /usr/local/nodejs/bin/elasticdump ${ES_URL} test tracking_webhook

# 使用nohup运行后台任务 导出
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${ES_PASS} /usr/local/nodejs/bin/elasticdump ${ES_URL} output tracking_webhook '' /temp/elastic/${day} 1000 &>> /temp/elastic/tracking_webhook.output.${day}.log &
# 速度大概是原来的2倍多
 tail -10000  /temp/elastic/tracking_webhook.output.${day}.log | grep 12000000
Sat, 09 Aug 2025 07:56:30 GMT | got 1000 objects from source elasticsearch (offset: 12000000)
Sat, 09 Aug 2025 07:56:30 GMT | sent 1000 objects, 12000000 offset, to destination file, wrote 1000
head -10000  /temp/elastic/tracking_webhook.output.${day}.log | grep 1000 | head
Sat, 09 Aug 2025 06:41:06 GMT | got 0 objects from source file (offset: 1000)
Sat, 09 Aug 2025 07:02:59 GMT | got 0 objects from source file (offset: 1000)
# # 当前速度 1200w用时 35分钟，240w预计70分钟
# 12000000/35/60=5714.28571429
# # 原来速度
# 11:46:14 -- 14:34:54
# 14*3600+34*60+54-(11*3600+46*60+14)=10120
# 24136300/10120=2385.00988142
# 当前是原来 5714.28571429/2385.00988142=2.395917

# 使用nohup运行后台任务 导入
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_TEST} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_TEST} input tracking_webhook tracking_webhook /temp/elastic/${day} 1000 &>> /temp/elastic/tracking_webhook.input.${day}.log &
# 速度大概是原来
head -10000  /temp/elastic/tracking_webhook.input.${day}.log | grep 1000 | head
Sat, 09 Aug 2025 08:16:00 GMT | got 0 objects from source file (offset: 1000)
Sat, 09 Aug 2025 08:16:00 GMT | got 0 objects from source file (offset: 1000)
Sat, 09 Aug 2025 08:16:01 GMT | got 1000 objects from source file (offset: 0)
Sat, 09 Aug 2025 08:16:01 GMT | got 1000 objects from source file (offset: 1000)
Sat, 09 Aug 2025 08:16:01 GMT | sent 1000 objects, 0 offset, to destination elasticsearch, wrote 1000
Sat, 09 Aug 2025 08:16:02 GMT | got 1000 objects from source file (offset: 2000)
Sat, 09 Aug 2025 08:16:02 GMT | sent 1000 objects, 1000 offset, to destination elasticsearch, wrote 1000
Sat, 09 Aug 2025 08:16:02 GMT | got 1000 objects from source file (offset: 3000)
Sat, 09 Aug 2025 08:16:02 GMT | sent 1000 objects, 2000 offset, to destination elasticsearch, wrote 1000
Sat, 09 Aug 2025 08:16:02 GMT | got 1000 objects from source file (offset: 4000)
# # 当前速度
# 700000/12/60=972.2222222
# # 原来速度
# 14:59:51 -- 11:47:13
# 71*3600+47*60+13-(14*3600+59*60+51)=204442
# 24169400/204442=118.22130482
# # 当前是原来
# 972.2222222/118.22130482=8.22374803

rm -rf /temp/elastic/${day}/tracking_webhook*

```

切片并行（Sliced Scroll）：在 --searchBody 里加 slice，开 N 份并发跑 N 个 elasticdump 进程（id=0..N-1），总吞吐更高
```bash
day=$(date +%Y%m%d)
mkdir /temp/elastic/${day}
# 查看
sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_OLD} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_OLD} test tracking_webhook

# 使用nohup运行后台任务 导出
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_OLD} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_OLD} output tracking_webhook '' /temp/elastic/${day} 1000 0 5 &>> /temp/elastic/tracking_webhook.output.old.${day}.log &
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_OLD} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_OLD} output tracking_webhook '' /temp/elastic/${day} 1000 1 5 &>> /temp/elastic/tracking_webhook.output.old.1.${day}.log &
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_OLD} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_OLD} output tracking_webhook '' /temp/elastic/${day} 1000 2 5 &>> /temp/elastic/tracking_webhook.output.old.2.${day}.log &
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_OLD} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_OLD} output tracking_webhook '' /temp/elastic/${day} 1000 3 5 &>> /temp/elastic/tracking_webhook.output.old.3.${day}.log &
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_OLD} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_OLD} output tracking_webhook '' /temp/elastic/${day} 1000 4 5 &>> /temp/elastic/tracking_webhook.output.old.4.${day}.log &
# # 速度大概是原来 8倍
# 10:10:10 -- 10:44:55
# 10*3600+44*60+55-(10*3600+10*60+10)=2085
# 8087197/2085=3878.75155875
# 3878.75155875/2385.00988142*5=8.13152094
# # 速度大概是原来 5倍
# 10:07:18 -- 10:35:14
# 10*3600+35*60+14-(10*3600+7*60+18)=1676
# 4042601/1676=2412.05310263
# 2412.05310263/2385.00988142*5=5.05669415

# 使用nohup运行后台任务 导入
nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_TEST} /usr/local/nodejs/bin/elasticdump ${GCP_ES_POD_0_TEST} input tracking_webhook tracking_webhook /temp/elastic/${day} 1000 &>> /temp/elastic/tracking_webhook.input.old.${day}.log &

```

```bash
# 先扩容
GPT分区（需安装gdisk工具）

 
type growpart || sudo yum install -y cloud-utils-growpart
sudo yum update cloud-utils-growpart
type sgdisk || sudo yum install -y gdisk
sudo LC_ALL=en_US.UTF-8 growpart /dev/vdb 1 
```

切片 并按时间条件

```bash
# 支持传参，未传参时使用默认值
# 用法示例：
#   bash your_script.sh [pass] [url] [index] [input_index] [type] [limit] [max] [dir] [start_time] [end_time] [id] [task_label] [shell_script] [elasticdump]
#   参数说明：
#     [pass]                ES 密码，默认取环境变量 ES_PASS
#     [url]                 ES 地址，默认取环境变量 ES_URL
#     [index]               主索引名，默认 bigdata_shipments_all_v6
#     [input_index]         输入索引名，默认与 index 相同
#     [type]                操作类型：output(导出) 或 input(导入)，默认 output
#     [limit]               每批导出/导入的文档数，默认 1000
#     [max]                 并发最大数，默认 1（待优化：如果传了，至少是2）
#     [dir]                 导出/导入数据目录，默认 /temp/elastic/当前日期
#     [start_time]          导出起始时间（Unix时间戳），可选
#     [end_time]            导出结束时间（Unix时间戳），可选
#     [id]                  单进程编号（用于多进程并发时区分每个任务的序号），可选，默认不传即为 ''
#     [task_label]          任务标签（可选，用于标记本次任务，便于日志区分），默认不传即为 ''
#     [shell_script]        shell脚本路径，默认 /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh
#     [elasticdump]         elasticdump工具路径，默认 /usr/local/nodejs/bin/elasticdump
#   导出 bigdata_shipments_all_v6
#   bash your_script.sh ${ES_PASS} ${ES_URL} bigdata_shipments_all_v6 '' output 1000 10 /temp/elastic/bigdata_20250809 1738339200 1754740800
#   导入 bigdata_shipments_all_v6
#   bash your_script.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} bigdata_shipments_all_v6 '' input 1000 10 /temp/elastic/bigdata_20250809 1738339200 1754740800
#   导入 tracking_webhook
#   bash your_script.sh ${GCP_TRACKING_WEBHOOK_ES_PASS} ${GCP_TRACKING_WEBHOOK_ES_POD_0} tracking_webhook '' input 1000 5 /temp/elastic/20250809
#     原来的18倍
#     132000/304=434.21052632
#     434.21052632/118.22130482*5=18.3643095
#     出现429，尝试单进程执行
#     bash your_script.sh ${GCP_TRACKING_WEBHOOK_ES_PASS} ${GCP_TRACKING_WEBHOOK_ES_POD_0} tracking_webhook '' input 1000 5 /temp/elastic/20250809 '' '' 0
#   导出 user_number_v2_*
#   bash your_script.sh ${ES_PASS} ${ES_URL} user_number_v2_* '' output 1000 10 /temp/elastic/user_number_v2_20250810
#   导入 user_number_v2_*
#   bash your_script.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} user_number_v2_* '' input 1000 10 /temp/elastic/user_number_v2_20250810

# 1. ES 密码
pass="${1:-${ES_PASS}}"

# 2. ES 地址
url="${2:-${ES_URL}}"

# 3. 导出/导入的主索引名
index="${3:-bigdata_shipments_all_v6}"

# 4. 输入索引名（如不指定，默认与index相同）
input_index="${4:-$index}"

# 5. 操作类型：output(导出) 或 input(导入)
type="${5:-output}"

# 6. 每批导出/导入的文档数
limit="${6:-1000}"

# 7. 并发最大数（max） 如果传了
max="${7:-1}"

# 获取当前日期，格式为YYYYMMDD
day=$(date +%Y%m%d)
# 定义导出数据的目录，默认包含日期
dir="${8:-/temp/elastic/${day}}"
# 如果目录不存在则创建
if [ ! -d "${dir}" ]; then
    mkdir -p "${dir}"
fi

# 9. 导出起始时间（Unix时间戳，默认示例值）
start_time="${9:-}"

# 10. 导出结束时间（Unix时间戳，默认示例值）
end_time="${10:-}"

# 11. 指定单进程运行的编号（用于多进程并发时区分每个任务的序号）
# 如果指定了 id，则每次只运行一个对应编号的任务；如果未指定，则默认会运行所有任务（即全部并发）
id="${11:-}"

# 12. 任务标识（如 aaa），用于区分不同任务的日志文件名
#    - 如果传入了任务标识，则 task_label=".${12}"
#    - 如果未传入，则 task_label=""
if [ -n "${12}" ]; then
    task_label=".${12}"
else
    task_label=""
fi

# 13. shell脚本路径
shell_script="${13:-/home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh}"

# 14. elasticdump工具路径
elasticdump="${14:-/usr/local/nodejs/bin/elasticdump}"

# 备注：
# - 可通过传参覆盖默认值，便于脚本复用和自动化。
# - 变量顺序与参数顺序一致，便于理解和维护。
# 查看
sh ${shell_script} ${pass} ${elasticdump} ${url} test ${index}

# # 使用nohup运行后台任务 导出
# nohup sh ${shell_script} ${pass} ${elasticdump} ${url} ${type} ${index} ${input_index} ${dir} ${limit} 0 5 ${start_time} ${end_time} &>> ${dir}/${index}.${type}.0.${day}.log &
# nohup sh ${shell_script} ${pass} ${elasticdump} ${url} ${type} ${index} ${input_index} ${dir} ${limit} 1 5 ${start_time} ${end_time} &>> ${dir}/${index}.${type}.1.${day}.log &
# nohup sh ${shell_script} ${pass} ${elasticdump} ${url} ${type} ${index} ${input_index} ${dir} ${limit} 2 5 ${start_time} ${end_time} &>> ${dir}/${index}.${type}.2.${day}.log &
# nohup sh ${shell_script} ${pass} ${elasticdump} ${url} ${type} ${index} ${input_index} ${dir} ${limit} 3 5 ${start_time} ${end_time} &>> ${dir}/${index}.${type}.3.${day}.log &
# nohup sh ${shell_script} ${pass} ${elasticdump} ${url} ${type} ${index} ${input_index} ${dir} ${limit} 4 5 ${start_time} ${end_time} &>> ${dir}/${index}.${type}.4.${day}.log &
# # 速度大概是原来
# 163000/168=970.23809524
# 863000/385=2241.55844156
# 1096000/240=4566.66666667
# 2595000/552=4701.08695652
# 970.23809524/2385.00988142*5=2.0340337
# 4701.08695652/2385.00988142*5=9.85548738

# 使用nohup运行后台任务

for i in $(seq 0 $((max-1))); do
  
    # 如果指定了id，只执行该id对应的任务
    if [ -n "${id}" ]; then
        if [ "$i" -ne "$id" ]; then
            continue
        fi
    fi
    # 执行前输出执行命令，便于调试和日志追踪
    echo "nohup sh ${shell_script} ${pass} ${elasticdump} ${url} ${type} ${index} ${input_index} ${dir} ${limit} $i $max ${start_time} ${end_time} &>> ${dir}/${index}.${type}${task_label}.$i.${day}.log &"
    nohup sh ${shell_script} \
        ${pass} ${elasticdump} ${url} ${type} ${index} ${input_index} ${dir} ${limit} $i $max ${start_time} ${end_time} \
        &>> ${dir}/${index}.${type}${task_label}.$i.${day}.log &
done
# # 导出 速度大概是原来 17倍
# 854000/210=4066.66666667
# 1400000/330=4242.42424242
# 4066.66666667/2385.00988142*10=17.05094263

# # 使用nohup运行后台任务 导入
# nohup sh /home/wwwroot/www.trackingmore.com/script/queueshell/serverMigration/elastic_test.sh ${GCP_ES_PASS_TEST} ${elasticdump} ${GCP_ES_POD_0_TEST} input ${index} ${index} /temp/elastic/${day} 1000 &>> /temp/elastic/tracking_webhook.input.old.${day}.log &

```

文件批量重命名

```bash

# 1. 如果是 Perl 版 rename（Debian/Ubuntu 常见）
rename 's/\.json$/_max_10.json/' bigdata_shipments_all_v6_data_1738339200_1754740800_slice_*.json

# 2. 如果是 util-linux 版 rename（CentOS/Alpine 常见）
rename .json _max_10.json bigdata_shipments_all_v6_data_1738339200_1754740800_slice_*.json

# 3. 通用方案（跨系统可用）
for f in bigdata_shipments_all_v6_data_1738339200_1754740800_slice_*.json; do
    mv -- "$f" "${f%.json}_max_10.json"
done
# ${f%.json} 会去掉文件名最后的 .json

# 再加上 _max_10.json 就完成重命名

# -- 确保即使文件名有 - 也能安全处理。


```

## 20250810

### 咨询ai

已经有副本，修改为0会不会导致需要删除副本让性能临时下降

是的，如果你现在已经有副本分片，临时把 `number_of_replicas` 改成 `0` 会触发**副本分片删除**，集群会经历一个重新分配过程，这个过程会带来两方面影响：

---

#### 影响分析

1. **副本分片会被删除**

   * 删除操作本身是很快的（比创建快），但集群会有一段时间内副本不可用，等于失去了高可用。
   * 在这个阶段，如果主分片所在节点宕机，该分片上的数据就会丢失，必须手动从快照/备份恢复。

2. **集群负载变化**

   * 删除副本会减少写入同步压力，批量导入时写入性能能明显提升。
   * 但同时，读请求会集中打到主分片，如果原来读压力很高，可能造成读延迟上升。

3. **恢复时会有性能下降**

   * 导入完成后把副本数恢复为原来的值（比如 1），Elasticsearch 会重新为每个主分片分配并复制数据到副本分片，这个**复制过程会消耗磁盘 IO 和网络带宽**，在恢复期间写入和查询性能都会下降。

---

#### 建议做法

* **导入窗口选择低峰期**，避免恢复副本时与业务高峰重叠。
* 如果数据安全要求高，可以不把 `number_of_replicas` 改成 0，而是只调低 `refresh_interval`，这样写入性能也能提高，但保留高可用。
* 如果必须改成 0，建议：

  1. 确保有近期快照或备份。
  2. 导入完成后，先用 `POST _refresh` 刷新数据，再把 `number_of_replicas` 改回原值。
  3. 观察 `cluster health`，等状态恢复到 `green` 再认为恢复完成。

---

我可以帮你画一张\*\*“副本调整与导入性能关系”流程图\*\*，让你直观看到从副本删除到恢复的性能曲线和风险点，你要我帮你画吗？这样方便评估改不改。


### tracking_webhook索引导入出现429，根本原因是磁盘不足

```bash
GET /_cat/allocation?v
shards disk.indices disk.used disk.avail disk.total disk.percent host        ip          node
    19       26.2gb      27gb      2.3gb     29.3gb           92 10.26.20.83 10.26.20.83 elasticsearch-es-default-0
    12       26.5gb    27.3gb        2gb     29.3gb           93 10.26.3.18  10.26.3.18  elasticsearch-es-default-2
     0       18.1gb    29.3gb        4kb     29.3gb           99 10.26.3.19  10.26.3.19  elasticsearch-es-default-1
    13                                                                                   UNASSIGNED
```

### concurrency 提升并发

- 速度&时间
  - 原来 单一进程 10小时 1760000 总10进程
      - 1760000/10/3600*10≈489 条/s
  - 20配置 单一进程 10分钟 113000 总10进程
    - 113000/10/60*10≈1883 条/s
  - 1.7亿预计时间
    - 170000000/1883/3600≈25h
  
## 20250811

- 大数据索引
  - 启动时间 0811 00:33
  - 查看进度
    - tail /temp/elastic/bigdata_20250809/bigdata_shipments_all_v6.output.1.20250809.log /temp/elastic/bigdata_20250809/bigdata_shipments_all_v6.input.task_up_20.1.20250811.log 
  - 时间预估
    - (9*60+15)/(411/1605)/60-(9+15/60)≈26.87 9:48 26.87-24=2.87 0.87*60=52.2 预计 0812 11:40完成
    - (14*60-10)/(755/1605)/60-(14-10/60)≈15.57 14:23 15.57-10=5.57 0.57*60=34.2 34.2+23=57.2 预计 0812 6:40完成
    - (21*60+27)/(1140/1605)/60-(21+27/60)≈8.75 22:00 8.75-2=6.75 0.75*60 预计 0812 6:45完成

- k8s新生成的es实例，需要重新获取密码
  - kubectl get secret elasticsearch-es-elastic-user -o yaml -n fjny-tm-twkes-pro -o jsonpath='{.data.elastic}' | base64 -d

- tracking_webhook 扩容后继续导
  - 以第一个id为例（总5个）
    - sh /temp/elastic/elastic.sh ${GCP_TRACKING_WEBHOOK_ES_PASS} ${GCP_TRACKING_WEBHOOK_ES_POD_0} tracking_webhook '' input 1000 5 /temp/elastic/20250809 '' '' 0 task_solve429_up_20
  - 启动时间 0811 17:00
  - 查看进度
    - tail /temp/elastic/20250809/tracking_webhook.input.task_solve429_up_20.0.20250811.log /temp/elastic/tracking_webhook.output.old.0.20250809.log

```txt
0809获取待迁移es索引
重要：
tracking_webhook                            24262909        68.3gb  22.6gb
bigdata_shipments_all_v6                    409674272       566gb   284gb
user_number_v2_*                            675000          245.7mb 245.7mb



其它：
ai_edd_data_stat_experience_v1              126195          30.3mb    15mb
tmp_ai_edd_none_delivery_dayofweek_v1       8005            987.5kb 498.5kb
tmp_ai_edd_data_stat_v1                     4613535         4gb     2gb
tmp_ai_edd_exper_config_v1                  456733          117.4mb  58.6mb
ofline_test                                 9562            3.3mb   3.3mb
callback_failures                           716089          180.1mb 180.1mb
ods_country_postal_code_v1                  5617107         2.7gb   1.3gb
```

```bash


#   导出 ai_edd_data_stat_experience_v1,tmp_ai_edd_none_delivery_dayofweek_v1,tmp_ai_edd_data_stat_v1,tmp_ai_edd_exper_config_v1,ofline_test,callback_failures,ods_country_postal_code_v1
#   bash /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} ai_edd_data_stat_experience_v1,tmp_ai_edd_none_delivery_dayofweek_v1,tmp_ai_edd_data_stat_v1,tmp_ai_edd_exper_config_v1,ofline_test,callback_failures,ods_country_postal_code_v1 '' output 1000 2 /temp/elastic/other_20250811
#   导入 ai_edd_data_stat_experience_v1,tmp_ai_edd_none_delivery_dayofweek_v1,tmp_ai_edd_data_stat_v1,tmp_ai_edd_exper_config_v1,ofline_test,callback_failures,ods_country_postal_code_v1
#   bash /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} ai_edd_data_stat_experience_v1,tmp_ai_edd_none_delivery_dayofweek_v1,tmp_ai_edd_data_stat_v1,tmp_ai_edd_exper_config_v1,ofline_test,callback_failures,ods_country_postal_code_v1 '' input 1000 2 /temp/elastic/other_20250811
# #出现报错
# {
#   _index: 'ai_edd_data_stat_experience_v1,tmp_ai_edd_none_delivery_dayofweek_v1,tmp_ai_edd_data_stat_v1,tmp_ai_edd_exper_config_v1,ofline_test,callback_failures,ods_country_postal_code_v1',
#   _type: '_doc',
#   _id: 'JAPxgJYBya66PftXVFat',
#   status: 400,
#   error: {
#     type: 'invalid_index_name_exception',
#     reason: 'Invalid index name [ai_edd_data_stat_experience_v1,tmp_ai_edd_none_delivery_dayofweek_v1,tmp_ai_edd_data_stat_v1,tmp_ai_edd_exper_config_v1,ofline_test,callback_failures,ods_country_postal_code_v1], must not contain the following characters [ , ", *, \\, <, |, ,, >, /, ?]',
#     index_uuid: '_na_',
#     index: 'ai_edd_data_stat_experience_v1,tmp_ai_edd_none_delivery_dayofweek_v1,tmp_ai_edd_data_stat_v1,tmp_ai_edd_exper_config_v1,ofline_test,callback_failures,ods_country_postal_code_v1'
#   }
# }

# 导出
sh /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} ai_edd_data_stat_experience_v1 '' output 1000 2 /temp/elastic/ai_edd_data_stat_experience_v1_20250811
sh /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} tmp_ai_edd_none_delivery_dayofweek_v1 '' output 1000 2 /temp/elastic/tmp_ai_edd_none_delivery_dayofweek_v1_20250811
sh /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} tmp_ai_edd_data_stat_v1 '' output 1000 2 /temp/elastic/tmp_ai_edd_data_stat_v1_20250811
sh /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} tmp_ai_edd_exper_config_v1 '' output 1000 2 /temp/elastic/tmp_ai_edd_exper_config_v1_20250811
sh /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} ofline_test '' output 1000 2 /temp/elastic/ofline_test_20250811
sh /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} callback_failures '' output 1000 2 /temp/elastic/callback_failures_20250811
sh /temp/elastic/elastic.sh ${ES_PASS} ${ES_URL} ods_country_postal_code_v1 '' output 1000 2 /temp/elastic/ods_country_postal_code_v1_20250811

# 导入
sh /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} ai_edd_data_stat_experience_v1 '' input 1000 2 /temp/elastic/ai_edd_data_stat_experience_v1_20250811
sh /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} tmp_ai_edd_none_delivery_dayofweek_v1 '' input 1000 2 /temp/elastic/tmp_ai_edd_none_delivery_dayofweek_v1_20250811
sh /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} tmp_ai_edd_data_stat_v1 '' input 1000 2 /temp/elastic/tmp_ai_edd_data_stat_v1_20250811
sh /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} tmp_ai_edd_exper_config_v1 '' input 1000 2 /temp/elastic/tmp_ai_edd_exper_config_v1_20250811
sh /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} ofline_test '' input 1000 2 /temp/elastic/ofline_test_20250811
sh /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} callback_failures '' input 1000 2 /temp/elastic/callback_failures_20250811
sh /temp/elastic/elastic.sh ${GCP_ES_PASS} ${GCP_ES_POD_0} ods_country_postal_code_v1 '' input 1000 2 /temp/elastic/ods_country_postal_code_v1_20250811


```
