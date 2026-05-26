#!/bin/bash

BASHRC="$HOME/.bashrc"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.jsonc"
DATE_TAG="$(date +%Y%m%d%H%M%S)"

# 代理块标记
BLOCK_START="# >>> v2rayN 代理配置 >>>"
BLOCK_END="# <<< v2rayN 代理配置 <<<"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
err()   { echo -e "${RED}✗${NC} $1"; }

# ──────────────────────────────────────
# 迁移旧版（删除 proxy_on/proxy_off 函数块）
# ──────────────────────────────────────
migrate_old_style() {
  if ! grep -q "function proxy_on()" "$BASHRC" 2>/dev/null; then
    return
  fi
  echo "  - 检测到旧版 proxy_on/proxy_off 函数，正在迁移..."
  awk '
    /^# v2rayN/ { skip = 1; n = 0 }
    skip {
      if (/^}$/) n++
      if (n >= 2) { skip = 0; next }
      next
    }
    { print }
  ' "$BASHRC" > "${BASHRC}.tmp" && mv "${BASHRC}.tmp" "$BASHRC"
  info "旧版函数已清理"
}

# ──────────────────────────────────────
# 追加新的代理块
# ──────────────────────────────────────
append_block() {
  cat >> "$BASHRC" << 'EOF'


# >>> v2rayN 代理配置 >>>
export HTTP_PROXY=http://127.0.0.1:10808
export HTTPS_PROXY=http://127.0.0.1:10808
export NO_PROXY=localhost,127.0.0.1
# <<< v2rayN 代理配置 <<<
EOF
}

# ──────────────────────────────────────
# 打开代理（取消注释）
# ──────────────────────────────────────
enable() {
  if ! grep -qF "$BLOCK_START" "$BASHRC" 2>/dev/null; then
    append_block
    info "代理块已添加"
    return
  fi
  sed -i 's|^[[:space:]]*# export HTTP_PROXY=|export HTTP_PROXY=|' "$BASHRC"
  sed -i 's|^[[:space:]]*# export HTTPS_PROXY=|export HTTPS_PROXY=|' "$BASHRC"
  sed -i 's|^[[:space:]]*# export NO_PROXY=|export NO_PROXY=|' "$BASHRC"
  info "代理已打开"
}

# ──────────────────────────────────────
# 关闭代理（注释掉）
# ──────────────────────────────────────
disable() {
  if ! grep -qF "$BLOCK_START" "$BASHRC" 2>/dev/null; then
    warn ".bashrc 中未找到代理块，无需关闭"
    return
  fi
  sed -i 's|^export HTTP_PROXY=|# export HTTP_PROXY=|' "$BASHRC"
  sed -i 's|^export HTTPS_PROXY=|# export HTTPS_PROXY=|' "$BASHRC"
  sed -i 's|^export NO_PROXY=|# export NO_PROXY=|' "$BASHRC"
  info "代理已关闭"
}

# ──────────────────────────────────────
# 状态检测
# ──────────────────────────────────────
status() {
  echo ""
  echo "━━━ 1. v2rayN 进程 ━━━"
  pgrep -x xray &>/dev/null \
    && info "xray 进程运行中" \
    || err "xray 进程未运行"

  echo ""
  echo "━━━ 2. 代理端口 127.0.0.1:10808 ━━━"
  code=$(curl -x http://127.0.0.1:10808 -s -o /dev/null -w '%{http_code}' \
    --connect-timeout 3 http://www.gstatic.com/generate_204 2>/dev/null || echo "000")
  [ "$code" = "204" ] && info "端口可达（返回 204）" \
                      || err "端口不可达（响应码: $code）"

  echo ""
  echo "━━━ 3. 当前环境变量 ━━━"
  if env | grep -qi proxy; then
    env | grep -i proxy | sed 's/^/  /'
  else
    echo "  （无代理相关环境变量）"
  fi

  echo ""
  echo "━━━ 4. .bashrc 代理配置 ━━━"
  if grep -qF "$BLOCK_START" "$BASHRC" 2>/dev/null; then
    grep -q "^export HTTP_PROXY=" "$BASHRC" 2>/dev/null \
      && info ".bashrc 代理块存在且已启用" \
      || warn ".bashrc 代理块存在但已被注释"
  else
    warn ".bashrc 中无代理块"
  fi
}

# ──────────────────────────────────────
# 确保 opencode.jsonc 有注释
# ──────────────────────────────────────
ensure_opencode_config() {
  if [ -f "$OPENCODE_CONFIG" ] && ! grep -q "网络代理通过环境变量配置" "$OPENCODE_CONFIG" 2>/dev/null; then
    cp "$OPENCODE_CONFIG" "$OPENCODE_CONFIG.bak.$DATE_TAG"
    sed -i 's|^[[:space:]]*}$|  // 网络代理通过环境变量配置（opencode 原生支持）：\n  //   HTTP_PROXY=http://127.0.0.1:10808\n  //   HTTPS_PROXY=http://127.0.0.1:10808\n  //   NO_PROXY=localhost,127.0.0.1\n}|' "$OPENCODE_CONFIG"
    info "opencode.jsonc 已添加注释"
  fi
}

# ──────────────────────────────────────
# 初始化（一次性迁移）
# ──────────────────────────────────────
init_once() {
  # 备份
  cp "$BASHRC" "$BASHRC.bak.$DATE_TAG"
  echo "  ✓ 已备份 .bashrc → .bashrc.bak.$DATE_TAG"

  migrate_old_style
  ensure_opencode_config
}

# ══════════════════════════════════════
# 主菜单
# ══════════════════════════════════════
while true; do
  echo ""
  echo "=== OpenCode 代理管理 ==="
  echo "1) 检测状态"
  echo "2) 打开代理"
  echo "3) 关闭代理"
  echo "q) 退出"
  echo ""
  if ! read -p "请选择 [1-3/q]: " choice; then echo; exit 0; fi

  case "$choice" in
    1) status ;;
    2)
      if ! grep -qF "$BLOCK_START" "$BASHRC" 2>/dev/null; then
        init_once
      fi
      enable
      echo ""
      echo "正在重新加载 .bashrc ..."
      source ~/.bashrc && echo "已自动执行 source ~/.bashrc"
      ;;
    3)
      if grep -qF "$BLOCK_START" "$BASHRC" 2>/dev/null; then
        disable
      else
        warn "从未配置过代理，无需关闭"
      fi
      echo ""
      echo "正在重新加载 .bashrc ..."
      source ~/.bashrc && echo "已自动执行 source ~/.bashrc"
      ;;
    q|Q) echo "退出。"; exit 0 ;;
    *) echo "无效输入，请重新选择" ;;
  esac
done
