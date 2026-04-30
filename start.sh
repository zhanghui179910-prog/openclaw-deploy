#!/bin/bash

cd "$(dirname "$0")"

if [ ! -d "openclaw_workspace" ]; then
    echo "[错误] 未找到 openclaw_workspace 目录"
    echo "请先运行 ./install.sh 完成部署"
    exit 1
fi

echo "========================================"
echo "  OpenClaw 网关正在启动..."
echo "========================================"
echo ""
echo "工作目录: $(pwd)/openclaw_workspace"
echo ""
echo "访问地址: http://localhost:8080"
echo "按 Ctrl+C 可停止服务"
echo ""

cd openclaw_workspace
openclaw gateway --port 8080 --verbose