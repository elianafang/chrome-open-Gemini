param([string]$Action = "on")

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Repo = "fxw-labs/glic-switch"
$BinDir = Join-Path $env:LOCALAPPDATA "Programs\glic-switch"
$Bin = Join-Path $BinDir "glic-switch.exe"

function Step($t) { Write-Host ""; Write-Host "==> $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host $t -ForegroundColor Green }
function Warn($t) { Write-Host $t -ForegroundColor Yellow }
function Err($t)  { Write-Host $t -ForegroundColor Red }

function Get-Proxy {
    try {
        $k = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        if ($k.ProxyEnable -eq 1 -and $k.ProxyServer) {
            $s = [string]$k.ProxyServer
            if ($s -match "https=([^;]+)") { return "http://$($Matches[1])" }
            if ($s -match "http=([^;]+)")  { return "http://$($Matches[1])" }
            if ($s -notmatch "=")          { return "http://$s" }
        }
    } catch {}
    return $null
}

$Proxy = Get-Proxy

function Invoke-Curl {
    param([string[]]$CurlArgs)
    $a = @("-s", "-m", "12")
    if ($Proxy) { $a += @("-x", $Proxy) }
    $a += $CurlArgs
    & curl.exe @a
}

function Find-Chrome {
    $paths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $p } }
    return $null
}

function Install-Tool {
    Step "安装 glic-switch"
    if (Test-Path $Bin) { Ok "已安装"; return }
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
    $asset = "glic-switch_windows_$arch.zip"
    $tmp = Join-Path $env:TEMP "glic-switch-dl"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp $asset
    Write-Host "下载 $asset ..."
    $a = @("-fsSL", "-m", "120", "-o", $zip)
    if ($Proxy) { $a += @("-x", $Proxy) }
    $a += "https://github.com/$Repo/releases/latest/download/$asset"
    & curl.exe @a
    if ($LASTEXITCODE -ne 0) {
        throw "下载失败。请确认代理已开启,或手动从 https://github.com/$Repo/releases 下载。"
    }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    $exe = Get-ChildItem $tmp -Filter "glic-switch.exe" -Recurse | Select-Object -First 1
    if (-not $exe) { throw "压缩包里没有找到 glic-switch.exe" }
    Copy-Item $exe.FullName $Bin -Force
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Ok "已安装到 $Bin"
}

function Check-Env {
    Step "检查环境"
    $chrome = Find-Chrome
    if (-not $chrome) { throw "没有找到 Google Chrome,请先安装。" }
    $ver = (Get-Item $chrome).VersionInfo.ProductVersion
    Write-Host "Chrome 版本: $ver"
    $major = [int]($ver.Split(".")[0])
    if ($major -lt 147) { throw "Chrome 版本需要 147 及以上,请先升级。" }
    if ($Proxy) { Write-Host "检测到系统代理: $Proxy" }
    else { Warn "没有检测到系统代理。如果你在中国大陆,请先打开代理软件的“系统代理”。" }
}

function Check-Node {
    Step "检查代理节点"
    $raw = Invoke-Curl @("https://api.country.is")
    $country = if ($raw -match '"country":"([A-Z]+)"') { $Matches[1] } else { $null }
    if (-not $country) { throw "无法获取出口地区,请检查网络和代理是否正常。" }
    Write-Host "出口地区: $country"
    if ($country -eq "CN" -or $country -eq "HK") {
        throw "出口在 $country,Gemini 不可用。请换成美国节点。"
    }
    $out = Invoke-Curl @("-o", "NUL", "-w", "%{http_code} %{redirect_url}", "https://gemini.google.com/app")
    $parts = ([string]$out).Trim().Split(" ", 2)
    $code = $parts[0]
    $redirect = if ($parts.Length -gt 1) { $parts[1] } else { "" }
    if ($redirect -like "*google.com/sorry*") {
        throw "这个节点的 IP 被 Google 风控(跳转到验证页)。不是地区问题,是这个 IP 被标记了。请换一个节点(优先美国),再重新运行。"
    }
    if ($code -eq "200") { Ok "gemini.google.com 可以正常访问" }
    else { Warn "gemini.google.com 返回 $code,可能不稳定,仍然继续。" }
}

function Confirm-Restart {
    if (Get-Process chrome -ErrorAction SilentlyContinue) {
        Write-Host ""
        Warn "Chrome 正在运行,继续会关闭并重启它。请先保存好网页里未提交的内容。"
        $ans = Read-Host "继续吗? [y/N]"
        if ($ans -notmatch "^(y|yes)$") { Write-Host "已取消。"; exit 0 }
    }
}

try {
    switch ($Action) {
        "on" {
            Check-Env
            Install-Tool
            Check-Node
            Confirm-Restart
            Step "开启 Gemini"
            & $Bin on
            Start-Sleep -Seconds 4
            Step "最终状态"
            & $Bin status
            Write-Host ""
            Ok "完成。请在 Chrome 右上角找 Gemini 图标。"
            Write-Host "以后要用 Gemini,请运行本脚本启动 Chrome,不要直接点桌面图标,否则配置会被重置。"
        }
        "off"    { Install-Tool; Confirm-Restart; & $Bin off }
        "status" { Install-Tool; & $Bin status }
        "check"  { Check-Env; Check-Node }
        default  { Write-Host "用法: gemini-on.ps1 [on|off|status|check]" }
    }
} catch {
    Err $_.Exception.Message
    exit 1
}
