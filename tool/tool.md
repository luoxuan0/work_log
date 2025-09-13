## 自动化运维

### 网络

#### 20250830

- https://ip111.cn/
	- 从国内测试
	- 从国外测试
	- 从谷歌测试

```txt
20250627

复盘（状态识别，调整）

创造开拓性内容（还可以继续定义），确定性的进行自动化（这里可稍微放长时间观察哪些累计比较庞大，可以先切入，这里要放长到什么程度，或者还有空间的维度？）

	比如，操作维护记录文档，报告（日报，周报，云效）

	还有一些流程操作（分割任务，日志，报错，异常处理保健壮性，函数封装）

	其他日常操作（授权，数据库操作，以及？）
		阿里云资源或其他三方资源创建（通过api读取现有配置，再通过api创建修改删除等）


--current-point--
```

#### 网站

网站测速|网站速度测试|网速测试|电信|联通|网通|全国|监控|CDN|PING|DNS 一起测试|17CE.COM: https://www.17ce.com/

### windows

#### Excel 表格

```txt

D51的数据在$L$51:$L$2664查找，如果不存在则为0，存在则为对应单元格的INDEX值
=IFNA(MATCH(D51,$L$51:$L$2664,0),0)
快速复制公式的方法：
	鼠标拖拽法：

		选中包含公式的单元格

		将鼠标移到单元格右下角的小方块（填充柄）上，光标会变成黑色十字

		按住左键向下拖动到需要的行数

	双击填充柄法（最快方法）：

		选中包含公式的单元格

		双击单元格右下角的小方块（填充柄）

		公式会自动向下填充到相邻列有数据的最后一行

	快捷键法：

		选中包含公式的单元格

		按Ctrl+C复制

		选中要粘贴的区域

		按Ctrl+V粘贴
引用说明：
	A2是相对引用，向下复制时会自动变成A3、A4等

	$Q$2:$Q$229是绝对引用（有$符号），向下复制时不会改变

存在则为“TP”，不存在则为“非TP”
=IF(ISNUMBER(MATCH(A2,$Q$2:$Q$229,0)), "TP", "非TP")

```

#### 批量启动程序（bat脚本）

```bat
::open some software
@echo off
start "title" "C:\Windows\system32\cmd.exe"
start "title" "C:\Windows\system32\cmd.exe"
start "title" "C:\Windows\system32\cmd.exe"
start "title" "C:\Windows\system32\cmd.exe"
start "title" "E:\svn"
start "title" "E:\work\daily"
start "title" "F:\BaiduNetdiskDownload\trackingmore\luoxuan01\daily"
start "title" "E:\work\project"
rem 设置编码，防止中文路径乱码 无法执行
chcp 65001
start "title" "E:\work\project\复盘.xmind"
start "title" "E:\work\project\时间.xmind"
start "title" "E:\work\project\时空.xmind"
start "title" "E:\work\project\project.xmind"
start "title" "E:\work\project\project\代码发布.xmind"

start "title" "D:\xampp\htdocs\trackingmore\trunk"
start "title" "D:\xampp\htdocs\trackingmore\trunknk_git"
start "title" "F:\钉钉"

:: goto 标签 注释多行
:: :标签
goto xxxx
:: 20230708 远程linux全部使用bastion 堡垒机
::start "title" "E:\SecureCRSecureFXPortable - copy1\SecureCRSecureFXPortable - copy\App\VanDyke Clients\SecureCRT.exe" /SESSION_FOLDER "mycat-F-new" /SESSION_FOLDER "mycat-H-new-1" 
start "title" "D:\Program Files\VanDyke Software\Clients\SecureCRT.exe" /SESSION_FOLDER "mycat-F-new" /SESSION_FOLDER "mycat-H-new-1"
::start "title" "E:\SecureCRSecureFXPortable - copy1\SecureCRSecureFXPortable - copy\App\VanDyke Clients\SecureCRT.exe" /SESSION_FOLDER "mycat-F-new" /SESSION_FOLDER "mycat-H-new-1" 
timeout /T 2 /NOBREAK
start "title" "D:\Program Files\VanDyke Software\Clients\SecureCRT.exe" /SESSION_FOLDER "国内-深圳-ecs"
timeout /T 1 /NOBREAK
::start "title" "E:\SecureCRSecureFXPortable - copy1\SecureCRSecureFXPortable - copy\App\VanDyke Clients\SecureCRT.exe" /SESSION_FOLDER "国内-new-H"
start "title" "D:\Program Files\VanDyke Software\Clients\SecureCRT.exe" /SESSION_FOLDER "国内-new-H" /SESSION_FOLDER "国外-new"
:: 20230708 远程linux全部使用bastion 堡垒机
:xxxx

start "title" "C:\Users\admin\Desktop\HostEditor\HostEditor\HostEditor.exe"
rem "title" "C:\Users\admin\Desktop\HostEditor\HostEditor\HostEditor.exe"


start "title" "D:\program\YoudaoNote\RunYNote.exe"
start "title" "D:\program\Sublime Text Build 3109\sublime_text.exe"
start "title" "D:\program\Sublime Text\sublime_text.exe"
start "title" "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
start "title" "D:\program\firefox56\firefox.exe"

start "title" "C:\Program Files (x86)\Tencent\QQ\Bin\QQScLauncher.exe"

:: 启动utools
start "title" "C:\Users\admin\AppData\Local\Programs\utools\uTools.exe"

:: 启动vscode
:: start "title" "C:\Users\admin\AppData\Local\Programs\Microsoft VS Code\Code.exe"



start "title" "D:\program\DingDing\main\current_new\DingTalk.exe"

```

#### windows的CPU性能确认

你问的是 **i5-10400** 能用的同一主板插槽 CPU。
我们可以从 **名字（型号）** 里大致判断插槽兼容性。

---

##### ✅ i5-10400 基本信息

* **代号**：Comet Lake
* **接口**：LGA1200
* **芯片组支持**：Intel 400 系列（H410/B460/H470/Z490）和 500 系列（B560/H510/Z590，部分需要 BIOS 升级）。

---

##### 🔄 能用同样插槽的 CPU（LGA1200）

从命名上你能看出来：

1. **第 10 代 Comet Lake (Core i3/i5/i7/i9 10xxx 系列)**

   * i3-10100/10300/10320
   * i5-10400/10500/10600/K/F
   * i7-10700/K/F
   * i9-10850K、10900/K/F
     （这些全部兼容 LGA1200，直接可用）

2. **第 11 代 Rocket Lake (Core i5/i7/i9 11xxx 系列)**

   * i5-11400/11500/11600/K/F
   * i7-11700/K/F
   * i9-11900/K/F
     （同样是 LGA1200，需要 500 系主板，部分 400 系需要更新 BIOS 才能支持）

---

##### ❌ 不兼容的（不同插槽）

* 第 12 代 (Alder Lake) 及之后 → **LGA1700**，名字以 12xxx/13xxx/14xxx 开头，不兼容。
* 第 8/9 代 → **LGA1151**，名字以 8xxx/9xxx 开头，不兼容。

---

##### 📌 从名字判断的方法

* **10xxx / 11xxx** → LGA1200（兼容 i5-10400 主板）
* **12xxx 及以上** → LGA1700（不兼容）
* **9xxx 及以下** → LGA1151 或更老（不兼容）

---

要不要我帮你整理一份 **LGA1200 全部可用 CPU 清单（10 代 + 11 代，按 i3/i5/i7/i9 分类）**，方便你直接对照？

