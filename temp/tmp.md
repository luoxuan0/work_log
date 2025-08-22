# Incident Analysis Report

- Host tag: esxi-web01
- Timestamp: 2025-08-21 12:18:55+0800
- Working dir: /var/log/ir-python/20250821-121727

## Findings
- Exec: `/usr/bin/log`  SHA256: `unknown`
- Exec: `/usr/log`  SHA256: `unknown`
- Exec: `/var/log/log`  SHA256: `unknown`

### Rule hits & reasons
- 非常规可执行路径（/var/log 或伪装 log）(+30)
- unit 名 python.service 与实际二进制不符（如 log）(+10)
- root crontab 存在 @reboot 可疑项 (+20)
- 系统 cron 目录命中可疑路径 (+10)
- 可执行不属于已安装包 (+15)
- strings 命中可疑指令/矿工关键字 (+10)
- unit 为本地自建（/etc/systemd/system）(+5)

### Score
- Total score: **100** (>=60: Malicious likely, 30-59: Suspicious, <30: Unclear/Benign)

## Verdict
- **Malicious likely**

## IOCs
- Path: `/usr/bin/log`  SHA256: `unknown`
- Path: `/usr/log`  SHA256: `unknown`
- Path: `/var/log/log`  SHA256: `unknown`
- PIDs: ``
- Open ports (snapshot):
  LISTEN   0         32768              0.0.0.0:3306              0.0.0.0:*        users:(("docker-proxy",pid=1879525,fd=4))                                      
  LISTEN   0         4096         127.0.0.53%lo:53                0.0.0.0:*        users:(("systemd-resolve",pid=1236,fd=12))                                     
  LISTEN   0         128                0.0.0.0:22                0.0.0.0:*        users:(("sshd",pid=1380,fd=3))                                                 
  LISTEN   0         32768                 [::]:3306                 [::]:*        users:(("docker-proxy",pid=1879532,fd=4))                                      
  LISTEN   0         128                   [::]:22                   [::]:*        users:(("sshd",pid=1380,fd=4))                                                 

## Recommended actions
1. **立即阻断（不改现场）：** 运行 `--strict --neutralize`（stop + mask --runtime）。
2. **业务窗口永久清除：** 运行 `--neutralize`（禁用 unit、清理 cron、隔离二进制），随后 `--restore` 可回撤。
3. **凭据轮换：** root 与相关服务账号口令、SSH Key、API Token 全量轮换。
4. **横向排查：** 检查同网段/同集群主机是否存在相同 IOC（路径/哈希/cron）。
5. **日志审计：** 回看 `authlog/lastb`、包管理/命令审计日志、Web 访问日志中可疑上传/执行。
6. **离线分析：** 对隔离的二进制进行沙箱与 YARA 扫描；如涉及合规，启动正式事件管理流程。

### Helpful commands
- 仅停止：`./ir-python-audit.sh --suspend --case-tag HOST`
- 恢复：   `./ir-python-audit.sh --resume /var/log/ir-python/<ts>/snapshot.json`
- 严格阻断：`./ir-python-audit.sh --strict --neutralize --case-tag HOST`
- 永久清理：`./ir-python-audit.sh --neutralize --case-tag HOST`
- 回撤处置：`./ir-python-audit.sh --restore /var/log/ir-python/<ts>/snapshot.json`