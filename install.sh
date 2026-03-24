#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[⚠] $1${NC}"; }
log_error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_warn "需要 sudo 权限，将提示输入密码..."
    fi
}

configure_apt_mirror() {
    log_info "配置阿里云镜像源..."
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
    sudo bash -c 'cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF'
    log_info "镜像源配置完成"
}

update_system() {
    log_info "更新软件包列表..."
    sudo apt-get update -qq
    log_info "安装系统基础依赖..."
    sudo apt-get install -y -qq curl wget git build-essential procps python3 python3-pip unzip
}

check_go() {
    if ! command -v go &> /dev/null; then
        log_warn "Go 未安装，正在安装 Go 1.21..."
        local go_version="go1.21.6.linux-amd64"
        local go_tarball="${go_version}.tar.gz"
        cd /tmp
        curl -fsSL "https://golang.google.cn/dl/${go_tarball}" -o "${go_tarball}"
        sudo tar -C /usr/local -xzf "${go_tarball}"
        sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
        sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
        rm -f "${go_tarball}"
        echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile > /dev/null
        export PATH="$PATH:/usr/local/go/bin"
        log_info "Go 安装完成: $(go version)"
    else
        log_info "Go 已安装: $(go version)"
    fi
}

check_node() {
    if ! command -v node &> /dev/null; then
        log_warn "Node.js 未安装，正在安装 Node.js 20..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y -qq nodejs
        log_info "Node.js 安装完成: $(node --version)"
    else
        log_info "Node.js 已安装: $(node --version)"
    fi

    if ! command -v npm &> /dev/null; then
        log_warn "npm 未找到，正在安装..."
        sudo apt-get install -y -qq npm
    fi
    log_info "npm 已就绪: $(npm --version)"
}

install_python_deps() {
    log_info "安装 Python 依赖..."
    pip3 install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple openai python-dotenv requests
    log_info "Python 依赖安装完成"
}

create_workspace() {
    if [ ! -d "openclaw_workspace" ]; then
        mkdir -p openclaw_workspace
        log_info "工作目录 openclaw_workspace 创建完成"
    else
        log_info "工作目录 openclaw_workspace 已存在"
    fi
}

check_and_clone_openclaw_source() {
    local workspace_count=$(ls -A openclaw_workspace 2>/dev/null | wc -l)

    if [ "$workspace_count" -eq 0 ]; then
        log_warn "openclaw_workspace 目录为空，正在克隆 OpenClaw 源码..."
        git clone https://github.com/openclaw/openclaw.git openclaw_workspace
        log_info "OpenClaw 源码克隆完成"
    else
        log_info "openclaw_workspace 目录非空，跳过克隆"
        return 0
    fi

    if [ -d "openclaw_workspace/openclaw" ]; then
        log_warn "检测到嵌套目录，正在整理文件结构..."
        mv openclaw_workspace/openclaw/* openclaw_workspace/
        rmdir openclaw_workspace/openclaw
        log_info "文件结构已整理完成"
    fi

    if [ -f "openclaw_workspace/package.json" ]; then
        log_info "package.json 已就绪，正在安装 npm 依赖..."
        cd openclaw_workspace
        npm install
        log_info "npm 依赖安装完成"
    else
        log_warn "未找到 package.json，请检查源码"
    fi
}

check_env_file() {
    if [ ! -f ".env" ] || [ ! -s ".env" ]; then
        if [ ! -f ".env.template" ]; then
            log_error ".env.template 文件不存在"
        fi
        cp .env.template .env
        echo ""
        log_warn "=========================================="
        log_warn "  环境初始化完成！"
        log_warn "  请修改 .env 文件填入 API Key 后，"
        log_warn "  再次运行此脚本启动！"
        log_warn "=========================================="
        echo ""
        log_info "已从 .env.template 生成 .env 文件"
        log_info "请运行: nano .env  # 填入 API Key"
        log_info "然后再次运行: ./install.sh"
        exit 0
    else
        log_info ".env 文件检查通过"
    fi
}

install_openclaw_cli() {
    if ! command -v openclaw &> /dev/null; then
        log_warn "正在全局安装 OpenClaw CLI..."
        sudo npm install -g openclaw@latest
        log_info "OpenClaw CLI 安装完成"
    else
        log_info "OpenClaw CLI 已安装: $(openclaw --version 2>/dev/null || echo 'version unknown')"
    fi
}

start_services() {
    install_openclaw_cli

    echo ""
    log_warn "=========================================="
    log_warn "  部署完成！"
    log_warn "=========================================="
    echo ""
    log_info "启动 OpenClaw 网关（前台运行）:"
    log_info "  cd openclaw_workspace"
    log_info "  openclaw gateway --port 8080 --verbose"
    echo ""
    log_info "详细文档请查看 README.md"
    log_info "=========================================="
}

main() {
    echo ""
    log_info "========== OpenClaw 一键部署脚本 =========="
    echo ""
    check_sudo
    configure_apt_mirror
    update_system
    check_go
    check_node
    install_python_deps
    create_workspace
    check_and_clone_openclaw_source
    check_env_file
    start_services
}

main "$@"