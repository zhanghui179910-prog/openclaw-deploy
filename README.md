# OpenClaw 离线部署包

一键在 Ubuntu 虚拟机中部署 OpenClaw，支持 Docker 离线运行，内置 Python3 和 Go 语言环境。

## 目录结构

```
openclaw-deploy/
├── install.sh           # 核心一键部署脚本
├── docker-compose.yml   # Docker 服务编排配置
├── Dockerfile           # 容器构建文件（内置 Python3 + Go）
├── .env.template        # 环境变量模板
├── .env                 # 实际配置文件（自动生成，不提交 Git）
└── openclaw_workspace/ # 工作目录（数据持久化）
```

## 部署步骤

### 第一步：获取安装包

从 GitHub 克隆或下载本仓库到 Ubuntu 虚拟机：

```bash
git clone https://github.com/zhanghui179910-prog/openclaw-deploy.git
cd openclaw-deploy
```

### 第二步：赋予执行权限

```bash
chmod +x install.sh
```

### 第三步：首次运行（自动安装 Docker + 初始化配置）

```bash
./install.sh
```

脚本会自动完成：

- 检查并安装 Docker（若未安装）
- 检查并安装 Docker Compose（若未安装）
- 配置国内 Docker 镜像加速器
- 创建 `openclaw_workspace` 工作目录
- 从 `.env.template` 生成 `.env` 配置文件

**首次运行后会提示配置 API Key，此时脚本会暂停，请进行下一步。**

### 第四步：配置 API Key

用编辑器打开 `.env` 文件：

```bash
nano .env
```

找到以下行，将占位符替换为真实密钥：

```env
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
ZHIPU_API_KEY=your_zhipu_api_key_here
SILICON_FLOW_API_KEY=your_silicon_flow_api_key_here
```

保存退出：`Ctrl + X` → `Y` → `回车`

### 第五步：再次运行启动服务

```bash
./install.sh
```

看到 `✓ OpenClaw 启动成功！` 即表示部署完成。

### 第六步：配置 Docker 权限（非 root 用户）

如果以非 root 用户运行 Docker 命令（如 `docker compose ps`），需要将自己加入 docker 组：

```bash
sudo usermod -aG docker $USER
```

**然后重新登录 Ubuntu**（退出当前终端并重新连接），使权限生效。

### 常见权限问题

| 错误信息 | 解决方法 |
|---------|---------|
| `permission denied while trying to connect to the Docker daemon` | 执行 `sudo usermod -aG docker $USER` 后重新登录 |
| `Got permission denied while trying to connect to the Docker daemon socket` | 同上，或使用 `sudo docker ...` 前缀 |

## 日常使用

### 查看服务状态

```bash
docker compose ps
```

### 查看实时日志

```bash
docker compose logs -f
```

按 `Ctrl + C` 退出日志。

### 停止服务

```bash
docker compose down
```

### 重启服务

```bash
docker compose restart
```

### 重新构建（修改代码后）

```bash
docker compose up -d --build
```

### 进入容器终端

```bash
docker exec -it openclaw bash
```

### 在容器内测试环境

```bash
python3 --version
go version
```

## 与 OpenClaw 对话

### 方式一：进入容器交互式对话

```bash
docker exec -it openclaw bash
cd /workspace
python3 your_script.py
```

### 方式二：通过 API 调用

容器已暴露 8080 端口：

```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "你好，请介绍一下你自己"}'
```

## 故障排查

### Docker 未安装成功

脚本会自动安装。如需手动安装：

```bash
curl -fsSL https://get.docker.com | sh
```

### Docker 镜像拉取失败

脚本会自动配置国内镜像加速器（`https://docker.1ms.run`）。如需手动配置：

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me"
  ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 端口冲突

若 8080 端口已被占用，修改 `docker-compose.yml` 中的端口映射：

```yaml
ports:
  - "8888:8080"
```

然后重启服务：

```bash
docker compose down
docker compose up -d
```

### 容器不断重启

查看日志定位问题：

```bash
docker compose logs -f
```

### 查看容器内部状态

```bash
docker exec -it openclaw ps aux
docker exec -it openclaw env
```

### 重置所有数据

```bash
docker compose down -v
rm -rf openclaw_workspace
rm -f .env
./install.sh
```

## 环境变量说明

| 变量名 | 说明 | 可选值 |
|--------|------|--------|
| `CURRENT_PROVIDER` | 当前使用的 AI 提供商 | `deepseek` / `silicon_flow` / `zhipu` |
| `LOG_LEVEL` | 日志级别 | `DEBUG` / `INFO` / `WARNING` / `ERROR` |
| `WORKSPACE_PATH` | 工作空间路径（容器内） | `/workspace` |

## 数据持久化

所有工作数据保存在宿主机的 `./openclaw_workspace` 目录中，删除容器不会丢失数据。

如需备份：

```bash
tar -czvf openclaw_backup.tar.gz openclaw_workspace/
```

## 安全提醒

- **`.env` 文件包含真实 API Key，切勿提交到 GitHub**
- 本项目已配置 `.gitignore` 忽略 `.env` 文件
- 定期更换 API Key，避免密钥泄露
