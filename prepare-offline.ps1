<# 
.SYNOPSIS
    OpenClaw 离线包准备脚本（在有网的 Windows 上运行）
.DESCRIPTION
    自动下载所有依赖并打包成离线安装包，拷贝到断网 Windows 11 后一键安装
#>

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$PACKAGE_DIR = Join-Path $PSScriptRoot "offline-package"
$DEPS_DIR = Join-Path $PACKAGE_DIR "deps"
$WORKSPACE_DIR_IN_PKG = Join-Path $PACKAGE_DIR "openclaw_workspace"

# 下载链接（国内镜像优先）
$DOWNLOADS = @{
    "nodejs.msi"   = "https://npmmirror.com/mirrors/node/v20.18.0/node-v20.18.0-x64.msi"
    "python.exe"   = "https://npmmirror.com/mirrors/python/3.11.9/python-3.11.9-amd64.exe"
    "go.msi"       = "https://golang.google.cn/dl/go1.21.6.windows-amd64.msi"
    "git.exe"      = "https://mirrors.huaweicloud.com/git-for-windows/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
}

# 备用下载链接
$FALLBACKS = @{
    "nodejs.msi"   = "https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi"
    "python.exe"   = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
    "go.msi"       = "https://go.dev/dl/go1.21.6.windows-amd64.msi"
    "git.exe"      = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
}

function Write-OK    { param($m) Write-Host "[ OK ] $m" -ForegroundColor Green }
function Write-WARN  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-FAIL  { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }
function Write-STEP  { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }

function Download-File {
    param($Url, $DestPath)
    try {
        Write-Host "  下载: $(Split-Path $Url -Leaf)"
        $progressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $DestPath -UseBasicParsing -TimeoutSec 600
        if ((Get-Item $DestPath).Length -gt 1048576) {
            Write-OK "  完成: $(Split-Path $Url -Leaf) ($([math]::Round((Get-Item $DestPath).Length/1MB, 1)) MB)"
            return $true
        } else {
            Write-FAIL "  文件异常，大小不足 1MB"
            return $false
        }
    } catch {
        Write-FAIL "  下载失败: $_"
        return $false
    }
}

# ==== 第 1 步：清理并创建目录 ====
Write-STEP "第 1 步：准备打包目录"
if (Test-Path $PACKAGE_DIR) { Remove-Item $PACKAGE_DIR -Recurse -Force }
New-Item -ItemType Directory -Path $DEPS_DIR -Force | Out-Null
Write-OK "打包目录已就绪: $PACKAGE_DIR"

# ==== 第 2 步：下载安装包 ====
Write-STEP "第 2 步：下载运行环境安装包"
foreach ($entry in $DOWNLOADS.GetEnumerator()) {
    $dest = Join-Path $DEPS_DIR $entry.Key
    $success = Download-File $entry.Value $dest
    if (-not $success -and $FALLBACKS.ContainsKey($entry.Key)) {
        Write-WARN "  切换到备用下载链接..."
        Download-File $FALLBACKS[$entry.Key] $dest
    }
}

# ==== 第 3 步：克隆 OpenClaw 源码 ====
Write-STEP "第 3 步：克隆 OpenClaw 源码"
if (Test-Path $WORKSPACE_DIR_IN_PKG) { Remove-Item $WORKSPACE_DIR_IN_PKG -Recurse -Force }
try {
    git clone https://github.com/openclaw/openclaw.git $WORKSPACE_DIR_IN_PKG
    Write-OK "源码克隆完成"
} catch {
    Write-FAIL "克隆失败，请检查网络: $_"
    exit 1
}

if (Test-Path (Join-Path $WORKSPACE_DIR_IN_PKG "openclaw")) {
    Write-WARN "整理嵌套目录..."
    Get-ChildItem (Join-Path $WORKSPACE_DIR_IN_PKG "openclaw") | Move-Item -Destination $WORKSPACE_DIR_IN_PKG -Force
    Remove-Item (Join-Path $WORKSPACE_DIR_IN_PKG "openclaw") -Recurse -Force
}

# ==== 第 4 步：预安装 Node 依赖 ====
Write-STEP "第 4 步：预安装 npm 依赖"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $oldLoc = Get-Location
    Set-Location $WORKSPACE_DIR_IN_PKG
    npm install --legacy-peer-deps
    Set-Location $oldLoc
    Write-OK "npm 依赖预安装完成"
} else {
    Write-WARN "未检测到 npm，跳过依赖预安装"
    Write-WARN "离线安装时将在目标机器上从 node_modules 安装"
}

# ==== 第 5 步：复制部署文件到打包目录 ====
Write-STEP "第 5 步：复制部署脚本和配置文件"
Copy-Item (Join-Path $PSScriptRoot "install-offline.ps1") $PACKAGE_DIR -ErrorAction SilentlyContinue
Copy-Item (Join-Path $PSScriptRoot ".env.template") $PACKAGE_DIR
Copy-Item (Join-Path $PSScriptRoot "start.bat") $PACKAGE_DIR
Write-OK "部署文件复制完成"

# ==== 第 6 步：打包 ====
Write-STEP "第 6 步：压缩为离线安装包"
$zipName = "openclaw-offline.zip"
$zipPath = Join-Path $PSScriptRoot $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $PACKAGE_DIR -DestinationPath $zipPath -Force
$zipSize = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-OK "离线包已生成: $zipPath ($zipSize MB)"

# ==== 完成 ====
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  离线包准备完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "文件位置: $zipPath ($zipSize MB)" -ForegroundColor Yellow
Write-Host ""
Write-Host "--- 在断网 Windows 11 上的操作 ---" -ForegroundColor Cyan
Write-Host "1. 拷贝 $zipName 到目标机器"
Write-Host "2. 解压到任意目录"
Write-Host "3. 右键 PowerShell → 以管理员身份运行"
Write-Host "4. cd 解压目录"
Write-Host "5. .\install-offline.ps1"
Write-Host ""
Write-Host "========================================" -ForegroundColor Green

# 清理临时目录
Remove-Item $PACKAGE_DIR -Recurse -Force
Write-OK "临时文件已清理"