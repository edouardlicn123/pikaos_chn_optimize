#!/bin/bash
set -e

echo "=== GitHub SSH 配置脚本 ==="
echo ""

# 1. 输入用户名和邮箱（默认用当前系统用户@主机名）
DEFAULT_USER="$(whoami)@$(hostname)"
DEFAULT_EMAIL="$(whoami)@$(hostname).host"

read -p "GitHub 用户名 [${DEFAULT_USER}]: " GIT_USER
GIT_USER="${GIT_USER:-$DEFAULT_USER}"

read -p "GitHub 邮箱   [${DEFAULT_EMAIL}]: " GIT_EMAIL
GIT_EMAIL="${GIT_EMAIL:-$DEFAULT_EMAIL}"

echo "→ 使用: 用户名=${GIT_USER}  邮箱=${GIT_EMAIL}"

git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"
echo "✓ git config 已设置"
echo ""

# 2. 生成 RSA 密钥
if [ -f ~/.ssh/id_rsa ]; then
  read -p "~/.ssh/id_rsa 已存在，覆盖？(y/N): " confirm
  if [ "$confirm" != "y" ]; then
    echo "跳过密钥生成，使用已有密钥"
  else
    ssh-keygen -t rsa -b 4096 -C "$GIT_EMAIL" -f ~/.ssh/id_rsa -N ""
    echo "✓ 新密钥已生成"
  fi
else
  ssh-keygen -t rsa -b 4096 -C "$GIT_EMAIL" -f ~/.ssh/id_rsa -N ""
  echo "✓ 密钥已生成"
fi
echo ""

# 3. 复制公钥到剪贴板并显示
echo "=== 你的公钥如下 ==="
cat ~/.ssh/id_rsa.pub
echo ""

if command -v wl-copy &>/dev/null; then
  cat ~/.ssh/id_rsa.pub | wl-copy
  echo "✓ 公钥已自动复制到剪贴板，可直接 Ctrl+V 粘贴"
elif command -v xclip &>/dev/null; then
  cat ~/.ssh/id_rsa.pub | xclip -selection clipboard
  echo "✓ 公钥已自动复制到剪贴板，可直接 Ctrl+V 粘贴"
else
  echo "⚠ 未检测到 wl-clipboard 或 xclip，请手动选中上方公钥复制"
  echo "  安装: sudo apt install wl-clipboard"
fi
echo ""

# 4. 打开 GitHub SSH 设置页
echo "正在打开 GitHub SSH 设置页面..."
xdg-open https://github.com/settings/keys 2>/dev/null || true
echo "→ 请在浏览器中将公钥粘贴并保存"
echo ""

# 5. 信任 github.com
echo "正在将 github.com 加入 known_hosts..."
ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null
echo "✓ github.com 已设为可信任"
echo ""

# 6. 验证连接
echo "=== 验证 SSH 连接 ==="
ssh -T git@github.com && echo "" || echo "（首次连接需输入 yes 确认）"

echo ""
echo "=== GitHub 配置完成 ==="
echo "用户名: $GIT_USER"
echo "邮箱:   $GIT_EMAIL"
echo "密钥:   ~/.ssh/id_rsa"
echo "公钥:   ~/.ssh/id_rsa.pub"
