#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[⚠] $1${NC}"; }
log_error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }
log_step() { echo -e "${BLUE}>>> $1${NC}"; }

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        UBUNTU_VERSION=$VERSION_ID
        log_info "检测到 Ubuntu $UBUNTU_VERSION"
        
        if [ "$(echo "$UBUNTU_VERSION < 20.04" | bc)" -eq 1 ] 2>/dev/null; then
            log_warn "Ubuntu $UBUNTU_VERSION 版本较旧，建议升级到 22.04+ 以获得最佳兼容性"
            log_warn "继续安装可能会遇到兼容性问题"
        fi
    else
        log_warn "无法检测操作系统版本"
    fi
}

check_sudo() {
    if command -v sudo &> /dev/null && sudo -n true 2>/dev/null; then
        log_info "sudo 权限正常"
        return 0
    elif command -v sudo &> /dev/null; then
        log_warn "需要 sudo 权限，将提示输入密码..."
        return 0
    else
        log_error "未找到 sudo，请以 root 或具有 sudo 权限的用户运行"
    fi
}

configure_apt_mirror() {
    log_step "配置国内镜像源..."
    
    if [ -f /etc/apt/sources.list ]; then
        if grep -q "mirrors.aliyun.com" /etc/apt/sources.list 2>/dev/null; then
            log_info "阿里云镜像源已配置，跳过"
            return 0
        fi
        
        if [ -f /etc/apt/sources.list.backup ]; then
            log_info "已存在备份文件，跳过备份"
        else
            sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
        fi
        
        local codename
        codename=$(lsb_release -cs 2>/dev/null || echo "focal")
        
        sudo bash -c "cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ ${codename} main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${codename}-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${codename}-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${codename}-backports main restricted universe multiverse
EOF"
        log_info "阿里云镜像源配置完成 (codename: ${codename})"
    else
        log_warn "未找到 /etc/apt/sources.list，跳过镜像源配置"
    fi
}

update_system() {
    log_step "更新软件包列表..."
    sudo apt-get update -qq
    
    log_step "安装系统基础依赖..."
    sudo apt-get install -y -qq curl wget git build-essential procps python3 python3-pip unzip bc lsb-release > /dev/null 2>&1
    log_info "系统基础依赖安装完成"
}

check_go() {
    log_step "检查 Go 语言环境..."
    
    if command -v go &> /dev/null; then
        local go_version
        go_version=$(go version | awk '{print $3}' | sed 's/go//')
        log_info "Go 已安装: $go_version"
        return 0
    fi
    
    log_warn "Go 未安装，正在安装 Go 1.21..."
    local go_version="go1.21.6.linux-amd64"
    local go_tarball="${go_version}.tar.gz"
    
    cd /tmp
    if curl -fsSL --connect-timeout 30 --max-time 300 "https://golang.google.cn/dl/${go_tarball}" -o "${go_tarball}"; then
        sudo tar -C /usr/local -xzf "${go_tarball}"
        sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
        sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
        rm -f "${go_tarball}"
        
        if ! grep -q "/usr/local/go/bin" /etc/profile 2>/dev/null; then
            echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile > /dev/null
        fi
        export PATH="$PATH:/usr/local/go/bin"
        log_info "Go 安装完成: $(go version)"
    else
        log_error "Go 下载失败，请检查网络连接"
    fi
}

check_node() {
    log_step "检查 Node.js 环境..."
    
    if command -v node &> /dev/null; then
        local node_major
        node_major=$(node -v | sed 's/v//' | cut -d. -f1)
        if [ "$node_major" -ge 20 ]; then
            log_info "Node.js 已安装: $(node --version)"
        else
            log_warn "Node.js 版本过低 ($(node --version))，需要 20+，正在升级..."
        fi
    else
        log_warn "Node.js 未安装，正在安装 Node.js 20 LTS..."
    fi
    
    if ! command -v node &> /dev/null || [ "$node_major" -lt 20 ]; then
        curl -fsSL --connect-timeout 30 https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y -qq nodejs > /dev/null 2>&1 || log_error "Node.js 安装失败"
        log_info "Node.js 安装完成: $(node --version)"
    fi

    if ! command -v npm &> /dev/null; then
        log_warn "npm 未找到，正在安装..."
        sudo apt-get install -y -qq npm > /dev/null 2>&1
    fi
    log_info "npm 已就绪: $(npm --version)"
}

install_python_deps() {
    log_step "安装 Python 依赖..."
    
    if command -v pip3 &> /dev/null; then
        pip3 install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple openai python-dotenv requests > /dev/null 2>&1 || {
            log_warn "pip3 安装失败，尝试使用系统 python3 -m pip..."
            python3 -m pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple openai python-dotenv requests > /dev/null 2>&1 || log_error "Python 依赖安装失败"
        }
    elif command -v python3 &> /dev/null; then
        sudo apt-get install -y -qq python3-pip > /dev/null 2>&1
        pip3 install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple openai python-dotenv requests > /dev/null 2>&1 || log_error "Python 依赖安装失败"
    else
        log_error "Python3 未找到，请手动安装"
    fi
    
    log_info "Python 依赖安装完成"
}

create_workspace() {
    log_step "创建工作目录..."
    
    if [ ! -d "openclaw_workspace" ]; then
        mkdir -p openclaw_workspace
        log_info "工作目录 openclaw_workspace 创建完成"
    else
        log_info "工作目录 openclaw_workspace 已存在"
    fi
}

check_and_clone_openclaw_source() {
    log_step "检查 OpenClaw 源码..."
    
    local workspace_count=$(ls -A openclaw_workspace 2>/dev/null | wc -l)

    if [ "$workspace_count" -eq 0 ]; then
        log_warn "openclaw_workspace 目录为空，正在克隆 OpenClaw 源码..."
        if git clone https://github.com/openclaw/openclaw.git openclaw_workspace 2>/dev/null; then
            log_info "OpenClaw 源码克隆完成"
        else
            log_error "源码克隆失败，请检查网络连接或手动下载"
        fi
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
        log_step "安装 npm 依赖..."
        cd openclaw_workspace
        npm install --silent || log_error "npm 依赖安装失败"
        log_info "npm 依赖安装完成"
    else
        log_warn "未找到 package.json，请检查源码"
    fi
}

check_env_file() {
    log_step "检查配置文件..."
    
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
        if grep -q "your_.*_api_key_here" .env 2>/dev/null; then
            log_warn ".env 文件中存在占位符 API Key"
            log_warn "请确保已填入真实的 API Key"
            log_info "按回车继续，或 Ctrl+C 退出修改..."
            read -r
        fi
        log_info ".env 文件检查通过"
    fi
}

install_openclaw_cli() {
    log_step "安装 OpenClaw CLI..."
    
    if command -v openclaw &> /dev/null; then
        log_info "OpenClaw CLI 已安装: $(openclaw --version 2>/dev/null || echo 'version unknown')"
    else
        log_warn "正在全局安装 OpenClaw CLI..."
        sudo npm install -g openclaw@latest > /dev/null 2>&1 || log_error "OpenClaw CLI 安装失败"
        log_info "OpenClaw CLI 安装完成"
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
    log_info "或后台运行:"
    log_info "  cd openclaw_workspace"
    log_info "  nohup openclaw gateway --port 8080 > openclaw.log 2>&1 &"
    echo ""
    log_info "详细文档请查看 README.md"
    log_info "=========================================="
}

main() {
    echo ""
    log_info "=========================================="
    log_info "  OpenClaw 一键部署脚本 (Linux)"
    log_info "=========================================="
    echo ""
    
    check_os
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