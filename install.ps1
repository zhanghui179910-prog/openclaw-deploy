#requires -RunAsAdministrator
<#
.SYNOPSIS
    OpenClaw Windows 一键安装脚本
.DESCRIPTION
    自动检测并安装 Node.js、Python、Go、Git 等依赖环境
    支持 Windows 10/11 系统，PowerShell 5.1+
.AUTHOR
    OpenClaw Deploy Team
#>

# 设置编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# 颜色定义
function Write-Info    { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Error   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }
function Write-Step    { param($msg) Write-Host ">>> $msg" -ForegroundColor Cyan }

# 检查管理员权限
function Check-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "请以管理员身份运行此脚本！右键点击 PowerShell，选择'以管理员身份运行'"
    }
    Write-Info "管理员权限检查通过"
}

# 检查操作系统版本
function Check-OS {
    $osVersion = [System.Environment]::OSVersion.Version
    $major = $osVersion.Major
    
    if ($major -lt 10) {
        Write-Warn "检测到 Windows 版本较低，推荐 Windows 10 或 11"
        Write-Warn "当前版本: $($osVersion.ToString())"
        $continue = Read-Host "是否继续安装？(Y/N)"
        if ($continue -ne 'Y' -and $continue -ne 'y') { exit }
    } else {
        Write-Info "操作系统版本: Windows $major (兼容)"
    }
    
    # 检查系统架构
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -ne 'AMD64' -and $arch -ne 'ARM64') {
        Write-Warn "非标准架构: $arch，可能存在兼容性问题"
    }
}

# 检查并安装 Chocolatey 包管理器
function Install-Choco {
    Write-Step "检查 Chocolatey 包管理器..."
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Info "Chocolatey 已安装: $(choco --version)"
        return
    }
    
    Write-Warn "Chocolatey 未安装，正在安装..."
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Write-Info "Chocolatey 安装完成"
    } catch {
        Write-Warn "Chocolatey 官方安装失败，尝试使用备用安装方法..."
        Write-Error "请手动安装 Chocolatey: https://chocolatey.org/install"
    }
}

# 检查并安装 Node.js
function Install-Node {
    Write-Step "检查 Node.js 环境..."
    
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVersion = node -v
        $major = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
        if ($major -ge 20) {
            Write-Info "Node.js 已安装: $nodeVersion"
            return
        } else {
            Write-Warn "Node.js 版本过低 ($nodeVersion)，需要 20+"
        }
    }
    
    Write-Warn "正在安装 Node.js 20 LTS..."
    try {
        choco install nodejs-lts -y --limitoutput
        refreshenv
        Write-Info "Node.js 安装完成: $(node -v)"
    } catch {
        Write-Warn "Chocolatey 安装失败，尝试使用 winget..."
        try {
            winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
            refreshenv
            Write-Info "Node.js 安装完成: $(node -v)"
        } catch {
            Write-Error "Node.js 安装失败，请手动下载: https://nodejs.org/"
        }
    }
    
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Error "npm 未找到，请重新安装 Node.js"
    }
    Write-Info "npm 已就绪: $(npm -v)"
}

# 检查并安装 Python
function Install-Python {
    Write-Step "检查 Python 环境..."
    
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pyCmd) {
        $pyVersion = python --version 2>&1
        Write-Info "Python 已安装: $pyVersion"
    } else {
        Write-Warn "Python 未安装，正在安装 Python 3.11..."
        try {
            choco install python311 -y --limitoutput
            refreshenv
            Write-Info "Python 安装完成: $(python --version)"
        } catch {
            Write-Warn "Chocolatey 安装失败，尝试 winget..."
            try {
                winget install Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements
                refreshenv
                Write-Info "Python 安装完成: $(python --version)"
            } catch {
                Write-Error "Python 安装失败，请手动下载: https://www.python.org/"
            }
        }
    }
    
    # 检查 pip
    if (-not (Get-Command pip -ErrorAction SilentlyContinue) -and -not (Get-Command pip3 -ErrorAction SilentlyContinue)) {
        Write-Warn "pip 未找到，尝试安装..."
        python -m ensurepip --upgrade
    }
    
    Write-Step "安装 Python 依赖..."
    pip install openai python-dotenv requests
    Write-Info "Python 依赖安装完成"
}

# 检查并安装 Go
function Install-Go {
    Write-Step "检查 Go 语言环境..."
    
    $goCmd = Get-Command go -ErrorAction SilentlyContinue
    if ($goCmd) {
        $goVersion = go version
        Write-Info "Go 已安装: $goVersion"
        return
    }
    
    Write-Warn "Go 未安装，正在安装 Go 1.21..."
    try {
        choco install golang -y --limitoutput
        refreshenv
        Write-Info "Go 安装完成: $(go version)"
    } catch {
        Write-Warn "Chocolatey 安装失败，尝试 winget..."
        try {
            winget install GoLang.Go --silent --accept-package-agreements --accept-source-agreements
            refreshenv
            Write-Info "Go 安装完成: $(go version)"
        } catch {
            Write-Error "Go 安装失败，请手动下载: https://golang.google.cn/dl/"
        }
    }
}

# 检查并安装 Git
function Install-Git {
    Write-Step "检查 Git 环境..."
    
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-Info "Git 已安装: $(git --version)"
        return
    }
    
    Write-Warn "Git 未安装，正在安装..."
    try {
        choco install git -y --limitoutput
        refreshenv
        Write-Info "Git 安装完成: $(git --version)"
    } catch {
        Write-Warn "Chocolatey 安装失败，尝试 winget..."
        try {
            winget install Git.Git --silent --accept-package-agreements --accept-source-agreements
            refreshenv
            Write-Info "Git 安装完成: $(git --version)"
        } catch {
            Write-Error "Git 安装失败，请手动下载: https://git-scm.com/download/win"
        }
    }
}

# 创建工作目录
function Create-Workspace {
    Write-Step "创建工作目录..."
    
    $workspacePath = Join-Path $PSScriptRoot "openclaw_workspace"
    if (-not (Test-Path $workspacePath)) {
        New-Item -ItemType Directory -Path $workspacePath | Out-Null
        Write-Info "工作目录创建完成: $workspacePath"
    } else {
        Write-Info "工作目录已存在: $workspacePath"
    }
}

# 克隆 OpenClaw 源码
function Clone-OpenClaw {
    Write-Step "检查 OpenClaw 源码..."
    
    $workspacePath = Join-Path $PSScriptRoot "openclaw_workspace"
    $isEmpty = (Get-ChildItem -Path $workspacePath -Force).Count -eq 0
    
    if ($isEmpty) {
        Write-Warn "工作目录为空，正在克隆 OpenClaw 源码..."
        try {
            git clone https://github.com/openclaw/openclaw.git $workspacePath
            Write-Info "源码克隆完成"
        } catch {
            Write-Error "源码克隆失败，请检查网络连接"
        }
    } else {
        Write-Info "工作目录非空，跳过克隆"
        return
    }
    
    # 处理嵌套目录
    $nestedPath = Join-Path $workspacePath "openclaw"
    if (Test-Path $nestedPath) {
        Write-Warn "检测到嵌套目录，正在整理..."
        Get-ChildItem -Path $nestedPath | Move-Item -Destination $workspacePath -Force
        Remove-Item -Path $nestedPath -Force -Recurse
        Write-Info "目录整理完成"
    }
    
    # 安装 npm 依赖
    $packageJson = Join-Path $workspacePath "package.json"
    if (Test-Path $packageJson) {
        Write-Step "安装 npm 依赖..."
        Set-Location $workspacePath
        npm install
        Write-Info "npm 依赖安装完成"
    }
}

# 检查配置文件
function Check-EnvFile {
    Write-Step "检查配置文件..."
    
    $envFile = Join-Path $PSScriptRoot ".env"
    $templateFile = Join-Path $PSScriptRoot ".env.template"
    
    if (-not (Test-Path $envFile) -or (Get-Item $envFile).Length -eq 0) {
        if (-not (Test-Path $templateFile)) {
            Write-Error ".env.template 文件不存在"
        }
        Copy-Item $templateFile $envFile
        
        Write-Host ""
        Write-Warn "=========================================="
        Write-Warn "  环境初始化完成！"
        Write-Warn "  请用记事本打开 .env 文件填入 API Key"
        Write-Warn "  然后再次运行此脚本！"
        Write-Warn "=========================================="
        Write-Host ""
        Write-Info "已从 .env.template 生成 .env 文件"
        Write-Info "请运行: notepad .env"
        Write-Info "然后再次运行: .\install.ps1"
        exit
    }
    
    # 检查是否存在占位符
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match 'your_.*_api_key_here') {
        Write-Warn ".env 文件中存在占位符 API Key"
        Write-Warn "请确保已填入真实的 API Key"
        Write-Info "按回车继续，或关闭此窗口退出修改..."
        Read-Host
    }
    
    Write-Info ".env 文件检查通过"
}

# 安装 OpenClaw CLI
function Install-OpenClawCLI {
    Write-Step "安装 OpenClaw CLI..."
    
    $openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($openclawCmd) {
        Write-Info "OpenClaw CLI 已安装: $(openclaw --version 2>$null)"
    } else {
        Write-Warn "正在全局安装 OpenClaw CLI..."
        npm install -g openclaw@latest
        if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
            refreshenv
        }
        Write-Info "OpenClaw CLI 安装完成"
    }
}

# 创建启动脚本
function Create-StartScript {
    Write-Step "创建快捷启动脚本..."
    
    $startBat = @"
@echo off
chcp 65001 >nul
title OpenClaw Gateway
echo 正在启动 OpenClaw 网关...
cd /d "%~dp0openclaw_workspace"
openclaw gateway --port 8080 --verbose
pause
"@
    
    $startBatPath = Join-Path $PSScriptRoot "start.bat"
    if (-not (Test-Path $startBatPath)) {
        Set-Content -Path $startBatPath -Value $startBat -Encoding UTF8
        Write-Info "快捷启动脚本已创建: start.bat"
    }
    
    $startPs1 = @"
#requires -RunAsAdministrator
Write-Host "正在启动 OpenClaw 网关..." -ForegroundColor Cyan
Set-Location "$PSScriptRoot\openclaw_workspace"
openclaw gateway --port 8080 --verbose
"@
    
    $startPs1Path = Join-Path $PSScriptRoot "start.ps1"
    if (-not (Test-Path $startPs1Path)) {
        Set-Content -Path $startPs1Path -Value $startPs1 -Encoding UTF8
        Write-Info "PowerShell 启动脚本已创建: start.ps1"
    }
}

# 显示完成信息
function Show-Done {
    Write-Host ""
    Write-Warn "=========================================="
    Write-Warn "  部署完成！"
    Write-Warn "=========================================="
    Write-Host ""
    Write-Info "方式 1: 双击 start.bat 启动（推荐）"
    Write-Info "方式 2: 右键 start.ps1 选择'使用 PowerShell 运行'"
    Write-Info "方式 3: 手动启动:"
    Write-Info "  cd openclaw_workspace"
    Write-Info "  openclaw gateway --port 8080 --verbose"
    Write-Host ""
    Write-Info "访问地址: http://localhost:8080"
    Write-Info "详细文档请查看 README.md"
    Write-Warn "=========================================="
}

# 主流程
function Main {
    Write-Host ""
    Write-Info "=========================================="
    Write-Info "  OpenClaw 一键部署脚本 (Windows)"
    Write-Info "=========================================="
    Write-Host ""
    
    Check-Admin
    Check-OS
    Install-Choco
    Install-Node
    Install-Python
    Install-Go
    Install-Git
    Create-Workspace
    Clone-OpenClaw
    Check-EnvFile
    Install-OpenClawCLI
    Create-StartScript
    Show-Done
}

Main