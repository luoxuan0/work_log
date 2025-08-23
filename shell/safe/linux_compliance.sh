param(
  [switch]$Preview,
  [switch]$Apply,
  [switch]$Rollback,
  [switch]$Verify,
  [string]$BackupPath
)

$ErrorActionPreference = 'Stop'
$Log = "C:\Windows\Temp\compliance_fix.log"
function Log($m){ ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ssK"), $m) | Tee-Object -FilePath $Log -Append }
function Run($cmd){ Log "+ $cmd"; $out = cmd.exe /c $cmd 2>&1; $out | Tee-Object -FilePath $Log -Append | Out-String | Out-Null }
function Ensure-Dir($p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Path $p | Out-Null } }

$ts = Get-Date -Format "yyyyMMddHHmmss"
$bkRoot = "C:\Backups"
$bkDir = Join-Path $bkRoot ("SecBaseline_{0}" -f $ts)
$infApply = Join-Path $env:TEMP ("apply_{0}.inf" -f $ts)
$infCur = Join-Path $env:TEMP ("current_{0}.inf" -f $ts)

function Export-CurrentPolicy($dest){ Run "secedit /export /cfg `"$dest`" /quiet" }

function Preview-Changes(){
  Log "仅预览，不落盘"
  Export-CurrentPolicy $infCur
  $cur = Get-Content $infCur -Raw
  $target = @"
[System Access]
; 合规需要整改-启用密码复杂性-$(Get-Date -Format yyyyMMdd)
PasswordComplexity = 1
"@
  $tmp = Join-Path $env:TEMP ("preview_{0}.inf" -f $ts)
  Set-Content -Path $tmp -Encoding ASCII -Value ($cur + "`r`n" + $target)
  Log "=== 预览差异（关键项）==="
  $before = ($cur -split "`r?`n") | Where-Object { $_ -match '^\s*PasswordComplexity\s*=' }
  $after  = (Get-Content $tmp)     | Where-Object { $_ -match '^\s*PasswordComplexity\s*=' }
  Log ("Before: {0}" -f ($before -join ' '))
  Log ("After : {0}" -f ($after -join ' '))
  Remove-Item $tmp -Force
}

function Apply-Changes(){
  Ensure-Dir $bkDir
  Log "导出当前基线到 $bkDir\baseline.inf"
  Export-CurrentPolicy (Join-Path $bkDir "baseline.inf")

  $append = @"
[System Access]
; 合规需要整改-启用密码复杂性-$(Get-Date -Format yyyyMMdd)
PasswordComplexity = 1
"@
  Export-CurrentPolicy $infCur
  Set-Content -Path $infApply -Encoding ASCII -Value ( (Get-Content $infCur -Raw) + "`r`n" + $append )

  Run "secedit /configure /db `"%SystemRoot%\Security\Database\secedit.sdb`" /cfg `"$infApply`" /quiet"
  Run "gpupdate /target:computer /force"
  Log "应用完成。备份目录：$bkDir"

  Verify-Policy
}

function Verify-Policy(){
  Log "开始验证：密码复杂性策略"
  $user = "comp_pw_test_$ts"
  $weak = "abc12345"
  $strong = "Abcdef12!@13435df"

  # 创建本地用户（先尝试 net user，若失败再用 New-LocalUser）
  try {
    Run "net user $user $weak /add"
    Log "注意：弱口令下直接创建成功，可能策略未生效；继续尝试用强口令修改以判定。"
  } catch {
    Log "弱口令创建用户失败（预期行为，策略可能已启用）：$($_.Exception.Message)"
    # 尝试使用强口令创建
    try {
      Run "net user $user $strong /add"
      Log "使用强口令创建用户成功（预期行为）。"
    } catch {
      # 再尝试 PowerShell 接口
      try {
        $sp = ConvertTo-SecureString $strong -AsPlainText -Force
        New-LocalUser -Name $user -Password $sp -ErrorAction Stop | Out-Null
        Log "使用强口令创建用户成功（PowerShell 接口）。"
      } catch {
        Log "❌ 无法以强口令创建用户，策略或权限异常：$($_.Exception.Message)"
        throw
      }
    }
  }

  # 如果用户已用弱口令创建成功，尝试将密码改为弱口令应当失败、改为强口令应当成功
  try {
    Run "net user $user $weak"
    Log "❌ 弱口令被接受（策略未生效或未应用到本机）。"
  } catch {
    Log "✅ 弱口令被拒绝，符合预期。"
  }

  try {
    Run "net user $user $strong"
    Log "✅ 强口令被接受，符合预期。"
  } catch {
    Log "❌ 强口令未被接受（策略过严或异常）。"
  }

  # 清理
  try { Run "net user $user /delete" } catch { try { Remove-LocalUser -Name $user -ErrorAction Stop } catch {} }
  Log "验证完成。"
}

function Rollback-Changes($bk){
  if(-not (Test-Path $bk)){ throw "备份不存在：$bk" }
  $inf = Join-Path $bk "baseline.inf"
  if(-not (Test-Path $inf)){ throw "未发现 baseline.inf：$inf" }
  Run "secedit /configure /db `"%SystemRoot%\Security\Database\secedit.sdb`" /cfg `"$inf`" /quiet"
  Run "gpupdate /target:computer /force"
  Log "已回滚至：$bk"
}

try{
  if($Preview){ Preview-Changes; exit 0 }
  elseif($Apply){ Apply-Changes; exit 0 }
  elseif($Rollback){ if(-not $BackupPath){ throw "请提供 -BackupPath" }; Rollback-Changes $BackupPath; exit 0 }
  elseif($Verify){ Verify-Policy; exit 0 }
  else {
    Write-Host "用法："
    Write-Host "  预览：   .\windows_password_policy.ps1 -Preview"
    Write-Host "  应用：   .\windows_password_policy.ps1 -Apply"
    Write-Host "  验证：   .\windows_password_policy.ps1 -Verify"
    Write-Host "  回滚：   .\windows_password_policy.ps1 -Rollback -BackupPath C:\Backups\SecBaseline_YYYYmmddHHMMSS"
    exit 1
  }
} catch {
  Log "异常：$($_.Exception.Message)"
  exit 2
} finally {
  foreach($f in @($infApply,$infCur)){ if(Test-Path $f){ Remove-Item $f -Force } }
}
