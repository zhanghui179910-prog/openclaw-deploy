# OpenClaw 离线部署包

一键在 Ubuntu 虚拟机中部署 OpenClaw，支持 Docker 离线运行，内置 Python3 和 Go 语言环境。

## 目录结构

```
openclaw-deploy/
├── install.sh           # 核心一键部署脚本（首次运行）
├── docker-compose.yml   # Docker 服务编排配置
├── Dockerfile           # 容器构建文件（内置 Python3 + Go）
├── .env.template        # 环境变量模板
├── .env                 # 实际配置文件（自动生成）
└── openclaw_workspace/  # 工作目录（自动创建，数据持久化）
```

## 快速开始

### 第一步：赋予执行权限

```bash
chmod +x install.sh
```

### 第二步：首次运行（自动安装依赖 + 初始化配置）

```bash
./install.sh
```

脚本会自动完成：
- 检查并安装 Docker（若未安装）
- 检查并安装 Docker Compose（若未安装）
- 创建 `openclaw_workspace` 工作目录
- 从 `.env.template` 生成 `.env` 配置文件

**首次运行后会提示您修改 .env 文件，请填入您的 API Key。**

### 第三步：修改配置文件

用文本编辑器打开 `.env` 文件，填入您的 API Key：

```bash
nano .env
```

找到以下行，将 `your_xxx_api_key_here` 替换为真实密钥：

```env
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
```

### 第四步：再次运行脚本启动服务

```bash
./install.sh
```

看到绿色的 `✓ OpenClaw 启动成功！` 即表示部署完成。

## 日常使用

### 查看服务状态

```bash
docker compose ps
```

### 查看实时日志

```bash
docker compose logs -f
```

### 停止服务

```bash
docker compose down
```

### 重启服务

```bash
docker compose restart
```

### 进入容器终端

```bash
docker exec -it openclaw bash
```

### 在容器内测试 Python

```bash
python3 --version
python3 -c "print('Hello from OpenClaw!')"
```

### 在容器内测试 Go

```bash
go version
go run hello.go
```

## 与 OpenClaw 对话

### 方式一：进入容器交互式对话

```bash
docker exec -it openclaw bash
cd /workspace
python3 your_script.py
```

### 方式二：通过 API 调用（容器已暴露 8080 端口）

```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "你好，请介绍一下你自己"}'
```

## 故障排查

### Docker 未安装

脚本会自动安装。如需手动安装：

```bash
curl -fsSL https://get.docker.com | sh
```

### 端口冲突

若 8080 端口已被占用，修改 `docker-compose.yml` 中的端口映射：

```yaml
ports:
  - "8888:8080"  # 改为 8888:8080
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
./install.sh  # 重新初始化
```

## 环境变量说明

| 变量名 | 说明 | 可选值 |
|--------|------|--------|
| `CURRENT_PROVIDER` | 当前使用的 AI 提供商 | `deepseek` / `silicon_flow` / `zhipu` |
| `LOG_LEVEL` | 日志级别 | `DEBUG` / `INFO` / `WARNING` / `ERROR` |

## 数据持久化

所有工作数据保存在宿主机的 `./openclaw_workspace` 目录中，删除容器不会丢失数据。

如需备份：

```bash
tar -czvf openclaw_backup.tar.gz openclaw_workspace/
```
