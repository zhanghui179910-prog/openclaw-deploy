#requires -RunAsAdministrator
<# 
.SYNOPSIS
    OpenClaw 离线一键安装脚本（断网 Windows 11 上运行）
.DESCRIPTION
    无需网络，从本地安装包一键部署 OpenClaw
    所有依赖已预置在 deps/ 目录中
#>

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

# 脚本所在目录
$ROOT = $PSScriptRoot
$DEPS = Join-Path $ROOT "deps"
$WORKSPACE_SRC = Join-Path $ROOT "openclaw_workspace"

function Write-OK    { param($m) Write-Host "[ OK ] $m" -ForegroundColor Green }
function Write-WARN  { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-FAIL  { param($m) Write-Host "[FAIL] $m" -ForegroundColor Red }
function Write-STEP  { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }

# ==============================
# 检查管理员权限
# ==============================
function Check-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  请以管理员身份运行！" -ForegroundColor Red
        Write-Host "  右键 PowerShell → 以管理员身份运行" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        exit 1
    }
    Write-OK "管理员权限检查通过"
}

# ==============================
# 检查离线包完整性
# ==============================
function Check-OfflinePackage {
    Write-STEP "检查离线安装包"
    
    if (-not (Test-Path $DEPS)) {
        Write-FAIL "未找到 deps 目录，请确认已正确解压离线安装包"
        Write-Host "当前目录: $ROOT"
        Get-ChildItem $ROOT | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    
    $missing = @()
    @("nodejs.msi", "python.exe", "go.msi", "git.exe") | ForEach-Object {
        if (-not (Test-Path (Join-Path $DEPS $_))) { $missing += $_ }
    }
    if ($missing.Count -gt 0) {
        Write-WARN "以下安装包缺失: $($missing -join ', ')"
    }
    
    if (Test-Path $WORKSPACE_SRC) {
        Write-OK "离线安装包完整性检查通过"
    } else {
        Write-FAIL "openclaw_workspace 目录缺失"
        exit 1
    }
}

# ==============================
# 安装 Node.js
# ==============================
function Install-NodeOffline {
    Write-STEP "安装 Node.js 20 LTS"
    
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $v = node -v
        $major = [int]($v -replace 'v(\d+)\..*','$1')
        if ($major -ge 20) {
            Write-OK "Node.js 已安装: $v，跳过"
            return
        }
    }
    
    $installer = Join-Path $DEPS "nodejs.msi"
    if (-not (Test-Path $installer)) {
        Write-FAIL "未找到 Node.js 安装包: $installer"
        exit 1
    }
    
    Write-Host "  从本地安装 Node.js..."
    $proc = Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /quiet /norestart ADDLOCAL=ALL" -Wait -PassThru
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-OK "Node.js 安装完成"
    } else {
        Write-FAIL "Node.js 安装失败，退出码: $($proc.ExitCode)"
        exit 1
    }
    
    # 刷新 PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-OK "Node.js: $(node -v)"
        Write-OK "npm: $(npm -v)"
    }
}

# ==============================
# 安装 Python
# ==============================
function Install-PythonOffline {
    Write-STEP "安装 Python 3.11"
    
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pyCmd) { $pyCmd = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($pyCmd) {
        Write-OK "Python 已安装: $(python --version 2>&1)，跳过"
        return
    }
    
    $installer = Join-Path $DEPS "python.exe"
    if (-not (Test-Path $installer)) {
        Write-FAIL "未找到 Python 安装包: $installer"
        exit 1
    }
    
    Write-Host "  从本地安装 Python..."
    $proc = Start-Process $installer -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_pip=1" -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        Write-OK "Python 安装完成"
    } else {
        Write-FAIL "Python 安装失败，退出码: $($proc.ExitCode)"
        exit 1
    }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-OK "Python: $(python --version 2>&1)"
    }
}

# ==============================
# 安装 Go
# ==============================
function Install-GoOffline {
    Write-STEP "安装 Go 1.21"
    
    $goCmd = Get-Command go -ErrorAction SilentlyContinue
    if ($goCmd) {
        Write-OK "Go 已安装: $(go version)，跳过"
        return
    }
    
    $installer = Join-Path $DEPS "go.msi"
    if (-not (Test-Path $installer)) {
        Write-FAIL "未找到 Go 安装包: $installer"
        exit 1
    }
    
    Write-Host "  从本地安装 Go..."
    $proc = Start-Process msiexec.exe -ArgumentList "/i `"$installer`" /quiet /norestart" -Wait -PassThru
    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Write-OK "Go 安装完成"
    } else {
        Write-FAIL "Go 安装失败，退出码: $($proc.ExitCode)"
        exit 1
    }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-OK "Go: $(go version)"
    }
}

# ==============================
# 安装 Git
# ==============================
function Install-GitOffline {
    Write-STEP "安装 Git"
    
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-OK "Git 已安装: $(git --version)，跳过"
        return
    }
    
    $installer = Join-Path $DEPS "git.exe"
    if (-not (Test-Path $installer)) {
        Write-WARN "未找到 Git 安装包，跳过"
        return
    }
    
    Write-Host "  从本地安装 Git..."
    $proc = Start-Process $installer -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        Write-OK "Git 安装完成"
    } else {
        Write-WARN "Git 安装可能失败，但不影响核心功能"
    }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ==============================
# 部署工作空间
# ==============================
function Deploy-Workspace {
    Write-STEP "部署 OpenClaw 工作空间"
    
    $targetWorkspace = Join-Path $ROOT "..\openclaw_workspace"
    $targetWorkspace = Join-Path $PSScriptRoot "openclaw_workspace"
    
    if (Test-Path $targetWorkspace) {
        Write-WARN "目标工作空间已存在，备份后覆盖..."
        Remove-Item $targetWorkspace -Recurse -Force
    }
    
    Write-Host "  复制预构建的工作空间..."
    Copy-Item $WORKSPACE_SRC $targetWorkspace -Recurse -Force
    Write-OK "工作空间部署完成: $targetWorkspace"
    
    if (-not (Test-Path (Join-Path $targetWorkspace "node_modules"))) {
        Write-WARN "node_modules 不存在，尝试安装..."
        Set-Location $targetWorkspace
        npm install --legacy-peer-deps
        Write-OK "npm 依赖安装完成"
    } else {
        Write-OK "node_modules 已就绪，跳过 npm install"
    }
}

# ==============================
# 配置环境
# ==============================
function Setup-EnvFile {
    Write-STEP "配置环境文件"
    
    $envFile = Join-Path $ROOT ".env"
    $template = Join-Path $ROOT ".env.template"
    
    if (-not (Test-Path $envFile) -or (Get-Item $envFile).Length -eq 0) {
        if (Test-Path $template) {
            Copy-Item $template $envFile
        }
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "  请用记事本打开 .env 填入 API Key" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-OK "已生成 .env 文件"
        Write-Host "  编辑命令: notepad `"$envFile`"" -ForegroundColor Cyan
    } else {
        Write-OK ".env 文件已存在"
    }
}

# ==============================
# 安装 OpenClaw CLI
# ==============================
function Install-OpenClawOffline {
    Write-STEP "安装 OpenClaw CLI"
    
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        Write-OK "OpenClaw CLI 已安装，跳过"
        return
    }
    
    # 尝试从预构建的 node_modules 中创建链接
    $workspace = Join-Path $ROOT "openclaw_workspace"
    $localOpenclaw = Join-Path $workspace "node_modules\.bin\openclaw.cmd"
    
    if (Test-Path $localOpenclaw) {
        Write-Host "  从本地 node_modules 安装..."
        # 直接安装全局 CLI（npm 会使用本地缓存）
        $oldLoc = Get-Location
        Set-Location $workspace
        npm link 2>$null
        Set-Location $oldLoc
        if (Get-Command openclaw -ErrorAction SilentlyContinue) {
            Write-OK "OpenClaw CLI 链接完成"
            return
        }
    }
    
    Write-Host "  从 npm 安装（使用已有包缓存）..."
    npm install -g openclaw@latest 2>$null
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        Write-OK "OpenClaw CLI 安装完成"
    } else {
        Write-WARN "OpenClaw CLI 安装失败，可稍后手动执行: npm install -g openclaw"
    }
}

# ==============================
# 创建启动脚本
# ==============================
function Create-StartScript {
    Write-STEP "创建快捷启动脚本"
    
    $startBat = @"
@echo off
chcp 65001 >nul
title OpenClaw Gateway
echo ========================================
echo   OpenClaw 网关正在启动...
echo ========================================
echo.
cd /d "%~dp0openclaw_workspace"
if not exist "%CD%" (
    echo [错误] 未找到 openclaw_workspace 目录
    pause
    exit /b 1
)
echo 工作目录: %CD%
echo 访问地址: http://localhost:8080
echo 按 Ctrl+C 可停止服务
echo.
openclaw gateway --port 8080 --verbose
pause
"@
    
    $startBatPath = Join-Path $ROOT "start.bat"
    Set-Content -Path $startBatPath -Value $startBat -Encoding UTF8
    Write-OK "快捷启动脚本已创建: start.bat"
}

# ==============================
# 主流程
# ==============================
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  OpenClaw 离线一键安装 (Windows 11)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Check-Admin
    Check-OfflinePackage
    Install-NodeOffline
    Install-PythonOffline
    Install-GoOffline
    Install-GitOffline
    
    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Deploy-Workspace
    Setup-EnvFile
    Install-OpenClawOffline
    Create-StartScript

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  离线部署完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "下一步:" -ForegroundColor Cyan
    Write-Host "  1. 配置 API Key: notepad .env" -ForegroundColor White
    Write-Host "  2. 启动服务: 双击 start.bat" -ForegroundColor White
    Write-Host "  3. 访问: http://localhost:8080" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
}

Main