#!/bin/bash

#
# PikaOS 系统优化及中文环境设置工具
#

# ── 颜色 ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ── 日志 ──
LOG_FILE=""
setup_log() {
  local dir
  dir="$(cd "$(dirname "$0")" && pwd)"
  LOG_FILE="$dir/setup_pikaos_$(date +%Y%m%d_%H%M%S).log"
  {
    echo "════════════════════════════════════════════"
    echo "  PikaOS 系统设置工具 — 操作日志"
    echo "════════════════════════════════════════════"
    echo "  开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  用户:     $(whoami)@$(hostname)"
    echo "  脚本:    $0"
    echo "════════════════════════════════════════════"
    echo ""
  } > "$LOG_FILE"
}

ts() { date '+%H:%M:%S'; }

info()  { local m="$1"; echo -e "${GREEN}✓${NC} $m"; echo "[$(ts)] ✓ $m" >> "$LOG_FILE"; }
warn()  { local m="$1"; echo -e "${YELLOW}⚠${NC} $m"; echo "[$(ts)] ⚠ $m" >> "$LOG_FILE"; }
err()   { local m="$1"; echo -e "${RED}✗${NC} $m"; echo "[$(ts)] ✗ $m" >> "$LOG_FILE"; }
hdr()   { local m="$1"; echo -e "${CYAN}━━━ $m ━━━${NC}"; echo "" >> "$LOG_FILE"; echo "── $m ──" >> "$LOG_FILE"; }
logcmd() { echo "[$(ts)] ▶ $1" >> "$LOG_FILE"; }
lograw() { echo "[$(ts)]   $1" >> "$LOG_FILE"; }

# ── Sudo 缓存 ──
init_sudo() {
  echo "请输入 sudo 密码以继续..."
  sudo -v || { err "sudo 验证失败"; exit 1; }
  while true; do sudo -v; sleep 60; done &
  SUDO_PID=$!
  logcmd "sudo 凭证已缓存"
}

cleanup() {
  [[ -n "$_cleaned" ]] && return; _cleaned=1
  kill "$SUDO_PID" 2>/dev/null
  if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
    echo "" >> "$LOG_FILE"
    echo "══ 结束时间: $(date '+%Y-%m-%d %H:%M:%S') ══" >> "$LOG_FILE"
  fi
}
trap cleanup EXIT
trap 'cleanup; echo ""; echo "已退出。"; exit 1' INT TERM

# ── 工具函数 ──
confirm() {
  local prompt="${1:-继续？}" default="${2:-Y}"
  local display_default
  [[ "$default" == "Y" ]] && display_default="Y/n" || display_default="y/N"
  read -r -p "$prompt [$display_default]: " ans
  ans=${ans:-$default}
  echo "[$(ts)] ⚙ 用户选择: $prompt → $ans" >> "$LOG_FILE"
  [[ "$ans" =~ ^[Yy] ]]
}

confirm_no() {
  local prompt="${1:-继续？}"
  read -r -p "$prompt [y/N]: " ans
  ans=${ans:-N}
  echo "[$(ts)] ⚙ 用户选择: $prompt → $ans" >> "$LOG_FILE"
  [[ "$ans" =~ ^[Yy] ]]
}

prompt_value() {
  local prompt="$1" default="$2" cur="$3"
  local display=""
  [[ -n "$cur" ]] && display=" [当前: $cur, 建议: $default]"
  read -r -p "$prompt${display}: " val
  val="${val:-$default}"
  echo "[$(ts)] ⚙ 输入参数: $prompt → $val" >> "$LOG_FILE"
  echo "$val"
}

opt_ask() {
  local label="$1" desc="$2" cur="$3" suggest="$4" act="$5" skip="$6"
  local default="${7:-1}"
  echo ""
  echo "  ${label}"
  echo "  → ${desc}"
  echo "  → 当前: ${cur}  建议: ${suggest}"
  echo "  1) ${act}"
  echo "  2) ${skip}"
  read -r -p "  请选择 [1/2] (默认 ${default}): " ans
  ans=${ans:-$default}
  echo "[$(ts)] ⚙ ${label}: 选择 ${ans}" >> "$LOG_FILE"
  [[ "$ans" == "1" ]]
}

svc_ask() {
  local label="$1" desc="$2" state="$3"
  local status="${4:-未安装}"
  [[ "$status" == "not-found" ]] && return 1
  local icon="○ 已停止"
  systemctl --user is-active "$label" &>/dev/null && icon="● 运行中"
  systemctl is-active "$label" &>/dev/null 2>/dev/null && icon="● 运行中"
  echo ""
  echo "  ${label}"
  echo "  → ${desc}"
  echo "  → ${icon}  ■ ${status}"
  if [[ "$status" == "masked" ]]; then
    echo "  1) 取消屏蔽(重新启用)"
    echo "  2) 保持屏蔽"
  elif [[ "$status" == "disabled" ]]; then
    echo "  1) 重新启用(取消禁用)"
    echo "  2) 保持禁用"
  else
    echo "  1) 禁用"
    echo "  2) 保持当前状态"
  fi
  read -r -p "  请选择 [1/2] (默认 1): " ans
  ans=${ans:-1}
  echo "[$(ts)] ⚙ ${label}: 选择 ${ans}" >> "$LOG_FILE"
  [[ "$ans" == "1" ]]
}

# ════════════════════════════════════════
# 1. 系统汉化美化
# ════════════════════════════════════════
i18n_setup() {
  echo ""
  hdr "系统汉化美化"
  echo "将执行以下操作："
  echo "  1. 配置 fcitx5 环境变量（~/.config/environment.d/10-fcitx5.conf）"
  echo "  2. 配置 CJK 字体回退优先级（~/.config/fontconfig/fonts.conf）"
  echo "  3. 配置 Shell 别名（~/.bash_aliases）"
  echo "  4. 配置 fcitx5 自启动（~/.config/autostart/fcitx5.desktop）"
  echo ""

  if ! confirm "是否执行以上操作" "Y"; then
    info "已取消"
    return
  fi

  # 1. fcitx5 环境变量
  echo ""
  echo "→ [1/4] 配置 fcitx5 环境变量 ..."
  logcmd "mkdir -p ~/.config/environment.d"
  mkdir -p "$HOME/.config/environment.d"
  logcmd "写入 ~/.config/environment.d/10-fcitx5.conf"
  cat > "$HOME/.config/environment.d/10-fcitx5.conf" << 'EOF'
# Wayland 使用 text-input-v3 协议原生输入法
# GTK_IM_MODULE 必须留空，否则与 COSMIC/Wayland 冲突
GTK_IM_MODULE=
QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx5
SDL_IM_MODULE=fcitx5
CLUTTER_IM_MODULE=
EOF
  info "fcitx5 环境变量已写入"

  # 2. CJK 字体回退
  echo ""
  echo "→ [2/4] 配置 CJK 字体回退优先级 ..."
  logcmd "mkdir -p ~/.config/fontconfig"
  mkdir -p "$HOME/.config/fontconfig"
  logcmd "写入 ~/.config/fontconfig/fonts.conf"
  cat > "$HOME/.config/fontconfig/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font</family>
      <family>Noto Sans Mono CJK SC</family>
      <family>Noto Sans Mono CJK TC</family>
    </prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans CJK SC</family>
      <family>Noto Sans CJK TC</family>
    </prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif CJK SC</family>
      <family>Noto Serif CJK TC</family>
    </prefer>
  </alias>
  <alias>
    <family>JetBrainsMono Nerd Font</family>
    <prefer>
      <family>JetBrainsMono Nerd Font</family>
      <family>Noto Sans Mono CJK SC</family>
    </prefer>
  </alias>
</fontconfig>
EOF
  logcmd "fc-cache -fv 更新字体缓存"
  fc-cache -fv &>/dev/null && info "fontconfig 已写入，缓存已更新" || warn "fc-cache 执行失败"

  # 3. Shell 别名
  echo ""
  echo "→ [3/4] 配置 Shell 别名 ..."
  logcmd "写入 ~/.bash_aliases"
  cat > "$HOME/.bash_aliases" << 'EOF'
# ls
alias ll='ls -lFh'
alias la='ls -lAFh'
alias l='ls -CF'
# safety
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
# navigation
alias ..='cd ..'
alias ...='cd ../..'
# grep
alias grep='grep --color=auto'
# disk usage
alias df='df -h'
alias du='du -h'
# tree
alias tree='tree -C -I "node_modules|.git|.cache"'
# opencode
alias oc='opencode'
EOF
  info "Shell 别名已写入 ~/.bash_aliases"

  # 4. fcitx5 自启动
  echo ""
  echo "→ [4/4] 配置 fcitx5 自启动 ..."
  logcmd "mkdir -p ~/.config/autostart"
  mkdir -p "$HOME/.config/autostart"
  logcmd "写入 ~/.config/autostart/fcitx5.desktop"
  cat > "$HOME/.config/autostart/fcitx5.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5
Terminal=false
NoDisplay=true
EOF
  info "fcitx5 自启动已配置"

  echo ""
  info "系统汉化美化操作完成"
  echo "  提示：重新登录后环境变量生效，新 shell 自动加载别名"
}

# ════════════════════════════════════════
# 2. 系统优化
# ════════════════════════════════════════

# ── 2.1 内存与交换优化 ──
sysopt_memory() {
  echo ""
  hdr "内存与交换优化"
  local total_gb
  total_gb=$(awk '/MemTotal/{printf "%.1f", $2/1024^2}' /proc/meminfo)
  info "检测中，总内存: ${total_gb} GiB ..."

  local cur_swappiness
  cur_swappiness=$(sysctl -n vm.swappiness 2>/dev/null) || cur_swappiness="?"

  local have_zram=false zram_algo="" zram_percent=""
  if command -v zramctl &>/dev/null && zramctl --noheadings 2>/dev/null | grep -q .; then
    have_zram=true
    zram_algo=$(zramctl -o ALGO --noheadings 2>/dev/null | head -1)
  fi
  if [[ -f /etc/default/zramswap ]]; then
    local f_algo f_percent
    f_algo=$(grep -oP '^ALGO=\K.*' /etc/default/zramswap 2>/dev/null)
    f_percent=$(grep -oP '^PERCENT=\K.*' /etc/default/zramswap 2>/dev/null)
    [[ -n "$f_algo" ]] && zram_algo="$f_algo"
    [[ -n "$f_percent" ]] && zram_percent="$f_percent"
  fi

  lograw "总内存: ${total_gb} GiB"
  lograw "vm.swappiness: ${cur_swappiness}"
  $have_zram && lograw "ZRAM 算法: ${zram_algo:-lz4}" && lograw "ZRAM 容量: ${zram_percent:-100}%"
  lograw "---"

  # ── swappiness ──
  if opt_ask \
    "vm.swappiness" \
    "控制系统使用交换的倾向，越低越倾向于使用物理内存。桌面/笔记本建议 10-20 以减少 Swap 写入，延长 SSD 寿命" \
    "$cur_swappiness" "20" \
    "调整为 20（推荐）" \
    "保持当前值 $cur_swappiness"; then
    if [[ "$cur_swappiness" != "20" ]]; then
      logcmd "sysctl -w vm.swappiness=20"
      sudo sysctl -w vm.swappiness=20 &>/dev/null
      logcmd "写入 /etc/sysctl.d/99-swappiness.conf"
      echo "vm.swappiness=20" | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null
      info "swappiness 已设为 20"
    else
      info "swappiness 已为 20，无需修改"
    fi
  fi

  # ── ZRAM 算法 ──
  if $have_zram || [[ -f /etc/default/zramswap ]]; then
    local cur_algo_display="${zram_algo:-lz4}"
    if opt_ask \
      "ZRAM 压缩算法" \
      "ZRAM 是内存中的压缩交换分区。zstd 算法压缩率更高（~40%），比默认 lz4 节省更多内存，现代 CPU 可硬件加速" \
      "$cur_algo_display" "zstd" \
      "切换为 zstd（推荐）" \
      "保持 $cur_algo_display"; then
      if [[ "$cur_algo_display" != "zstd" ]]; then
        logcmd "sed -i s/ALGO=.*/ALGO=zstd/ /etc/default/zramswap"
        sudo sed -i 's/^ALGO=.*/ALGO=zstd/' /etc/default/zramswap 2>/dev/null
      else
        info "ZRAM 算法已为 zstd"
      fi
    fi

    # ── ZRAM 容量 ──
    local cur_percent_display="${zram_percent:-100}"
    if opt_ask \
      "ZRAM 容量百分比" \
      "ZRAM 占物理内存的百分比。40% 是平衡点：内存足够时限制 ZRAM 大小以节约资源，内存不足时也不会过度膨胀" \
      "${cur_percent_display}%" "40%" \
      "设为 40%（推荐）" \
      "保持 ${cur_percent_display}%"; then
      if [[ "${zram_percent:-100}" != "40" ]]; then
        logcmd "sed -i s/PERCENT=.*/PERCENT=40/ /etc/default/zramswap"
        sudo sed -i 's/^PERCENT=.*/PERCENT=40/' /etc/default/zramswap 2>/dev/null
        logcmd "systemctl restart zramswap"
        sudo systemctl restart zramswap &>/dev/null && info "ZRAM 已重启生效" || warn "ZRAM 重启失败，重启后生效"
      else
        info "ZRAM 容量已为 40%"
      fi
    fi
  fi
}

# ── 2.2 内核参数调优 ──
sysopt_kernel() {
  echo ""
  hdr "内核参数调优"

  local cur_vfs cur_numa numa_nodes
  cur_vfs=$(sysctl -n vm.vfs_cache_pressure 2>/dev/null) || cur_vfs="?"
  cur_numa=$(sysctl -n kernel.numa_balancing 2>/dev/null) || cur_numa="?"
  numa_nodes=$(lscpu 2>/dev/null | grep -oP 'NUMA node\(s\):\s*\K\d+')
  [[ -z "$numa_nodes" ]] && numa_nodes="1"

  lograw "vm.vfs_cache_pressure: ${cur_vfs}"
  lograw "kernel.numa_balancing: ${cur_numa}"
  lograw "NUMA 节点数: ${numa_nodes}"

  # ── vfs_cache_pressure ──
  if opt_ask \
    "vm.vfs_cache_pressure" \
    "控制内核回收目录/索引节点 (dentry/inode) 缓存的力度。默认 100，降低到 50 可让缓存保留更久，加快文件系统重复访问速度" \
    "$cur_vfs" "50" \
    "调整为 50（推荐）" \
    "保持当前值 $cur_vfs"; then
    if [[ "$cur_vfs" != "50" ]]; then
      logcmd "sysctl -w vm.vfs_cache_pressure=50"
      sudo sysctl -w vm.vfs_cache_pressure=50 &>/dev/null
      logcmd "写入 /etc/sysctl.d/99-cache.conf"
      echo "vm.vfs_cache_pressure=50" | sudo tee /etc/sysctl.d/99-cache.conf >/dev/null
      info "vfs_cache_pressure 已设为 50"
    else
      info "vfs_cache_pressure 已为 50"
    fi
  fi

  # ── numa_balancing ──
  if [[ "$numa_nodes" -gt 1 ]]; then
    local numa_desc="NUMA 平衡会在多 NUMA 节点间自动迁移内存和任务以优化局部性。桌面/笔记本单用户场景下，自动平衡反而带来额外开销和延迟，建议关闭"
  else
    local numa_desc="系统仅有单 NUMA 节点，NUMA 平衡无实际作用，建议关闭以节省内核开销"
  fi
  if opt_ask \
    "kernel.numa_balancing" \
    "$numa_desc" \
    "$cur_numa" "0" \
    "关闭（推荐）" \
    "保持当前值 $cur_numa"; then
    if [[ "$cur_numa" != "0" ]]; then
      logcmd "sysctl -w kernel.numa_balancing=0"
      sudo sysctl -w kernel.numa_balancing=0 &>/dev/null
      logcmd "追加 kernel.numa_balancing=0 到 /etc/sysctl.d/99-cache.conf"
      echo "kernel.numa_balancing=0" | sudo tee -a /etc/sysctl.d/99-cache.conf >/dev/null
      info "numa_balancing 已关闭"
    else
      info "numa_balancing 已为 0"
    fi
  fi

  echo ""
  info "内核参数调优完成"
}

# ── 2.3 服务精简 ──
sysopt_services() {
  echo ""
  hdr "服务精简"

  local -a all_services=(
    "evolution-addressbook-factory.service:user:Evolution 地址簿后台（GNOME 组件，COSMIC 下不需要）"
    "evolution-calendar-factory.service:user:Evolution 日历后台（GNOME 组件，COSMIC 下不需要）"
    "evolution-source-registry.service:user:Evolution 源注册（GNOME 组件，COSMIC 下不需要）"
    "evolution-user-prompter.service:user:Evolution 用户提示（GNOME 组件，COSMIC 下不需要）"
    "app-geoclue-demo-agent@autostart.service:user:位置服务演示代理（桌面用户通常不需要位置演示）"
    "at-spi-dbus-bus.service:user:无障碍服务，GTK 应用的剪贴板和拖放依赖。某些应用可能依赖它才能正常工作"
    "app-polkit-mate-authentication-agent-1@autostart.service:user:MATE 桌面认证代理，COSMIC 下的残留"
    "app-pika-welcome-autostart@autostart.service:user:PikaOS 首次启动欢迎页面（单次使用后可禁用）"
    "hypridle:user:Hyprland 空闲管理守护进程，COSMIC 桌面有自己的空闲管理系统"
    "brltty:system:盲文终端支持，桌面用户一般不需要"
    "avahi-daemon:system:mDNS/Zeroconf 局域网设备发现协议，单机桌面用户无需此服务"
    "rsyslog:system:传统 Syslog 日志服务，已被 systemd-journald 完全替代"
  )

  for entry in "${all_services[@]}"; do
    local svc="${entry%%:*}" rest="${entry#*:}"
    local scope="${rest%%:*}" desc="${rest#*:}"

    local state="" active=""
    if [[ "$scope" == "user" ]]; then
      state=$(systemctl --user is-enabled "$svc" 2>/dev/null || echo "not-found")
      systemctl --user is-active "$svc" &>/dev/null 2>/dev/null && active="running"
    else
      state=$(systemctl is-enabled "$svc" 2>/dev/null || echo "not-found")
      systemctl is-active "$svc" &>/dev/null 2>/dev/null && active="running"
    fi

    [[ "$state" == "not-found" ]] && state="未安装"

    lograw "服务 ${svc} (${scope}): ${state}"

    if [[ "$state" == "未安装" ]]; then
      warn "${svc} 未安装，跳过"
      continue
    fi

    if svc_ask "$svc" "$desc" "$active" "$state"; then
      if [[ "$scope" == "user" ]]; then
        if [[ "$state" == "masked" ]]; then
          logcmd "systemctl --user unmask ${svc}"
          systemctl --user unmask "$svc" &>/dev/null
          logcmd "systemctl --user enable ${svc}"
          systemctl --user enable "$svc" &>/dev/null
          info "${svc} 已取消屏蔽并启用"
        else
          logcmd "systemctl --user mask ${svc}"
          systemctl --user mask "$svc" &>/dev/null
          logcmd "systemctl --user stop ${svc}"
          systemctl --user stop "$svc" &>/dev/null
          info "${svc} 已屏蔽"
        fi
      else
        if [[ "$state" == "masked" ]]; then
          logcmd "sudo systemctl unmask ${svc}"
          sudo systemctl unmask "$svc" &>/dev/null
          logcmd "sudo systemctl enable ${svc}"
          sudo systemctl enable "$svc" &>/dev/null
          info "${svc} 已取消屏蔽并启用"
        elif [[ "$state" == "disabled" ]]; then
          logcmd "sudo systemctl enable ${svc}"
          sudo systemctl enable "$svc" &>/dev/null
          info "${svc} 已重新启用"
        else
          logcmd "sudo systemctl disable --now ${svc}"
          sudo systemctl disable --now "$svc" &>/dev/null
          if [[ "$svc" == "avahi-daemon" ]]; then
            logcmd "sudo systemctl mask avahi-daemon"
            sudo systemctl mask avahi-daemon &>/dev/null
          fi
          info "${svc} 已禁用"
        fi
      fi
    fi
  done

  # ── Evolution 日历提醒 autostart 覆盖 ──
  local alarm_desktop="org.gnome.Evolution-alarm-notify.desktop"
  local alarm_src="/etc/xdg/autostart/${alarm_desktop}"
  local alarm_dst="$HOME/.config/autostart/${alarm_desktop}"
  if [[ -f "$alarm_src" ]]; then
    if [[ -f "$alarm_dst" ]] && grep -q '^Hidden=true' "$alarm_dst"; then
      lograw "Evolution 日历提醒: 已隐藏（autostart 覆盖存在）"
    else
      echo ""
      echo "  ${alarm_desktop}"
      echo "  → Evolution 日历提醒通知。系统级 autostart 文件，COSMIC 下不需要此提醒"
      echo "  → 当前: $( [[ -f "$alarm_dst" ]] && echo '已覆盖但未生效' || echo '未隐藏' )"
      echo "  1) 隐藏（创建 Hidden=true 覆盖）"
      echo "  2) 保持当前"
      read -r -p "  请选择 [1/2] (默认 1): " ans
      ans=${ans:-1}
      echo "[$(ts)] ⚙ ${alarm_desktop}: 选择 ${ans}" >> "$LOG_FILE"
      if [[ "$ans" == "1" ]]; then
        logcmd "创建 ${alarm_dst} (Hidden=true)"
        mkdir -p "$HOME/.config/autostart"
        cat > "$alarm_dst" << 'HEOF'
[Desktop Entry]
Hidden=true
HEOF
        info "Evolution 日历提醒已隐藏"
      fi
    fi
  else
    lograw "Evolution 日历提醒: 未安装（/etc/xdg/autostart/ 无此文件，跳过）"
  fi

  echo ""
  info "服务精简完成"
}

# ── 2.4 日志优化 ──
sysopt_journal() {
  echo ""
  hdr "日志优化"

  local cur_usage cur_limit
  cur_usage=$(journalctl --disk-usage 2>/dev/null | awk '{print $NF}' || echo "?")
  cur_limit=$(grep -oP '^SystemMaxUse=\K.*' /etc/systemd/journald.conf 2>/dev/null || grep -oP '^SystemMaxUse=\K.*' /etc/systemd/journald.conf.d/*.conf 2>/dev/null)
  [[ -z "$cur_limit" ]] && cur_limit="无限制"

  lograw "当前日志占用: ${cur_usage}"
  lograw "当前配置上限: ${cur_limit}"

  if opt_ask \
    "systemd-journald 日志上限" \
    "控制系统日志占用磁盘的最大容量。默认无限制，日志可能积累到数 GB。设置 200M 可防止日志撑满 /var 分区，同时保留近期日志供排查" \
    "$cur_limit" "200M" \
    "设为 200M（推荐）" \
    "保持 ${cur_limit}"; then
    if [[ "$cur_limit" != "200M" ]]; then
      logcmd "追加 SystemMaxUse=200M 到 /etc/systemd/journald.conf"
      echo "SystemMaxUse=200M" | sudo tee -a /etc/systemd/journald.conf >/dev/null
      logcmd "systemctl restart systemd-journald"
      sudo systemctl restart systemd-journald &>/dev/null
      info "日志上限已设为 200M"
    else
      info "日志上限已为 200M"
    fi
  fi
}

# ── 2.5 NVIDIA 电源管理 ──
sysopt_nvidia() {
  echo ""
  hdr "NVIDIA 电源管理"

  if ! command -v nvidia-smi &>/dev/null && ! lsmod | grep -q nvidia; then
    warn "未检测到 NVIDIA 显卡"
    read -r -p "  按 Enter 返回"
    return
  fi

  local nv_conf="/etc/modprobe.d/nvidia-options.conf"
  local cur_preserve=false cur_s0ix=false

  if [[ -f "$nv_conf" ]]; then
    grep -qP '^\s*options\s+nvidia\s+NVreg_PreserveVideoMemoryAllocations=1' "$nv_conf" && cur_preserve=true
    grep -qP '^\s*options\s+nvidia\s+NVreg_EnableS0ixPowerManagement=1' "$nv_conf" && cur_s0ix=true
  fi

  local gpu_name
  gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  [[ -z "$gpu_name" ]] && gpu_name="NVIDIA GPU"

  lograw "GPU: ${gpu_name}"
  lograw "PreserveVideoMemoryAllocations: $($cur_preserve && echo '已启用' || echo '未启用')"
  lograw "EnableS0ixPowerManagement: $($cur_s0ix && echo '已启用' || echo '未启用')"

  local preserve_cur=$($cur_preserve && echo "已启用" || echo "未启用")
  local s0ix_cur=$($cur_s0ix && echo "已启用" || echo "未启用")

  if opt_ask \
    "NVreg_PreserveVideoMemoryAllocations" \
    "在系统休眠或挂起时保留 NVIDIA 显存内容。不启用可能导致休眠唤醒后 GPU 应用崩溃或黑屏，建议启用" \
    "$preserve_cur" "启用" \
    "启用（推荐）" \
    "保持 ${preserve_cur}"; then
    if ! $cur_preserve; then
      if [[ -f "$nv_conf" ]]; then
        sudo sed -i 's/^#\s*options nvidia NVreg_PreserveVideoMemoryAllocations=1/options nvidia NVreg_PreserveVideoMemoryAllocations=1/' "$nv_conf" 2>/dev/null
      fi
      if ! grep -qP '^\s*options\s+nvidia\s+NVreg_PreserveVideoMemoryAllocations=1' "$nv_conf" 2>/dev/null; then
        echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee -a "$nv_conf" >/dev/null
      fi
      logcmd "已启用 NVreg_PreserveVideoMemoryAllocations"
      info "PreserveVideoMemoryAllocations 已启用"
    else
      info "PreserveVideoMemoryAllocations 已启用"
    fi
  fi

  if opt_ask \
    "NVreg_EnableS0ixPowerManagement" \
    "启用现代 S0ix 待机状态下的 NVIDIA 电源管理。允许 GPU 在系统浅睡眠时进入低功耗模式，延长笔记本电池续航" \
    "$s0ix_cur" "启用" \
    "启用（推荐）" \
    "保持 ${s0ix_cur}"; then
    if ! $cur_s0ix; then
      if [[ -f "$nv_conf" ]]; then
        sudo sed -i 's/^#\s*options nvidia NVreg_EnableS0ixPowerManagement=1/options nvidia NVreg_EnableS0ixPowerManagement=1/' "$nv_conf" 2>/dev/null
      fi
      if ! grep -qP '^\s*options\s+nvidia\s+NVreg_EnableS0ixPowerManagement=1' "$nv_conf" 2>/dev/null; then
        echo "options nvidia NVreg_EnableS0ixPowerManagement=1" | sudo tee -a "$nv_conf" >/dev/null
      fi
      logcmd "已启用 NVreg_EnableS0ixPowerManagement"
      info "EnableS0ixPowerManagement 已启用"
    else
      info "EnableS0ixPowerManagement 已启用"
    fi
  fi

  # ── nvidia-vaapi-env.sh 清理 ──
  local nv_env="/etc/profile.d/nvidia-vaapi-env.sh"
  if [[ -f "$nv_env" ]]; then
    local cur_moz=false cur_vaapi=false cur_nvd=false cur_egl=false
    grep -q '^export MOZ_DISABLE_RDD_SANDBOX=1' "$nv_env" && cur_moz=true
    grep -q '^export LIBVA_DRIVER_NAME=nvidia' "$nv_env" && cur_vaapi=true
    grep -q '^export NVD_BACKEND=direct' "$nv_env" && cur_nvd=true
    grep -q '^export EGL_PLATFORM=wayland' "$nv_env" && cur_egl=true

    local env_cur=""
    if $cur_moz; then env_cur+="MOZ_DISABLE_RDD_SANDBOX(待移除) "; else env_cur+="MOZ_DISABLE_RDD_SANDBOX ✓ "; fi
    if $cur_vaapi; then env_cur+="LIBVA_DRIVER_NAME ✓ "; else env_cur+="LIBVA_DRIVER_NAME ✗ "; fi
    if $cur_nvd; then env_cur+="NVD_BACKEND ✓ "; else env_cur+="NVD_BACKEND ✗ "; fi
    if $cur_egl; then env_cur+="EGL_PLATFORM ✓ "; else env_cur+="EGL_PLATFORM ✗ "; fi

    if opt_ask \
      "nvidia-vaapi-env.sh" \
      "清理 /etc/profile.d/nvidia-vaapi-env.sh：
  • 移除 MOZ_DISABLE_RDD_SANDBOX=1（禁用 Firefox 沙盒，降低浏览器安全性）
  • 确保 LIBVA_DRIVER_NAME=nvidia（VA-API 驱动选择）
  • 确保 NVD_BACKEND=direct（NVIDIA 后端模式）
  • 确保 EGL_PLATFORM=wayland（EGL 平台选择）
  这三项是 NVIDIA + Wayland 下硬件视频加速必需的。移除 MOZ_DISABLE_RDD_SANDBOX 后如需 Firefox 硬解，可在 shell 中单独 export" \
      "$env_cur" "全部就绪" \
      "清理（推荐）" \
      "保持当前"; then
      if $cur_moz; then
        sudo sed -i '/^export MOZ_DISABLE_RDD_SANDBOX/d' "$nv_env"
      fi
      $cur_vaapi || echo 'export LIBVA_DRIVER_NAME=nvidia' | sudo tee -a "$nv_env" >/dev/null
      $cur_nvd || echo 'export NVD_BACKEND=direct' | sudo tee -a "$nv_env" >/dev/null
      $cur_egl || echo 'export EGL_PLATFORM=wayland' | sudo tee -a "$nv_env" >/dev/null
      logcmd "nvidia-vaapi-env.sh 已清理"
      info "nvidia-vaapi-env.sh 已清理"
    fi
  else
    lograw "nvidia-vaapi-env.sh: 不存在，跳过"
  fi

  local changed=false
  if ! $cur_preserve || ! $cur_s0ix; then
    if grep -qP '^\s*options\s+nvidia\s+NVreg_' "$nv_conf" 2>/dev/null; then
      changed=true
    fi
  fi
  if $changed; then
    logcmd "update-initramfs -u"
    sudo update-initramfs -u &>/dev/null
    echo ""
    info "NVIDIA 电源配置已更新（重启后生效）"
  fi
}

# ── 系统优化菜单 ──
sysopt_menu() {
  while true; do
    echo ""
    hdr "系统优化"
    echo "1) 内存与交换优化"
    echo "2) 内核参数调优"
    echo "3) 服务精简"
    echo "4) 日志优化"
    echo "5) NVIDIA 电源管理"
    echo "b) 返回主菜单"
    echo ""
    read -r -p "请选择 [1-5/b]: " choice
    echo "[$(ts)] ⚙ 菜单选择: 系统优化 → $choice" >> "$LOG_FILE"
    case "$choice" in
      1) sysopt_memory ;;
      2) sysopt_kernel ;;
      3) sysopt_services ;;
      4) sysopt_journal ;;
      5) sysopt_nvidia ;;
      b|B) break ;;
      *) warn "无效输入" ;;
    esac
  done
}

# ════════════════════════════════════════
# 3. 软件推荐
# ════════════════════════════════════════

# ── 3.1 微信 ──
soft_wechat_download() {
  local url="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb"
  local deb="/tmp/WeChatLinux_x86_64.deb"

  logcmd "下载微信 Linux 版"
  wget -c -O "$deb" "$url" || { err "下载失败"; return 1; }
  echo "$deb"
}

soft_wechat() {
  echo ""
  hdr "安装微信 WeChat"
  local local_deb="$HOME/下载/WeChatLinux_x86_64.deb"
  local deb_path=""

  if ! confirm "安装微信 WeChat？" "Y"; then
    info "已取消"
    return
  fi

  # 尝试本地安装包
  if [[ -f "$local_deb" ]]; then
    echo "→ 检测到本地安装包: WeChatLinux_x86_64.deb"
    if confirm "使用本地安装包" "Y"; then
      deb_path="$local_deb"
    fi
  fi

  # 本地不存在或用户拒绝 → 从官网下载
  if [[ -z "$deb_path" ]]; then
    echo "→ 正在从官网下载最新版本..."
    deb_path=$(soft_wechat_download)
    if [[ -z "$deb_path" || ! -f "$deb_path" ]]; then
      err "下载失败，请手动访问 https://linux.weixin.qq.com/ 下载"
      return
    fi
  fi

  logcmd "dpkg -i $(basename "$deb_path")"
  sudo dpkg -i "$deb_path" && info "微信安装成功" || {
    warn "安装微信时出现依赖问题，尝试修复..."
    logcmd "apt install -f -y"
    sudo apt install -f -y && info "依赖已修复，微信安装完成" || err "微信安装失败"
  }
  rm -f /tmp/WeChatLinux_x86_64.deb
}

# ── 3.2 VS Code ──
soft_vscode() {
  echo ""
  hdr "安装 Visual Studio Code"

  if command -v code &>/dev/null; then
    info "VS Code 已安装"
    return
  fi

  echo ""
  echo "安装方式："
  echo "  1) 添加微软源（推荐，自动更新）"
  echo "  2) 下载 deb 安装"
  local method
  read -r -p "请选择 [1/2] (默认 1): " method
  method=${method:-1}
  echo "[$(ts)] ⚙ 用户选择: VS Code 安装方式 → $method" >> "$LOG_FILE"

  case "$method" in
    1)
      logcmd "下载微软 GPG 密钥并添加源"
      wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
      sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/trusted.gpg.d/
      rm -f /tmp/packages.microsoft.gpg
      sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
      logcmd "apt update && apt install code"
      sudo apt update -q 2>/dev/null
      sudo apt install -y code && info "VS Code 安装成功" || err "VS Code 安装失败"
      ;;
    2)
      logcmd "下载 VS Code deb 包"
      wget -O /tmp/code_latest_amd64.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
      logcmd "dpkg -i code_latest_amd64.deb"
      sudo dpkg -i /tmp/code_latest_amd64.deb && info "VS Code 安装成功" || {
        logcmd "apt install -f -y"
        sudo apt install -f -y && info "VS Code 安装成功" || err "VS Code 安装失败"
      }
      rm -f /tmp/code_latest_amd64.deb
      ;;
    *)
      warn "无效选择，取消"
      ;;
  esac
}

# ── 3.3 百度网盘 ──
soft_baidu() {
  echo ""
  hdr "安装百度网盘"

  if command -v baidunetdisk &>/dev/null; then
    info "百度网盘已安装"
    return
  fi

  if ! confirm "安装百度网盘？（从镜像下载 deb）" "Y"; then
    info "已取消"
    return
  fi

  local mirror_url="https://mirrors.sdu.edu.cn/spark-store/store/network/baidunetdisk/"
  local deb_name
  deb_name=$(curl -sL "$mirror_url" | grep -oP 'baidunetdisk_\d+\.\d+\.\d+_amd64\.deb' | sort -V | tail -1)

  if [[ -z "$deb_name" ]]; then
    warn "无法获取最新版本号，尝试固定版本 4.17.8"
    deb_name="baidunetdisk_4.17.8_amd64.deb"
  fi

  local url="${mirror_url}${deb_name}"
  local deb="/tmp/${deb_name}"

  logcmd "下载百度网盘 deb (${deb_name})"
  wget -c -O "$deb" "$url" || { err "下载失败: $url"; return; }
  logcmd "dpkg -i ${deb_name}"
  sudo dpkg -i "$deb" && info "百度网盘安装成功" || {
    logcmd "apt install -f -y"
    sudo apt install -f -y && info "百度网盘安装成功" || err "百度网盘安装失败"
  }
  rm -f "$deb"
}

# ── 3.4 网易云音乐 ──
soft_netease() {
  echo ""
  hdr "安装网易云音乐"

  echo ""
  echo "安装方式："
  echo "  1) Flatpak 第三方 GTK4 客户端（推荐，持续更新）"
  echo "  2) 官方旧版 deb"
  local method
  read -r -p "请选择 [1/2] (默认 1): " method
  method=${method:-1}
  echo "[$(ts)] ⚙ 用户选择: 网易云安装方式 → $method" >> "$LOG_FILE"

  case "$method" in
    1)
      if ! command -v flatpak &>/dev/null; then
        logcmd "apt install flatpak"
        sudo apt install -y flatpak
      fi
      logcmd "flatpak remote-add flathub"
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
      logcmd "flatpak install NeteaseCloudMusicGtk4"
      flatpak install -y flathub com.github.gmg137.NeteaseCloudMusicGtk4 && info "网易云音乐 (GTK4) 安装成功" || err "安装失败"
      ;;
    2)
      local url="https://d1.music.126.net/dmusic/netease-cloud-music_1.2.1_amd64_ubuntu_20190428.deb"
      local deb="/tmp/netease-cloud-music_1.2.1_amd64.deb"
      logcmd "下载网易云官方 deb"
      wget -c -O "$deb" "$url" || { err "下载失败"; return; }
      logcmd "dpkg -i netease-cloud-music_1.2.1_amd64.deb"
      sudo dpkg -i "$deb" && info "网易云音乐安装成功" || {
        logcmd "apt install -f -y"
        sudo apt install -f -y
        if [[ -f /opt/netease/netease-cloud-music/libs/libgio-2.0.so.0 ]]; then
          logcmd "修复 libgio 兼容性"
          sudo cp /usr/lib/x86_64-linux-gnu/libgio-2.0.so.0 /opt/netease/netease-cloud-music/libs/
          info "libgio 兼容性已修复"
        fi
        info "网易云音乐安装完成"
      }
      rm -f "$deb"
      ;;
    *)
      warn "无效选择，取消"
      ;;
  esac
}

# ── 3.5 WPS Office ──
soft_wps_download() {
  local page_url="https://linux.wps.cn/"
  local base_url
  base_url=$(curl -sL "$page_url" | grep -oP "https://wps-linux-personal\.wpscdn\.cn[^\"']+amd64\.deb" | head -1)

  if [[ -z "$base_url" ]]; then
    warn "无法从官网获取下载链接"
    return 1
  fi

  local key="7f8faaaa468174dc1c9cd62e5f218a5b"
  local uri
  uri=$(echo "$base_url" | sed 's|https://[^/]*||' | sed 's|?.*||')
  local ts
  ts=$(date +%s)
  local hash
  hash=$(echo -n "${key}${uri}${ts}" | md5sum | awk '{print $1}')
  local signed_url="${base_url}?t=${ts}&k=${hash}"
  local deb_name
  deb_name=$(basename "$base_url")
  local deb_path="/tmp/${deb_name}"

  logcmd "下载 WPS: ${deb_name}"
  wget -c -O "$deb_path" "$signed_url" || { err "下载失败"; return 1; }
  echo "$deb_path"
}

soft_wps_install_deps() {
  local deps=(libcups2 libglib2.0-0 libglu1-mesa libsm6 libxrender1 libfontconfig1 libxext6 libxcb1 libbz2-1.0)
  logcmd "apt install -y ${deps[*]}"
  sudo apt install -y "${deps[@]}" &>/dev/null
}

soft_wps_install_deb() {
  local deb_path="$1"
  logcmd "dpkg -i $(basename "$deb_path")"
  local dpkg_out
  dpkg_out=$(sudo dpkg -i "$deb_path" 2>&1)
  local ret=$?
  echo "$dpkg_out" | while IFS= read -r line; do lograw "$line"; done

  if [[ $ret -eq 0 ]]; then
    return 0
  elif echo "$dpkg_out" | grep -qP "lzma error|unexpected end of file|corrupt"; then
    err "安装包已损坏（lzma 解压错误）"
    return 2
  else
    warn "dpkg 安装失败，尝试自动修复依赖..."
    logcmd "apt install -f -y"
    sudo apt install -f -y &>/dev/null
    if dpkg -l wps-office 2>/dev/null | grep -qP '^ii'; then
      return 0
    else
      return 1
    fi
  fi
}

soft_wps() {
  echo ""
  hdr "安装 WPS Office"
  local local_deb="$HOME/下载/wps-office_*.deb"
  local deb_path

  if ! confirm "安装 WPS Office？" "Y"; then
    info "已取消"
    return
  fi

  # 尝试本地安装包
  local local_files
  local_files=($HOME/下载/wps-office_*.deb)
  if [[ -f "${local_files[0]}" ]]; then
    echo "→ 检测到本地安装包: $(basename "${local_files[0]}")"
    if confirm "使用本地安装包" "Y"; then
      deb_path="${local_files[0]}"
    fi
  fi

  # 本地不存在或用户拒绝 → 从官网下载
  if [[ -z "$deb_path" ]]; then
    echo "→ 正在从官网获取最新版本..."
    deb_path=$(soft_wps_download)
    if [[ -z "$deb_path" || ! -f "$deb_path" ]]; then
      err "无法下载 WPS Office"
      echo "  请手动访问 https://linux.wps.cn 下载后重试"
      return
    fi
  fi

  # 预装依赖
  echo "→ 安装依赖..."
  soft_wps_install_deps

  # 安装
  echo "→ 安装 WPS Office ..."
  soft_wps_install_deb "$deb_path"
  local install_ret=$?

  if [[ $install_ret -eq 0 ]]; then
    info "WPS Office 安装成功"
    rm -f "$deb_path"
  else
    err "WPS Office 安装失败"
    rm -f "$deb_path"
    return
  fi

  echo ""
  if confirm "安装 WPS 中文字体？（fonts-wqy-zenhei, fonts-wqy-microhei）" "Y"; then
    logcmd "apt install fonts-wqy-zenhei fonts-wqy-microhei"
    sudo apt install -y fonts-wqy-zenhei fonts-wqy-microhei && info "WPS 中文字体已安装"
  fi
}

# ── 软件推荐菜单 ──
soft_menu() {
  while true; do
    echo ""
    hdr "软件推荐"
    echo "1) 安装微信 WeChat"
    echo "2) 安装 Visual Studio Code"
    echo "3) 安装百度网盘"
    echo "4) 安装网易云音乐"
    echo "5) 安装 WPS Office"
    echo "b) 返回主菜单"
    echo ""
    read -r -p "请选择 [1-5/b]: " choice
    echo "[$(ts)] ⚙ 菜单选择: 软件推荐 → $choice" >> "$LOG_FILE"
    case "$choice" in
      1) soft_wechat ;;
      2) soft_vscode ;;
      3) soft_baidu ;;
      4) soft_netease ;;
      5) soft_wps ;;
      b|B) break ;;
      *) warn "无效输入" ;;
    esac
  done
}

# ════════════════════════════════════════
# 主菜单
# ════════════════════════════════════════
main_menu() {
  while true; do
    echo ""
    hdr "PikaOS 系统设置工具"
    echo "1) 系统汉化美化"
    echo "2) 系统优化"
    echo "3) 软件推荐"
    echo "q) 退出"
    echo ""
    read -r -p "请选择 [1-3/q]: " choice
    echo "[$(ts)] ⚙ 菜单选择: 主菜单 → $choice" >> "$LOG_FILE"
    case "$choice" in
      1) i18n_setup ;;
      2) sysopt_menu ;;
      3) soft_menu ;;
      q|Q) echo "退出。"; exit 0 ;;
      *) warn "无效输入" ;;
    esac
  done
}

# ════════════════════════════════════════
# 启动
# ════════════════════════════════════════
setup_log
init_sudo
main_menu
