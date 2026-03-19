#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[✓] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[⚠] $1${NC}"; }
log_error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_warn "Docker 未安装，正在自动安装..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release > /dev/null 2>&1
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1
        sudo systemctl start docker || sudo service docker start
        sudo systemctl enable docker || true
        sudo usermod -aG docker $USER
        log_success "Docker 安装完成（可能需要重新登录）"
    else
        log_success "Docker 已安装: $(docker --version)"
    fi
}

check_docker_compose() {
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_warn "Docker Compose 未安装，正在自动安装..."
        sudo apt-get install -y -qq docker-compose > /dev/null 2>&1 || true
        log_success "Docker Compose 安装完成"
    else
        log_success "Docker Compose 已就绪"
    fi
}

create_workspace() {
    if [ ! -d "openclaw_workspace" ]; then
        mkdir -p openclaw_workspace
        log_success "工作目录 openclaw_workspace 创建完成"
    else
        log_success "工作目录 openclaw_workspace 已存在"
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
        log_success "已从 .env.template 生成 .env 文件"
        exit 0
    else
        log_success ".env 文件检查通过"
    fi
}

start_services() {
    log_success "正在启动 OpenClaw 服务..."
    docker compose up -d
    log_success "=========================================="
    log_success "  OpenClaw 启动成功！"
    log_success "  查看日志: docker compose logs -f"
    log_success "  进入容器: docker exec -it openclaw bash"
    log_success "=========================================="
}

main() {
    echo ""
    log_success "========== OpenClaw 一键部署脚本 =========="
    echo ""

    check_docker
    check_docker_compose
    create_workspace
    check_env_file
    start_services
}

main "$@"
