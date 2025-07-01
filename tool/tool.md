## 网站

网站测速|网站速度测试|网速测试|电信|联通|网通|全国|监控|CDN|PING|DNS 一起测试|17CE.COM: https://www.17ce.com/

### Excel 表格

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

### 批量启动程序（bat脚本）

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


