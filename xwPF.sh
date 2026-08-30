#!/bin/bash

# xwPF - Realm 端口转发管理工具
# Bootstrap 引导器 + 入口

# 安装路径
INSTALL_DIR="/usr/local/bin"
LIB_DIR="$INSTALL_DIR/lib"
SHORTCUT_PATH="/usr/local/bin/pf"
PORT_TRAFFIC_DOG_PATH="$INSTALL_DIR/port-traffic-dog.sh"
TELEGRAM_MODULE_PATH="/etc/port-traffic-dog/notifications/telegram.sh"

# 仓库地址
REPO_RAW_URL="https://raw.githubusercontent.com/lzj565/realm-xwPF/main"

# 模块列表（加载顺序）
LIB_FILES=("core.sh" "rules.sh" "server.sh" "realm.sh" "ui.sh")

# 颜色
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[1;33m'
_BLUE='\033[0;34m'
_NC='\033[0m'

# 下载函数
_download() {
    local url="$1" target="$2"
    curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$target" 2>/dev/null ||
    wget -qO "$target" "$url" 2>/dev/null
}

# 下载到临时文件，校验成功后再替换目标，避免网络中断导致旧脚本损坏
_download_replace() {
    local url="$1" target="$2" temp_file
    temp_file=$(mktemp) || return 1

    if _download "$url" "$temp_file" && [ -s "$temp_file" ]; then
        mkdir -p "$(dirname "$target")" || {
            rm -f "$temp_file"
            return 1
        }
        mv "$temp_file" "$target"
        return $?
    fi

    rm -f "$temp_file"
    return 1
}

# 同步端口流量狗及Telegram通知模块，确保一次安装覆盖完整功能
_update_port_traffic_dog() {
    local failed=0

    echo -e "${_YELLOW}正在更新端口流量狗及Telegram通知模块...${_NC}"

    if _download_replace "$REPO_RAW_URL/port-traffic-dog.sh" "$PORT_TRAFFIC_DOG_PATH"; then
        chmod +x "$PORT_TRAFFIC_DOG_PATH"
        echo -e "  ${_GREEN}✓${_NC} port-traffic-dog.sh"
    else
        echo -e "  ${_RED}✗${_NC} port-traffic-dog.sh 下载失败"
        failed=1
    fi

    if _download_replace "$REPO_RAW_URL/notifications/telegram.sh" "$TELEGRAM_MODULE_PATH"; then
        chmod +x "$TELEGRAM_MODULE_PATH"
        echo -e "  ${_GREEN}✓${_NC} notifications/telegram.sh"
    else
        echo -e "  ${_RED}✗${_NC} notifications/telegram.sh 下载失败"
        failed=1
    fi

    return "$failed"
}

# 安装/更新脚本文件到系统（幂等）
_bootstrap() {
    echo -e "${_YELLOW}正在安装/更新脚本文件...${_NC}"

    mkdir -p "$LIB_DIR"

    # 下载入口脚本
    if _download_replace "$REPO_RAW_URL/xwPF.sh" "$INSTALL_DIR/xwPF.sh"; then
        chmod +x "$INSTALL_DIR/xwPF.sh"
        echo -e "  ${_GREEN}✓${_NC} xwPF.sh"
    else
        echo -e "  ${_RED}✗${_NC} xwPF.sh 下载失败"
        return 1
    fi

    # 下载所有模块
    local failed=0
    for f in "${LIB_FILES[@]}"; do
        if _download_replace "$REPO_RAW_URL/lib/$f" "$LIB_DIR/$f"; then
            echo -e "  ${_GREEN}✓${_NC} lib/$f"
        else
            echo -e "  ${_RED}✗${_NC} lib/$f 下载失败"
            failed=1
        fi
    done

    _update_port_traffic_dog || failed=1

    [ "$failed" -eq 1 ] && return 1

    # 创建快捷命令
    ln -sf "$INSTALL_DIR/xwPF.sh" "$SHORTCUT_PATH"
    echo -e "${_GREEN}✓ 快捷命令已创建: pf${_NC}"

    echo -e "${_GREEN}=== 脚本安装完成${_NC}"
    echo ""
}

# 加载模块
_load_libs() {
    if [ ! -d "$LIB_DIR" ] || [ ! -f "$LIB_DIR/core.sh" ]; then
        echo -e "${_RED}错误: 未找到模块目录，请先安装${_NC}"
        echo -e "${_BLUE}wget -qO- ${REPO_RAW_URL}/xwPF.sh | sudo bash -s install${_NC}"
        return 1
    fi

    for f in "${LIB_FILES[@]}"; do
        if [ -f "$LIB_DIR/$f" ]; then
            source "$LIB_DIR/$f"
        else
            echo -e "${_RED}错误: 缺少模块 $f${_NC}"
            return 1
        fi
    done
}

# 主入口
case "${1:-}" in
    install)
        [ "$(id -u)" -ne 0 ] && { echo -e "${_RED}错误: 需要 root 权限${_NC}"; exit 1; }
        _bootstrap || exit 1
        _load_libs || exit 1
        _SKIP_SCRIPT_UPDATE=1 smart_install
        ;;
    *)
        _load_libs || exit 1
        main "$@"
        ;;
esac
