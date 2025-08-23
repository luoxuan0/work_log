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


```txt

PowerShell命令行文件操作全指南
PowerShell作为Windows系统强大的命令行工具，提供了丰富的文件操作功能。以下从文件创建、属性查看/修改、批量处理三个维度详细介绍常用命令。

文件基础操作：创建与内容编辑
新建文件
使用New-Item命令可快速创建文件，例如在E:\test目录创建test.txt ：

New-Item -Path "E:\test\test.txt"  -ItemType File
执行后将在目标路径生成指定文件1。

编辑文件内容

覆盖写入：Set-Content -Path "文件路径" -Value "内容"
追加内容：Add-Content -Path "文件路径" -Value "追加文本"
调用记事本编辑：Invoke-Item -Path "文件路径"（需手动保存）3
文件属性管理：时间与元数据修改
时间属性操作
操作类型	查看命令	修改命令示例
创建时间	(Get-Item 路径).CreationTime	(Get-Item 路径).CreationTime = "2025-08-22 17:00:00"
最后修改时间	(Get-Item 路径).LastWriteTime	(Get-Item 路径).LastWriteTime = (Get-Date).AddDays(-1)
最后访问时间	(Get-Item 路径).LastAccessTime	(Get-Item 路径).LastAccessTime = [DateTime]::UtcNow
时间格式支持本地时间（默认）和UTC时间，修改时需注意权限1。

高级属性设置
通过Get-Item结合属性赋值可修改隐藏、只读等特性：

# 设置为隐藏文件
(Get-Item "test.txt").Attributes  += "Hidden"
# 移除只读属性
(Get-Item "test.txt").Attributes  -= "ReadOnly"
批量文件处理：高效管理多文件
批量重命名
创建.ps1脚本实现规则化重命名：

$path = "E:\test"
Get-ChildItem -Path $path -File | ForEach-Object {
    $newName = "prefix_$($_.Name)"
    Rename-Item -Path $_.FullName -NewName $newName
}
保存为rename.ps1 后，在PowerShell中执行.\rename.ps1 即可批量添加前缀2。

文件夹遍历与批量操作
使用Get-ChildItem递归处理子文件：

# 遍历所有.txt文件并修改编码
Get-ChildItem -Path "E:\test" -Filter *.txt -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    Set-Content -Path $_.FullName -Value $content -Encoding UTF8
}
该命令可批量转换指定目录下所有文本文件的编码格式1。

注意事项与故障排除
权限问题：修改系统文件需以管理员身份运行PowerShell（Win+X选择"管理员模式"）
执行策略：若脚本运行失败，需先执行Set-ExecutionPolicy RemoteSigned解除限制2
编码处理：中文乱码时可通过chcp 65001切换至UTF-8编码3
通过上述命令组合，可实现从单文件操作到批量自动化管理的全流程文件控制，适用于日常维护、数据整理等场景。

以上内容均由AI搜集总结并生成，仅供参考



New-Item -Path "E:\test\test.txt"  -ItemType File
New-Item -Path "F:\temp-data\project\temp\等保\indows_password_policy.ps1"  -ItemType File
调用记事本编辑：Invoke-Item -Path "文件路径"（需手动保存）


F:\temp-data\project\temp\等保\indows_password_policy.ps1 -Preview
indows_password_policy.ps1 : 无法加载文件 indows_password
_policy.ps1，因为在此系统上禁止运行脚本

遇到 PowerShell 脚本无法执行的问题（错误提示："在此系统上禁止运行脚本"），这是由于系统执行策略限制所致。以下是详细解决方案：

🔒 解决方案：修改 PowerShell 执行策略
步骤 1：以管理员身份启动 PowerShell
在开始菜单搜索 PowerShell → 右键选择 “以管理员身份运行”（必需管理员权限）23。
步骤 2：查看当前执行策略
Get-ExecutionPolicy
若返回 Restricted（默认值），表示禁止所有脚本运行 14。
步骤 3：修改执行策略为允许本地脚本
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
RemoteSigned：允许运行本地创建的脚本，仅限制来自网络的未签名脚本 23。
输入 Y 确认更改。
步骤 4：验证是否生效
Get-ExecutionPolicy # 应返回 RemoteSigned
️ 注意事项
安全提示：
RemoteSigned 是平衡安全与灵活性的推荐选项，避免使用 Unrestricted（完全放行）25。
仅限当前用户生效：
若需全局生效，替换命令为 Set-ExecutionPolicy RemoteSigned（需管理员权限）4。
临时绕过策略（不推荐）：
powershell -ExecutionPolicy Bypass -File .\indows_password_policy.ps1 
💡 故障原因说明
默认策略限制：Windows 为防止恶意脚本，默认禁止运行 .ps1 文件 14。
权限要求：修改策略需管理员权限，普通用户无法操作 2。
通过以上步骤，99% 的脚本禁止问题可解决。若仍报错，请检查脚本路径是否正确 5。

以上内容均由AI搜集总结并生成，仅供参考




```