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
    echo 请先运行 install.ps1 完成部署
    pause
    exit /b 1
)
echo 工作目录: %CD%
echo.
echo 访问地址: http://localhost:8080
echo 按 Ctrl+C 可停止服务
echo.
openclaw gateway --port 8080 --verbose
pause