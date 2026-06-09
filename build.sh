#!/bin/bash
set -e

PROJECT_DIR="."
DEFAULT_ZEROTIER_VERSION="1.16.2"
ZEROTIER_VERSION="${DEFAULT_ZEROTIER_VERSION}"

QDK_URL="https://github.com/qnap-dev/QDK/releases/download/v2.5.0/qdk_2.5.0_amd64.deb"

# 控制标志
DOWNLOAD=false
CONFIG=false
BUILD=false
SHOW_VERSION=false

# 显示用法
usage() {
    cat << EOF
ZeroTier QPKG 构建脚本 v1.0

用法: $0 [选项] [版本号]

选项:
  -d, --download     仅下载资源文件
  -c, --config       仅生成配置文件
  -b, --build        仅执行构建（需已下载资源并生成配置）
  -h, --help         显示此帮助信息
  -v, --version      显示版本信息

参数:
  版本号             要构建的 ZeroTier 版本（可选，默认: ${DEFAULT_ZEROTIER_VERSION}）

说明:
  - 如果不带任何参数，执行完整流程（下载+配置+构建）
  - 支持组合参数，如: -dc 或 -dcb
  - 支持单个参数，如: -d -c 或 -d -c -b
  - 参数顺序不影响执行顺序，脚本会自动按正确顺序执行
  - 版本号参数应放在最后

示例:
  $0                     # 完整流程，使用默认版本 ${DEFAULT_ZEROTIER_VERSION}
  $0 1.16.4              # 完整流程，构建 1.16.4 版本
  $0 -dc 1.16.4          # 下载资源并生成配置，使用 1.16.4 版本
  $0 -d                  # 仅下载资源，使用默认版本
  $0 -c 1.15.0           # 仅生成配置，使用 1.15.0 版本
  $0 -b                  # 仅执行构建，使用默认版本
  $0 -dcb 1.16.2         # 完整流程，指定 1.16.2 版本
EOF
    exit 0
}

# 显示版本信息
show_version() {
    cat << EOF
ZeroTier QPKG 构建脚本
默认构建版本: ${DEFAULT_ZEROTIER_VERSION}
当前目标版本: ${ZEROTIER_VERSION}
EOF
    exit 0
}

# 使用 getopt 解析参数
parse_args() {
    # 如果没有参数，则执行完整流程
    if [ $# -eq 0 ]; then
        DOWNLOAD=true
        CONFIG=true
        BUILD=true
        return
    fi

    # 定义短选项和长选项
    local SHORT_OPTS="dcbhv"
    local LONG_OPTS="download,config,build,help,version"

    # 解析参数
    local TEMP
    TEMP=$(getopt -o "$SHORT_OPTS" --long "$LONG_OPTS" -n "$0" -- "$@")

    if [ $? != 0 ]; then
        echo "错误: 参数解析失败"
        usage
    fi

    # 重新设置参数
    eval set -- "$TEMP"

    # 处理参数
    while true; do
        case "$1" in
            -d|--download)
                DOWNLOAD=true
                shift
                ;;
            -c|--config)
                CONFIG=true
                shift
                ;;
            -b|--build)
                BUILD=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -v|--version)
                SHOW_VERSION=true
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "内部错误: 未知参数 '$1'"
                exit 1
                ;;
        esac
    done

    # 处理版本号参数（最后一个非选项参数）
    if [ $# -gt 0 ]; then
        # 检查是否还有额外的未知参数
        if [ $# -eq 1 ]; then
            # 假设最后一个参数是版本号
            ZEROTIER_VERSION="$1"
            echo "==> 使用指定版本: ${ZEROTIER_VERSION}"
        else
            echo "错误: 未知参数 '$*'"
            usage
        fi
    fi

    # 如果指定了--version，显示版本信息
    if [ "$SHOW_VERSION" = true ]; then
        show_version
    fi

    # 如果没有指定任何操作，默认执行完整流程
    if [ "$DOWNLOAD" = false ] && [ "$CONFIG" = false ] && [ "$BUILD" = false ]; then
        DOWNLOAD=true
        CONFIG=true
        BUILD=true
    fi
}

# 创建目录结构
create_dirs() {
    echo "==> 创建项目目录结构..."
    mkdir -p ${PROJECT_DIR}/qpkg-template/{build,shared,x86_64}
    mkdir -p ${PROJECT_DIR}/output
}

# 下载资源
download_resources() {
    echo "==> 下载 QDK 2.5.0..."
    if ! curl -L -o ${PROJECT_DIR}/qdk.deb ${QDK_URL}; then
        echo "ERROR: 下载 QDK 失败，请检查网络连接或 URL 有效性。"
        exit 1
    fi

    echo "==> 下载 ZeroTier One ${ZEROTIER_VERSION} 源码..."
    local ZT_SRC_URL="https://github.com/zerotier/ZeroTierOne/archive/refs/heads/${ZEROTIER_VERSION}.zip"
    if ! curl -L -o /tmp/zt.zip "${ZT_SRC_URL}"; then
        echo "ERROR: 下载 ZeroTier 源码失败，请检查网络连接或 URL 有效性。"
        exit 1
    fi

    unzip -q /tmp/zt.zip -d ${PROJECT_DIR}/
    rm -rf ${PROJECT_DIR}/ZeroTierOne-src
    mv ${PROJECT_DIR}/ZeroTierOne-${ZEROTIER_VERSION} ${PROJECT_DIR}/ZeroTierOne-src
    rm -f /tmp/zt.zip
}

# 生成 Dockerfile.alpine
generate_dockerfile_alpine() {
    cat > ${PROJECT_DIR}/Dockerfile.alpine <<'EOF'
FROM alpine:3.20

RUN apk update && apk add --no-cache \
    make gcc g++ linux-headers musl-dev \
    openssl-dev openssl-libs-static curl

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /tmp/ZeroTierOne
COPY ZeroTierOne-src /tmp/ZeroTierOne

RUN make ZT_STATIC=1

RUN strip zerotier-one

CMD ["sh", "-c", "cp /tmp/ZeroTierOne/zerotier-one /build/qpkg-template/x86_64/ && cp /tmp/ZeroTierOne/zerotier-cli /build/qpkg-template/x86_64/ && cp /tmp/ZeroTierOne/zerotier-idtool /build/qpkg-template/x86_64/"]
EOF
}

# 生成 Dockerfile.builder
generate_dockerfile_builder() {
    cat > ${PROJECT_DIR}/Dockerfile.builder <<'EOF'
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    pv xz-utils rsync gnupg2 curl openssl bsdextrautils

COPY qdk.deb /tmp/qdk.deb
RUN dpkg -i /tmp/qdk.deb

WORKDIR /build/qpkg-template
COPY qpkg-template /build/qpkg-template

CMD ["sh", "-c", "qbuild --build-arch x86_64 && cp /build/qpkg-template/build/* /output/"]
EOF
}

# 生成 docker-compose.yml
generate_docker_compose() {
    cat > ${PROJECT_DIR}/docker-compose.yml <<'EOF'
services:
  alpine-builder:
    platform: linux/amd64
    build:
      context: .
      dockerfile: Dockerfile.alpine
    volumes:
      - ./qpkg-template:/build/qpkg-template
    container_name: zerotier-alpine-builder

  ubuntu-packager:
    platform: linux/amd64
    build:
      context: .
      dockerfile: Dockerfile.builder
    volumes:
      - ./qpkg-template:/build/qpkg-template
      - ./output:/output
    container_name: zerotier-ubuntu-packager
    depends_on:
      - alpine-builder
EOF
}

# 生成 package_routines
generate_package_routines() {
    cat > ${PROJECT_DIR}/qpkg-template/package_routines <<'EOF'
#!/bin/sh

pkg_install() {
    ln -sf "$QPKG_ROOT/usr/bin/zerotier-cli" "/usr/local/bin/zerotier-cli"
}

pkg_post_install() {
    echo "ZeroTier One installed successfully."
}

pkg_pre_remove() {
    $QPKG_SERVICE_PROGRAM stop
}

pkg_main_remove() {
    rm -f "/usr/local/bin/zerotier-cli"
}
EOF
    chmod +x ${PROJECT_DIR}/qpkg-template/package_routines
}

# 生成 qpkg.cfg
generate_qpkg_cfg() {
    cat > ${PROJECT_DIR}/qpkg-template/qpkg.cfg <<EOF
QPKG_NAME="zerotier"
QPKG_VER="${ZEROTIER_VERSION}"
QPKG_AUTHOR="Ivan Zhang"
QPKG_LICENSE="GPL"
QPKG_DISPLAY_NAME="ZeroTier One"
QPKG_ARCH="x86_64"
QPKG_SERVICE_PROGRAM="zerotier.sh"
EOF
}

# 生成 zerotier.sh
generate_zerotier_sh() {
    cat > ${PROJECT_DIR}/qpkg-template/shared/zerotier.sh <<'EOF'
#!/bin/sh

QPKG_NAME="zerotier"
CONF=/etc/config/qpkg.conf
QPKG_ROOT=/share/CACHEDEV1_DATA/.qpkg/${QPKG_NAME}

case "$1" in
  start)
    ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $CONF)
    if [ "$ENABLED" != "TRUE" ]; then
        echo "$QPKG_NAME is disabled."
        exit 1
    fi
    $QPKG_ROOT/zerotier-one -d
    ;;
  stop)
    killall zerotier-one
    ;;
  restart)
    $0 stop
    $0 start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac

exit 0
EOF
    chmod +x ${PROJECT_DIR}/qpkg-template/shared/zerotier.sh
}

# 生成 Docker 相关文件
generate_docker_files() {
    echo "==> 生成 Docker 相关文件..."
    generate_dockerfile_alpine
    generate_dockerfile_builder
    generate_docker_compose
}

# 生成 QPKG 模板文件
generate_qpkg_files() {
    echo "==> 生成 QPKG 模板文件..."
    generate_package_routines
    generate_qpkg_cfg
    generate_zerotier_sh
}

# 执行构建
execute_build() {
    echo "==> 开始构建..."
    cd ${PROJECT_DIR}
    docker compose up --build --force-recreate
    echo "==> 构建完成！"
    echo "最终 QPKG 文件位于：output/zerotier_${ZEROTIER_VERSION}_x86_64.qpkg"
}

# 执行配置生成
execute_config() {
    echo "==> 执行配置生成..."
    create_dirs
    generate_docker_files
    generate_qpkg_files
    echo "==> 配置生成完成"
}

# 执行下载
execute_download() {
    echo "==> 执行资源下载..."
    create_dirs
    download_resources
    echo "==> 资源下载完成"
}

# 主函数
main() {
    parse_args "$@"

    # 显示执行的步骤
    echo "=== ZeroTier QPKG 构建脚本 ==="
    echo "目标版本: ${ZEROTIER_VERSION}"
    echo "步骤:"
    echo "  - 下载资源: $([ "$DOWNLOAD" = true ] && echo "是" || echo "否")"
    echo "  - 生成配置: $([ "$CONFIG" = true ] && echo "是" || echo "否")"
    echo "  - 执行构建: $([ "$BUILD" = true ] && echo "是" || echo "否")"
    echo "============================="

    # 执行下载
    if [ "$DOWNLOAD" = true ]; then
        execute_download
    fi

    # 执行配置生成
    if [ "$CONFIG" = true ]; then
        execute_config
    fi

    # 执行构建
    if [ "$BUILD" = true ]; then
        execute_build
    fi

    echo "=== 所有操作完成 ==="
}

# 执行主函数
main "$@"
