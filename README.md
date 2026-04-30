# OpenClaw 一键部署包

跨平台部署方案，支持 **Windows 10/11** 和 **Ubuntu Linux** 傻瓜式安装。

---

## 目录结构

```
openclaw-deploy/
├── install.ps1          # Windows 一键部署脚本 (PowerShell)
├── install.sh           # Linux 一键部署脚本 (Bash)
├── start.bat            # Windows 快捷启动 (双击运行)
├── start.sh             # Linux 快捷启动脚本
├── .env.template        # 环境变量模板
├── .env                 # 实际配置文件（自动生成，不提交 Git）
├── .gitignore           # Git 忽略配置
└── openclaw_workspace/  # 工作目录（首次运行时自动创建）
```

---

# 一、Windows 系统部署指南

## 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Windows 10 (20H2+) 或 Windows 11 |
| **内存** | 最低 4GB，推荐 8GB+ |
| **磁盘空间** | 最低 10GB，推荐 20GB+ |
| **权限** | 管理员权限（首次安装依赖时需要） |
| **PowerShell** | 5.1 及以上（系统自带） |

## 部署步骤

### 第一步：下载安装包

从 GitHub 下载并解压：

```powershell
# 方法 1：使用 PowerShell 下载
Invoke-WebRequest -Uri "https://github.com/zhanghui179910-prog/openclaw-deploy/archive/refs/heads/main.zip" -OutFile "openclaw-deploy.zip"
Expand-Archive -Path "openclaw-deploy.zip" -DestinationPath "."
cd openclaw-deploy-main
```

或直接从浏览器下载 ZIP 包：https://github.com/zhanghui179910-prog/openclaw-deploy/archive/refs/heads/main.zip

### 第二步：一键安装

**右键点击 PowerShell**，选择 **"以管理员身份运行"**，然后执行：

```powershell
# 进入安装包目录
cd 你的下载路径\openclaw-deploy-main

# 解除脚本执行限制
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

# 运行安装脚本
.\install.ps1
```

脚本会自动完成：

- ✅ 检测操作系统版本和兼容性
- ✅ 安装 Chocolatey 包管理器
- ✅ 安装 Node.js 20 LTS
- ✅ 安装 Python 3.11 + pip
- ✅ 安装 Go 1.21
- ✅ 安装 Git
- ✅ 克隆 OpenClaw 源码
- ✅ 安装所有依赖
- ✅ 生成 .env 配置文件
- ✅ 创建快捷启动脚本

### 第三步：配置 API Key

首次运行脚本会提示配置 API Key，打开 .env 文件：

```powershell
notepad .env
```

填入你的真实密钥：

```env
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
ZHIPU_API_KEY=your_zhipu_api_key_here
SILICON_FLOW_API_KEY=your_silicon_flow_api_key_here
```

保存并关闭记事本。

### 第四步：完成部署

再次运行安装脚本：

```powershell
.\install.ps1
```

看到 `部署完成！` 即表示安装成功。

---

## 启动 OpenClaw

### 方式 1：双击启动（推荐）

直接双击 `start.bat` 文件，即可启动 OpenClaw 网关。

### 方式 2：PowerShell 启动

```powershell
.\start.ps1
```

### 方式 3：手动启动

```powershell
cd openclaw_workspace
openclaw gateway --port 8080 --verbose
```

### 验证服务

浏览器访问：http://localhost:8080

或用 PowerShell 测试：

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/api/chat" -Method Post -ContentType "application/json" -Body '{"message":"你好"}'
```

---

## 常见问题（Windows）

### Q: 提示"无法加载文件，因为在此系统上禁止运行脚本"

**解决方法：** 以管理员身份运行 PowerShell，执行：

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

### Q: Chocolatey 安装失败

**解决方法：** 使用 winget 替代：

```powershell
winget install OpenJS.NodeJS.LTS
winget install Python.Python.3.11
winget install GoLang.Go
winget install Git.Git
```

### Q: npm install 速度慢

**解决方法：** 切换淘宝镜像源：

```powershell
npm config set registry https://registry.npmmirror.com
```

### Q: 端口 8080 被占用

**解决方法：** 修改启动命令使用其他端口：

```powershell
openclaw gateway --port 8888 --verbose
```

或编辑 start.bat 中的端口号。

---

# 二、Ubuntu Linux 系统部署指南

## 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | Ubuntu 20.04+（推荐 22.04+） |
| **内存** | 最低 4GB，推荐 8GB+ |
| **磁盘空间** | 最低 20GB，推荐 40GB+ |
| **权限** | sudo 权限 |

## 虚拟机环境准备

### 硬件资源分配

| 配置项 | 最低要求 | 推荐配置 |
|--------|----------|----------|
| CPU 核心数 | 2 核 | 4 核及以上 |
| 内存 | 4 GB | 8 GB 及以上 |
| 磁盘空间 | 20 GB | 40 GB 及以上 |
| 交换分区 | 2 GB | 4 GB |

### 网络模式配置

推荐使用**桥接模式 (Bridged)**，让虚拟机获得独立 IP 地址：

1. VMware/VirtualBox 中选择 **桥接网卡 (Bridged)**
2. 选择宿主机的物理网卡作为桥接接口
3. 启动后执行 `ip addr` 确认独立 IP
4. 从宿主机可直接 SSH 连接虚拟机

### SSH 连接设置

```bash
sudo apt-get install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

从宿主机连接：

```bash
ssh username@虚拟机IP地址
```

### 虚拟化引擎设置

确保在 VMware/VirtualBox 中开启硬件虚拟化：

- **Intel VT-x** / **AMD-V**

## 部署步骤

### 第一步：获取安装包

```bash
git clone https://github.com/zhanghui179910-prog/openclaw-deploy.git
cd openclaw-deploy
```

### 第二步：赋予执行权限

```bash
chmod +x install.sh
```

### 第三步：运行安装脚本

```bash
./install.sh
```

脚本会自动完成：

- 配置阿里云镜像源
- 安装系统依赖
- 安装 Go 1.21
- 安装 Node.js 20 LTS
- 安装 Python 依赖
- 克隆源码
- 生成配置文件

### 第四步：配置 API Key

```bash
nano .env
```

填入真实 API Key 后保存（Ctrl+X → Y → 回车）。

### 第五步：完成部署

```bash
./install.sh
```

## 启动 OpenClaw

### 方式 1：快捷启动

```bash
./start.sh
```

### 方式 2：前台运行

```bash
cd openclaw_workspace
openclaw gateway --port 8080 --verbose
```

### 方式 3：后台运行

```bash
cd openclaw_workspace
nohup openclaw gateway --port 8080 > openclaw.log 2>&1 &
```

### 方式 4：systemd 服务

创建服务文件：

```bash
sudo nano /etc/systemd/system/openclaw.service
```

内容：

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

启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw
sudo systemctl start openclaw
sudo systemctl status openclaw
```

---

# 三、环境变量说明

| 变量名 | 说明 | 可选值 |
|--------|------|--------|
| `DEEPSEEK_API_KEY` | DeepSeek API 密钥 | 从 https://platform.deepseek.com/ 获取 |
| `ZHIPU_API_KEY` | 智谱 AI API 密钥 | 从 https://open.bigmodel.cn/ 获取 |
| `SILICON_FLOW_API_KEY` | 硅基流动 API 密钥 | 从 https://cloud.siliconflow.cn/ 获取 |
| `CURRENT_PROVIDER` | 当前 AI 提供商 | `deepseek` / `silicon_flow` / `zhipu` |
| `LOG_LEVEL` | 日志级别 | `DEBUG` / `INFO` / `WARNING` / `ERROR` |

---

# 四、数据持久化

所有工作数据保存在 `openclaw_workspace` 目录中。

**备份：**

```bash
# Windows
Compress-Archive -Path openclaw_workspace -DestinationPath openclaw_backup.zip

# Linux
tar -czvf openclaw_backup.tar.gz openclaw_workspace/
```

---

# 五、故障排查

## 通用问题

### 源码克隆失败

GitHub 连接被重置，可尝试：

1. 配置 Git 代理：
   ```bash
   git config --global http.proxy http://代理地址:端口
   ```

2. 手动下载 ZIP 包解压到 `openclaw_workspace` 目录

### API Key 配置错误

确保 `.env` 文件中：

- 使用真实的 API Key（非占位符）
- 没有多余空格或引号
- 保存为 UTF-8 编码

## Linux 特有

### Ubuntu 版本太旧

Node.js 20+ 需要 glibc 2.28+，Ubuntu 18.04 (glibc 2.27) 不兼容：

```bash
sudo apt update && sudo apt upgrade -y
sudo do-release-upgrade
```

## Windows 特有

### 杀毒软件拦截

部分杀毒软件可能拦截 PowerShell 脚本，请添加信任或暂时关闭。

### 环境变量未生效

重启 PowerShell 终端或运行：

```powershell
refreshenv
```

---

# 六、安全提醒

- **`.env` 文件包含真实 API Key，切勿提交到 GitHub**
- 本项目已配置 `.gitignore` 忽略 `.env` 文件
- 定期更换 API Key，避免密钥泄露
- Windows 用户建议配置防火墙规则限制 API 访问来源

---

# 七、更新日志

- **v2.0** - 跨平台支持，新增 Windows 一键部署
- **v1.5** - 优化安装脚本幂等性和错误处理
- **v1.0** - 初始版本，支持 Ubuntu 本地部署