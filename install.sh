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

configure_docker_mirror() {
    local mirror_config='{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me"
  ]
}'
    if [ -f /etc/docker/daemon.json ]; then
        if grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
            log_info "Docker 镜像加速已配置，跳过"
            return 0
        fi
        log_warn "检测到现有 daemon.json，备份并更新..."
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
    fi
    log_warn "配置国内 Docker 镜像加速器..."
    sudo mkdir -p /etc/docker
    echo "$mirror_config" | sudo tee /etc/docker/daemon.json > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    log_info "镜像加速配置完成"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_warn "Docker 未安装，正在自动安装..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release > /dev/null 2>&1
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin > /dev/null 2>&1 || log_error "Docker 安装失败"
        sudo systemctl start docker || sudo service docker start
        sudo systemctl enable docker || true
        sudo usermod -aG docker $USER
        configure_docker_mirror
        log_info "Docker 安装完成"
        log_warn "=========================================="
        log_warn "  安装完成，建议重新登录后执行 ./install.sh"
        log_warn "  或直接继续执行（如果 Docker 已可用）"
        log_warn "=========================================="
    else
        log_info "Docker 已安装: $(docker --version)"
        configure_docker_mirror
    fi
}

check_docker_compose() {
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        log_warn "Docker Compose 未安装，正在自动安装..."
        sudo apt-get install -y -qq docker-compose > /dev/null 2>&1 || log_warn "Docker Compose 安装失败，请手动安装"
        log_info "Docker Compose 安装完成"
    else
        log_info "Docker Compose 已就绪: $(docker compose version 2>/dev/null || docker-compose version 2>/dev/null)"
    fi
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

    if [ -f "openclaw_workspace/requirements.txt" ]; then
        log_info "requirements.txt 已就绪"
    else
        log_warn "未找到 requirements.txt，请检查源码"
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

start_services() {
    log_info "正在构建并启动 OpenClaw 服务..."
    docker compose up -d --build

    log_info "等待容器启动完成..."
    sleep 3

    if [ -f "openclaw_workspace/requirements.txt" ]; then
        log_info "正在安装 Python 依赖..."
        docker exec openclaw bash -c "cd /workspace && pip install -r requirements.txt"
        log_info "Python 依赖安装完成"
    fi

    log_info "=========================================="
    log_info "  OpenClaw 启动成功！"
    log_info "  查看日志: docker compose logs -f"
    log_info "  进入容器: docker exec -it openclaw bash"
    log_info "=========================================="
}

main() {
    echo ""
    log_info "========== OpenClaw 一键部署脚本 =========="
    echo ""
    check_sudo
    check_docker
    check_docker_compose
    create_workspace
    check_and_clone_openclaw_source
    check_env_file
    start_services
}

main "$@"
