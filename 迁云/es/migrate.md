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

## 测试
elasticdump \
  --input=http://elasticsearch:pass@es-cn-nwy3go68w00059lv8.public.elasticsearch.aliyuncs.com:9200/my_index \
  --output=my_index_settings.json \
  --type=settings

```
