# OpenClaw 离线部署包

一键在 Ubuntu 虚拟机中部署 OpenClaw，直接在本地安装 Python3、Go 和 Node.js 环境。

## 目录结构

```
openclaw-deploy/
├── install.sh           # 核心一键部署脚本
├── .env.template        # 环境变量模板
├── .env                 # 实际配置文件（自动生成，不提交 Git）
└── openclaw_workspace/  # 工作目录（数据持久化）
```

---

# 虚拟机环境准备与注意事项

## 硬件资源分配

| 配置项 | 最低要求 | 推荐配置 |
|--------|----------|----------|
| CPU 核心数 | 2 核 | 4 核及以上 |
| 内存 | 4 GB | 8 GB 及以上 |
| 磁盘空间 | 20 GB | 40 GB 及以上 |
| 交换分区 | 2 GB | 4 GB |

> **注意**：AI 相关组件（如模型推理、Python/Go 编译）可能占用大量内存和 CPU，建议预留充足资源。

## 网络模式配置

推荐使用**桥接模式 (Bridged)**，让虚拟机获得独立 IP 地址，便于从宿主机直接访问服务。

### 桥接模式配置步骤

1. 在 VMware/VirtualBox 中选择虚拟机网络模式为 **桥接网卡 (Bridged)**
2. 选择宿主机的物理网卡作为桥接接口
3. 启动虚拟机后执行 `ip addr` 确认是否获得独立 IP
4. 从宿主机终端可直接用该 IP SSH 连接虚拟机

### NAT + 端口转发（备选）

如果使用 NAT 模式，需要配置端口转发：

**VirtualBox**：虚拟机设置 → 网络 → 高级 → 端口转发
- 规则示例：主机端口 2222 → 虚拟机 IP:22

**VMware**：虚拟机 → 设置 → 网络适配器 → 高级 → 端口转发

## SSH 连接

**强烈建议安装 SSH 服务**，方便在宿主机终端操作虚拟机：

```bash
sudo apt-get install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

然后从宿主机连接：

```bash
ssh username@虚拟机IP地址
```

> 避免在虚拟机简陋的窗口中敲代码，SSH 连接体验更好，支持复制粘贴和标签页。

## 虚拟化引擎设置

确保在 VMware/VirtualBox 中开启了硬件虚拟化支持：

- **Intel VT-x**：Intel 处理器需要开启
- **AMD-V**：AMD 处理器需要开启

### VMware 开启方法

1. 虚拟机设置 → 处理器 →勾选 **"虚拟化 Intel VT-x/EPT 或 AMD-V/RVI"**

### VirtualBox 开启方法

1. 虚拟机设置 → 系统 → 加速 → 勾选 **"启用 VT-x/AMD-V"**

## 基础环境

首次部署前，务必执行基础更新：

```bash
sudo apt update && sudo apt upgrade -y
```

如果系统版本较旧（如 Ubuntu 18.04），建议升级后再继续：

```bash
sudo do-release-upgrade
```

---

# Ubuntu 本地部署指南

## 部署步骤

### 第一步：获取安装包

从宿主机将安装包传输到虚拟机，或直接在虚拟机中克隆：

```bash
git clone https://github.com/zhanghui179910-prog/openclaw-deploy.git
cd openclaw-deploy
```

### 第二步：赋予执行权限

```bash
chmod +x install.sh
```

### 第三步：首次运行（自动安装所有依赖）

```bash
./install.sh
```

脚本会自动完成：

- 配置阿里云镜像源（加速下载）
- 安装系统基础依赖（curl, wget, git, build-essential, python3, pip）
- 安装 Go 1.21 语言环境
- 安装 Node.js 20 LTS 环境
- 安装 Python 依赖（openai, python-dotenv, requests）
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

### 第五步：再次运行完成部署

```bash
./install.sh
```

看到 `部署完成！` 即表示安装成功。

## 启动 OpenClaw

### 方式一：前台运行

```bash
cd openclaw_workspace
openclaw gateway --port 8080 --verbose
```

### 方式二：后台运行（使用 nohup）

```bash
cd openclaw_workspace
nohup openclaw gateway --port 8080 > openclaw.log 2>&1 &
```

### 方式三：使用 systemd 服务（可选）

创建服务文件：

```bash
sudo nano /etc/systemd/system/openclaw.service
```

内容如下：

```ini
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/openclaw-deploy/openclaw_workspace
ExecStart=/usr/local/bin/openclaw gateway --port 8080 --verbose
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

启用并启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw
sudo systemctl start openclaw
```

查看服务状态：

```bash
sudo systemctl status openclaw
```

---

## 日常使用

### 查看 OpenClaw 进程

```bash
ps aux | grep openclaw
```

### 查看实时日志

```bash
tail -f openclaw_workspace/openclaw.log
```

### 停止服务

```bash
pkill -f "openclaw gateway"
```

### 重启服务

```bash
pkill -f "openclaw gateway"
cd openclaw_workspace
openclaw gateway --port 8080 --verbose &
```

### 检查环境版本

```bash
python3 --version
go version
node --version
npm --version
openclaw --version
```

---

## 与 OpenClaw 对话

### 通过 API 调用

服务启动后，访问 http://localhost:8080 或 http://虚拟机IP:8080：

```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "你好，请介绍一下你自己"}'
```

### 运行 Python 脚本

```bash
cd openclaw_workspace
python3 your_script.py
```

---

## 故障排查

### Ubuntu 版本太旧导致安装失败

如果使用 Ubuntu 18.04，Node.js 20+ 需要更高版本的 glibc。请先升级系统：

```bash
sudo apt update && sudo apt upgrade -y
sudo do-release-upgrade
```

或手动更换镜像源后升级：

```bash
sudo bash -c 'cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF'
sudo apt update && sudo apt upgrade -y
sudo do-release-upgrade
```

### 下载速度慢

脚本已默认配置阿里云镜像源。如需更换其他镜像源，修改 `/etc/apt/sources.list`。

### 端口 8080 被占用

修改启动命令使用其他端口：

```bash
openclaw gateway --port 8888 --verbose
```

### Go/Python/Node 环境异常

检查环境变量是否正确加载：

```bash
echo $PATH
which go
which node
which python3
```

如需手动刷新环境：

```bash
source /etc/profile
```

### 重置所有数据

```bash
rm -rf openclaw_workspace
rm -f .env
./install.sh
```

---

## 环境变量说明

| 变量名 | 说明 | 可选值 |
|--------|------|--------|
| `CURRENT_PROVIDER` | 当前使用的 AI 提供商 | `deepseek` / `silicon_flow` / `zhipu` |
| `LOG_LEVEL` | 日志级别 | `DEBUG` / `INFO` / `WARNING` / `ERROR` |
| `WORKSPACE_PATH` | 工作空间路径 | `/workspace` |

---

## 数据持久化

所有工作数据保存在 `./openclaw_workspace` 目录中，重装系统前请备份：

```bash
tar -czvf openclaw_backup.tar.gz openclaw_workspace/
```

---

## 安全提醒

- **`.env` 文件包含真实 API Key，切勿提交到 GitHub**
- 本项目已配置 `.gitignore` 忽略 `.env` 文件
- 定期更换 API Key，避免密钥泄露
- 建议使用防火墙限制 API 访问来源