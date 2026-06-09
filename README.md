# ZeroTier QPKG Builder for QNAP NAS

一个自动化的 ZeroTier One QPKG 构建工具，用于在 QNAP NAS 上创建 ZeroTier 虚拟网络客户端。

## ✨ 特性

- 🔧 **一键构建**：自动化下载、编译、打包全过程
- 🐳 **Docker 容器化**：在隔离环境中构建，保证一致性
- 🎯 **参数化控制**：支持分步执行（下载、配置、构建）
- 📦 **静态编译**：生成独立的可执行文件，无需外部依赖
- 🏷️ **版本可配置**：轻松修改 ZeroTier 版本
- 🖥️ **x86_64 架构**：支持主流 QNAP NAS 型号

## 📋 系统要求

- **操作系统**：Linux 或 macOS
- **Docker**：Docker Engine 20.10+ 和 Docker Compose
- **存储空间**：至少 2GB 可用空间
- **网络**：稳定的网络连接以下载源码

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone https://github.com/take7yo/zerotier-qpkg-builder.git
cd zerotier-qpkg-builder
```

### 2. 赋予执行权限
```bash
chmod +x build.sh
```

### 3. 完整构建（推荐）
```bash
./build.sh
```
这将执行完整的构建流程：下载源码 → 生成配置文件 → 编译打包

## ⚙️ 使用方法

### 基本命令
```bash
# 显示帮助信息
./build.sh -h
./build.sh --help

# 完整构建流程（默认）
./build.sh

# 仅下载资源
./build.sh -d
./build.sh --download

# 仅生成配置文件
./build.sh -c
./build.sh --config

# 仅执行构建（需已下载资源）
./build.sh -b
./build.sh --build
```

### 组合参数
```bash
# 下载并生成配置
./build.sh -dc
./build.sh -d -c

# 生成配置并构建
./build.sh -cb
./build.sh -c -b

# 下载、配置、构建（完整流程）
./build.sh -dcb
./build.sh -d -c -b
```

## 📁 项目结构

```
zerotier-qpkg-builder/
├── build.sh              # 主构建脚本
├── Dockerfile.alpine     # ZeroTier 编译环境
├── Dockerfile.builder    # QPKG 打包环境
├── docker-compose.yml    # Docker 编排配置
├── output/               # 生成的 QPKG 文件
├── qpkg-template/        # QPKG 模板文件
│   ├── build/
│   ├── shared/
│   │   └── zerotier.sh   # 服务控制脚本
│   ├── x86_64/
│   ├── package_routines  # 安装/卸载脚本
│   └── qpkg.cfg          # QPKG 配置文件
├── ZeroTierOne-src/      # ZeroTier 源码（构建时下载）
└── README.md             # 本文档
```

## 🔧 构建流程

脚本使用两阶段 Docker 构建：

1. **第一阶段**（Alpine Linux 容器）：
   - 下载并安装 Rust 工具链
   - 静态编译 ZeroTier One
   - 生成可执行文件

2. **第二阶段**（Ubuntu 容器）：
   - 安装 QDK（QNAP 开发工具包）
   - 打包为 QPKG 格式
   - 输出到 `output/` 目录

## 📦 生成的 QPKG 文件

构建完成后，QPKG 文件位于：
```
output/zerotier_1.16.2_x86_64.qpkg
```

### 在 QNAP NAS 上安装

#### 方法一：Web 界面安装（推荐）
1. 登录 QNAP 管理界面
2. 进入 "App Center" → "手动安装"
3. 上传生成的 QPKG 文件
4. 按照提示完成安装

#### 方法二：SSH 命令行安装
1. 通过 SSH 登录到 QNAP NAS
2. 上传 QPKG 文件到 NAS（可以使用 SCP 或 WinSCP）
3. 执行安装命令：

```bash
# 复制 QPKG 文件到 NAS（从本地机器）
scp zerotier_1.16.2_x86_64.qpkg admin@your-nas-ip:/share/Public/

# SSH 登录到 NAS
ssh admin@your-nas-ip

# 安装 QPKG
cd /share/Public
qpkg_cli -i zerotier_1.16.2_x86_64.qpkg

# 或者使用 QNAP 的安装工具
installpkg zerotier_1.16.2_x86_64.qpkg
```

#### 方法三：QNAP 专用命令
```bash
# 检查 QPKG 信息
qpkg_cli -s zerotier_1.16.2_x86_64.qpkg

# 强制安装（覆盖现有版本）
qpkg_cli -f -i zerotier_1.16.2_x86_64.qpkg

# 卸载 ZeroTier
qpkg_cli -r zerotier
```

#### 安装后的配置
```bash
# 启用 ZeroTier
/sbin/setcfg zerotier Enable TRUE -f /etc/config/qpkg.conf

# 设置开机自启
/sbin/setcfg zerotier autorun TRUE -f /etc/config/qpkg.conf
```

## ⚡ ZeroTier 使用

### 基本命令
```bash
# 启动 ZeroTier
/usr/local/bin/zerotier-cli start

# 加入网络
/usr/local/bin/zerotier-cli join <network-id>

# 查看状态
/usr/local/bin/zerotier-cli status

# 列出网络
/usr/local/bin/zerotier-cli listnetworks
```

### 服务管理
```bash
# 启动 / 停止 / 重启（通过 QPKG 框架）
qpkg_cli -s zerotier start
qpkg_cli -s zerotier stop
qpkg_cli -s zerotier restart
```

## 🔄 版本配置

要修改 ZeroTier 版本，编辑 `build.sh` 文件：
```bash
# 修改此行
ZEROTIER_VERSION="1.16.2"
```

## 🐛 故障排除

### 常见问题

1. **构建失败：网络连接问题**
   ```
   ERROR: 下载 QDK 失败，请检查网络连接或 URL 有效性。
   ```
   **解决方案**：确保网络连接正常，可以访问 GitHub

2. **Docker 权限问题**
   ```
   Got permission denied while trying to connect to the Docker daemon
   ```
   **解决方案**：将当前用户加入 docker 组
   ```bash
   sudo usermod -aG docker $USER
   # 重新登录生效
   ```

3. **磁盘空间不足**
   **解决方案**：清理 Docker 缓存
   ```bash
   docker system prune -a
   ```

4. **QPKG 安装失败**
   **解决方案**：
   - 确认 QNAP NAS 架构为 x86_64
   - 检查 QPKG 文件完整性
   - 确保有足够的磁盘空间

5. **SSH 安装权限问题**
   ```
   Permission denied
   ```
   **解决方案**：
   ```bash
   # 使用管理员账号
   ssh admin@your-nas-ip
   
   # 或检查文件权限
   chmod 644 zerotier_1.16.2_x86_64.qpkg
   ```

### 调试模式
要查看详细的构建日志，可以临时修改脚本：
```bash
# 在脚本开头添加
set -x
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 许可证

本项目基于 MIT 许可证 - 查看 LICENSE 文件了解详情

## 👥 贡献者

感谢所有为这个项目做出贡献的人！

<a href="https://github.com/yourusername/zerotier-qpkg-builder/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=yourusername/zerotier-qpkg-builder" />
</a>

## ⭐ 支持

如果这个项目对你有帮助，请给它一个 Star！⭐

## 📞 联系

- 项目地址：https://github.com/take7yo/zerotier-qpkg-builder
- 报告问题：https://github.com/take7yo/zerotier-qpkg-builder/issues

---

**注意**：本项目仅用于学习和研究目的。使用 ZeroTier 请遵守相关服务条款。

**备注**：arm 架构理论上也可行，手头上无 arm 架构机器无法验证，有需要的可自行修改 Dockerfile 中的基础镜像和 `platform: linux/arm64`，QPKG 配置的 `QPKG_ARCH="arm_64"` 等相关的配置信息。或者直接把 build.sh 丢给 AI 让 AI 生成一个 arm 架构的版本试一试。
