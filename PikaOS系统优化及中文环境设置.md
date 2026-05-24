# PikaOS 系统优化及中文环境设置

> 作者: Edouardlicn
> 系统版本: PikaOS 4 (Debian Sid 基础)
> 桌面环境: COSMIC (System76)
> 显示服务器: Wayland
> 内核: 7.0.8-pikaos
> GPU: NVIDIA GeForce GTX 1650 (驱动 595.71.05, CUDA 13.2)

---

## 目录

1. [内存与交换优化](#1-内存与交换优化)
2. [服务精简](#2-服务精简)
3. [环境变量清理](#3-环境变量清理)
4. [fcitx5 输入法配置](#4-fcitx5-输入法配置)
5. [NVIDIA 配置](#5-nvidia-配置)
6. [终端配置（foot）](#6-终端配置foot)
7. [字体配置（CJK 回退优先级）](#7-字体配置cjk-回退优先级)
8. [Shell 配置](#8-shell-配置)
9. [附录：更改汇总](#9-附录更改汇总)

---

## 1. 内存与交换优化

### 1.1 vm.swappiness

swappiness 控制内核使用交换空间的倾向程度。值越大越倾向于交换，默认 60。

**建议**: 桌面 + zram 场景设为 **10~30**。

```bash
# 立即生效
sudo sysctl -w vm.swappiness=20

# 持久化
echo "vm.swappiness=20" | sudo tee /etc/sysctl.d/99-swappiness.conf
```

### 1.2 ZRAM 压缩交换

检查当前状态：

```bash
zramctl
```

默认配置文件：`/etc/default/zramswap`

优化要点：

| 参数    | 优化前 | 优化后 | 说明                              |
|---------|--------|--------|-----------------------------------|
| ALGO    | lz4    | zstd   | zstd 压缩比更高，适合现代 CPU     |
| PERCENT | 100    | 40     | 40% × 15GB ≈ 6GB，对桌面足够      |

```bash
sudo vim /etc/default/zramswap
```

示例配置：

```ini
ALGO=zstd
PERCENT=40
SIZE=6144
PRIORITY=100
```

重启生效：

```bash
sudo systemctl restart zramswap
```

---

## 2. 服务精简

### 2.1 禁用 Evolution 后台服务

如不使用 GNOME Evolution 邮件客户端，可禁用其后台进程组。

```bash
systemctl --user mask evolution-addressbook-factory.service
systemctl --user mask evolution-calendar-factory.service
systemctl --user mask evolution-source-registry.service
systemctl --user mask evolution-user-prompter.service

# 立即停止
systemctl --user stop evolution-addressbook-factory.service \
                       evolution-calendar-factory.service \
                       evolution-source-registry.service \
                       evolution-user-prompter.service
```

#### Evolution 提醒通知

系统级 autostart 文件在 `/etc/xdg/autostart/org.gnome.Evolution-alarm-notify.desktop`。

用空的 `Hidden=true` 覆盖屏蔽（比改系统文件更干净）：

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/org.gnome.Evolution-alarm-notify.desktop << 'EOF'
[Desktop Entry]
Hidden=true
EOF

# 立即终止进程
kill <pid_of_evolution-alarm-notify>
```

### 2.2 Geoclue Demo Agent

位置服务 Demo，桌面用户通常不需要：

```bash
systemctl --user mask app-geoclue-demo-agent@autostart.service
```

### 2.3 at-spi-dbus-bus（无障碍服务）

如不使用屏幕阅读器等辅助功能，可禁用：

```bash
systemctl --user mask at-spi-dbus-bus.service
systemctl --user stop at-spi-dbus-bus.service
```

> **注意**: 部分 GTK 应用依赖 a11y 桥接实现剪贴板、拖放等功能。如果禁用后遇到问题，取消 mask 即可：
```bash
systemctl --user unmask at-spi-dbus-bus.service
systemctl --user start at-spi-dbus-bus.service
```

### 2.4 polkit-mate 认证代理

MATE 桌面的残留组件，COSMIC 下启动失败：

```bash
systemctl --user mask app-polkit-mate-authentication-agent-1@autostart.service
```

### 2.5 pika-welcome

首次启动欢迎页，使用后无需自启：

```bash
systemctl --user mask app-pika-welcome-autostart@autostart.service
```

---

## 3. 环境变量清理

PikaOS 默认通过 `im-config` 和 `nvidia-vaapi` 设置了若干环境变量，在 Wayland + COSMIC 下部分变量已不需要。

### 3.1 MOZ_DISABLE_RDD_SANDBOX

来源：`/etc/profile.d/nvidia-vaapi-env.sh`

该变量**禁用 Firefox 远程数据解码器（RDD）的沙盒**，是硬件视频加速（VA-API on NVIDIA）所需。但它会降低浏览器安全性。

```bash
# 从系统脚本中移除
sudo sed -i '/export MOZ_DISABLE_RDD_SANDBOX=1/d' /etc/profile.d/nvidia-vaapi-env.sh
```

> **⚠️ 注意**: Firefox 硬件视频解码（VA-API over NVIDIA）需要此变量。
> 如果发现 Firefox 无法硬件解码视频，可以单独在当前 shell 或 `~/.bashrc` / `~/.profile` 中设置：
> ```bash
> export MOZ_DISABLE_RDD_SANDBOX=1
> ```

### 3.2 CLUTTER_IM_MODULE

Wayland 下 Clutter 工具库基本不再使用。`im-config` 通过 `/etc/X11/Xsession.d/70im-config_launch` 设置的 `CLUTTER_IM_MODULE=xim` 属于 X11 遗留，可以清除。

通过 `~/.config/environment.d/`（systemd 用户环境覆盖）将其置空：

```bash
cat >> ~/.config/environment.d/10-fcitx5.conf << 'EOF'

# Clutter not used on Wayland/COSMIC; suppress legacy im-config xim setting
CLUTTER_IM_MODULE=
EOF
```

### 3.3 其他 Wayland 下推荐的环境变量

```bash
cat > ~/.config/environment.d/10-fcitx5.conf << 'EOF'
# Wayland native text-input-v3
GTK_IM_MODULE=
QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx5
SDL_IM_MODULE=fcitx5
CLUTTER_IM_MODULE=
EOF
```

> **⚠️ Wayland 下 GTK_IM_MODULE 关键说明**:
> Wayland 使用 `text-input-v3` / `text-input-v1` 协议原生处理输入法，不再依赖 GTK 的 IM 模块。
> **如果在 Wayland 下设置 `GTK_IM_MODULE=fcitx5`，会导致某些 GTK4 应用（如 COSMIC 本身的部分组件）输入法冲突——具体表现为按键无响应、无法输入或 fcitx5 崩溃。**
> 因此正确的做法是**留空** `GTK_IM_MODULE=`。

---

## 4. fcitx5 输入法配置

### 4.1 基础配置

fcitx5 配置文件位于 `~/.config/fcitx5/config`，核心设置：

```ini
[Behavior]
# 默认状态关闭（避免在不需要中文的应用中自动弹出）
ActiveByDefault=False

# 切换时显示输入法信息
ShowInputMethodInformation=True
CompactInputMethodInformation=True

# 默认页大小
DefaultPageSize=5

# 允许在密码框使用输入法（默认关闭，可根据需要开启）
AllowInputMethodForPassword=False

[Groups/0]
Name=默认
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=keyboard-cn
Layout=

[Groups/0/Items/2]
Name=pinyin
Layout=
```

### 4.2 快捷键配置

```ini
[Hotkey/TriggerKeys]         # 触发/切换输入法
0=Control+space
1=Zenkaku_Hankaku
2=Hangul

[Hotkey/EnumerateGroupForwardKeys]   # 切换输入法分组
0=Super+space

[Hotkey/EnumerateGroupBackwardKeys]
0=Shift+Super+space

[Hotkey/PrevPage]            # 候选词上翻
0=Up

[Hotkey/NextPage]            # 候选词下翻
0=Down

[Hotkey/PrevCandidate]       # 候选词左移
0=Shift+Tab

[Hotkey/NextCandidate]       # 候选词右移
0=Tab
```

### 4.3 拼音配置（双拼）

`~/.config/fcitx5/conf/pinyin.conf`：

```ini
# 双拼方案 — 自然码（可改为其他方案如 MS2003、ABC 等）
ShuangpinProfile=Ziranma

# 每页候选词
PageSize=7

# 功能开关
SpellEnabled=True           # 显示英文候选
SymbolsEnabled=True         # 显示符号候选
ChaiziEnabled=True          # 显示拆字候选
ExtBEnabled=True            # Unicode CJK 扩展 B 区
StrokeCandidateEnabled=True # 笔画过滤

# 云拼音（推荐关闭以保护隐私）
CloudPinyinEnabled=False

# 预测输入
Prediction=False

# 模糊音（按需开启）
[Fuzzy]
VE_UE=True              # ue -> ve (常见错误)
NG_GN=True              # 常见错误
Inner=True              # 音节内模糊 (xian -> xi'an)
PartialFinal=True       # 不完整元音匹配 (e -> en/eng/er)

# 以下模糊音默认关闭，按个人口音开启：
# AN_ANG=False          # an <-> ang
# EN_ENG=False          # en <-> eng
# IN_ING=False          # in <-> ing
# L_N=False             # l <-> n
# Z_ZH=False            # z <-> zh
# S_SH=False            # s <-> sh
# C_CH=False            # c <-> ch

# 翻页键
[PrevPage]
0=minus
1=Up
2=Page_Up

[NextPage]
0=equal
1=Down
2=Next

# 快捷输入
QuickPhraseKey=semicolon  # ; 触发快捷短语
VAsQuickphrase=True       # v 触发快捷输入
```

### 4.4 自启动

fcitx5 的 autostart 文件在 `~/.config/autostart/fcitx5.desktop`，确保它存在：

```bash
ls ~/.config/autostart/fcitx5.desktop
```

如果不存在，手动创建：

```bash
cat > ~/.config/autostart/fcitx5.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=fcitx5
Terminal=false
NoDisplay=true
EOF
```

### 4.5 环境变量（Wayland 专用）

通过 `~/.config/environment.d/10-fcitx5.conf`（systemd 用户环境）统一管理：

```ini
# Wayland 使用 text-input-v3 协议原生输入法
# GTK_IM_MODULE 必须留空，否则与 COSMIC/Wayland 冲突
GTK_IM_MODULE=

QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx5
SDL_IM_MODULE=fcitx5

# Clutter 在 Wayland 下已废弃，清空 im-config 的遗留设置
CLUTTER_IM_MODULE=
```

> **⚠️ 再次强调**: Wayland 下绝对不能设 `GTK_IM_MODULE=fcitx5`。这会与 Wayland 原生的 text-input 协议冲突，导致 fcitx5 在某些 GTK4 应用中无法工作或崩溃。

---

## 5. NVIDIA 配置

### 4.1 硬件加速相关环境变量

`/etc/profile.d/nvidia-vaapi-env.sh` 中保留以下内容（已移除 MOZ_DISABLE_RDD_SANDBOX）：

```bash
export LIBVA_DRIVER_NAME=nvidia
export NVD_BACKEND=direct
export EGL_PLATFORM=wayland
```

### 4.2 电源管理

在 `/etc/modprobe.d/nvidia-options.conf` 中启用两个电源管理选项：

```bash
sudo sed -i 's/^#options nvidia NVreg_PreserveVideoMemoryAllocations=1/options nvidia NVreg_PreserveVideoMemoryAllocations=1/' /etc/modprobe.d/nvidia-options.conf
sudo sed -i 's/^#options nvidia NVreg_EnableS0ixPowerManagement=1/options nvidia NVreg_EnableS0ixPowerManagement=1/' /etc/modprobe.d/nvidia-options.conf
```

更新 initramfs 使配置生效（重启后加载）：

```bash
sudo update-initramfs -u
```

> **说明**: `NVreg_PreserveVideoMemoryAllocations` 在系统休眠/挂起后保留显存内容；
> `NVreg_EnableS0ixPowerManagement` 启用现代 S0ix 待机电源管理。
> 如果是台式机且不关心省电，可以不启用这两个选项。

---

## 6. 终端配置（foot）

[foot](https://codeberg.org/dnkl/foot) 是一个轻量级 Wayland 原生终端模拟器，基于 VT340 标准，支持真彩色、字体连字（ligatures）、GPU 渲染。

### 6.1 推荐配置

foot 配置文件：`~/.config/foot/foot.ini`

```ini
[main]
# 字体配置：英文用 JetBrainsMono Nerd Font，中文回退到 Noto Sans Mono CJK SC
# 字号务必保持一致（都是 14），否则中文行高错位
font=JetBrainsMono Nerd Font:size=14, Noto Sans Mono CJK SC:size=14

# 推荐开启，按显示器 DPI 自动缩放字体
dpi-aware=yes

# 终端尺寸（列x行）
term=foot

# 初始窗口大小（字符数，而非像素）
initial-window-size-chars=100x32

# 字号调整步长
font-size-adjustment=1.0

# 字距调整（0 = 默认）
letter-spacing=0

# 行高调整（0 = 默认）
line-height=0

# 水平间距调整（0 = 默认，1 = 等宽） 
horizontal-letter-offset=0
vertical-letter-offset=0

# 下划线偏移
underline-offset=0

# 字距限制（防止极端缩放时字距过大/过小）
font-size-adjustment-min=8
font-size-adjustment-max=48

[scrollback]
# 回滚行数
lines=10000
# 回滚时是否多行跳动
indicator-position=relative

[bell]
# 终端响铃：没有视觉效果
urgent=no
notify=no
command=
# 可视响铃（闪烁）
visual=no

[mouse]
# 隐藏鼠标光标并允许鼠标选择文本
hide-when-typing=yes

[colors]
# 主题配色（可使用 catppuccin、dracula、gruvbox 等替换）
# 以下为 foot 默认暗色主题
background=282828
foreground=ebdbb2

# 光标颜色
cursor=ebdbb2

# 选区颜色（文字/背景）
selection-foreground=282828
selection-background=ebdbb2

# 常规 ANSI 颜色
regular0=282828   # black
regular1=cc241d   # red
regular2=98971a   # green
regular3=d79921   # yellow
regular4=458588   # blue
regular5=b16286   # magenta
regular6=689d6a   # cyan
regular7=a89984   # white

# 亮色 ANSI 颜色
bright0=928374    # bright black
bright1=fb4934    # bright red
bright2=b8bb26    # bright green
bright3=fabd2f    # bright yellow
bright4=83a598    # bright blue
bright5=d3869b    # bright magenta
bright6=8ec07c    # bright cyan
bright7=ebdbb2    # bright white

[csd]
# 客户端装饰（标题栏）
preference=server    # 使用服务端（合成器）装饰，更符合 COSMIC 风格
# preference=client  # 使用 foot 自绘标题栏
border-width=2
border-color=504945
hide-when-maximized=yes

[key-bindings]
# 自定义快捷键，以下设为空可禁用相应功能
# scrollback-up-page=none   # 禁用 Page Up 回滚
# scrollback-down-page=none # 禁用 Page Down 回滚

# 字体缩放（如果 dpi-aware 表现不佳，可用此快捷键实时调整）
font-increase=Control+plus
font-decrease=Control+minus
font-reset=Control+0
```

### 6.2 foot 的 server 模式（推荐）

foot 支持 **server/客户端 模式** —— 启动一个后台 foot 服务，新终端窗口直接连到该服务，实现瞬间启动（秒开）和共享缓存。

启用方式：

```bash
# 设置开机自启动
systemctl --user enable --now foot-server.service
```

确认正在运行：

```bash
systemctl --user status foot-server.service
```

然后在终端中运行 `foot` 开新窗口，或设置快捷键（COSMIC 设置 → 键盘 → 添加自定义快捷键）。

### 6.3 中文字体注意事项

foot 的多字体语法为：

```ini
font=<主字体>:size=<字号>, <回退字体>:size=<字号>, <更多回退>:size=<字号>
```

**关键规则**:
- **所有回退字体的 size 必须一致**，否则中文行高会与英文错位。
- JetBrainsMono Nerd Font 已包含部分 CJK 字形（源自 Noto），但覆盖不全。额外指定 `Noto Sans Mono CJK SC` 作为回退可确保完整的 CJK 覆盖。
- 如果字体名称包含空格，需要用引号包裹：
  ```ini
  font=JetBrainsMono Nerd Font:size=14, "Noto Sans Mono CJK SC":size=14
  ```
  实际上 foot 对引号不严格，逗号分隔即可。

检查字体是否生效：

```bash
# 在 foot 中运行，查看 fallback 字体
footclient --version 2>&1
# 或打开 foot 的 debug log:
# foot --log-level=info -o font=...
```

### 6.4 常见问题

**Q: 中文显示为方块（□□）？**
> 缺少中文字体。安装 `fonts-noto-cjk`：
> ```bash
> sudo apt install fonts-noto-cjk
> ```

**Q: 中文和英文字体行高不对齐？**
> 确保中英文的 `:size=` 完全相同，且两个字体在相同字号下 x-height 接近。JetBrainsMono + Noto Sans Mono CJK 组合表现良好。

**Q: 模糊/缩放不正确？**
> 确保 `dpi-aware=yes`，然后在 foot 中使用 `Ctrl++` / `Ctrl+-` 缩放测试。

### 6.5 推荐工具：wl-clipboard（Wayland 剪贴板）

Wayland 下传统的 xclip 不可用，需要 `wl-clipboard` 提供命令行剪贴板功能。
常用于：复制 SSH 公钥、从终端输出直接贴到 GUI 等。

```bash
sudo apt install wl-clipboard
```

使用示例：

```bash
# 复制到剪贴板
cat ~/.ssh/id_rsa.pub | wl-copy

# 从剪贴板粘贴到文件
wl-paste > file.txt
```

如果不装 `wl-clipboard`，GitHub SSH 公钥（一长串无换行的文本）就需要手动在终端中用鼠标跨屏选取，容易漏选导致粘贴失败。

---

## 7. 字体配置（CJK 回退优先级）

> foot 终端的多字体已在上一节配置，本节主要针对**桌面环境**（GTK/Qt 应用等）的 CJK 字体回退。

### 7.1 CJK 字体回退优先级

通过 fontconfig 配置文件 `~/.config/fontconfig/fonts.conf` 设定字体回退顺序：

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <!-- Monospace: JetBrainsMono → Noto Sans Mono CJK SC -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font</family>
      <family>Noto Sans Mono CJK SC</family>
      <family>Noto Sans Mono CJK TC</family>
    </prefer>
  </alias>

  <!-- Sans: prefer Noto Sans CJK SC for CJK -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans CJK SC</family>
      <family>Noto Sans CJK TC</family>
    </prefer>
  </alias>

  <!-- Serif: prefer Noto Serif CJK SC for CJK -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif CJK SC</family>
      <family>Noto Serif CJK TC</family>
    </prefer>
  </alias>

  <!-- JetBrainsMono fallback for CJK -->
  <alias>
    <family>JetBrainsMono Nerd Font</family>
    <prefer>
      <family>JetBrainsMono Nerd Font</family>
      <family>Noto Sans Mono CJK SC</family>
    </prefer>
  </alias>
</fontconfig>
```

创建目录：

```bash
mkdir -p ~/.config/fontconfig
```

使配置生效（无需重启，新应用会立即使用）：

```bash
fc-cache -fv
```

---

## 8. Shell 配置

### 8.1 Bash 别名

`~/.bash_aliases` 会被 `~/.bashrc` 自动加载，用于存放自定义别名：

```bash
cat > ~/.bash_aliases << 'EOF'
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
```

### 8.2 opencode 快捷配置

`~/.bashrc` 尾部已添加 PATH：

```bash
export PATH=/home/edo/.opencode/bin:$PATH
```

opencode 主配置文件 `~/.config/opencode/opencode.jsonc`：

```jsonc
{
  "$schema": "https://opencode.ai/config.json"
  // 可在此添加 API key、Proxy、自定义 agents 等配置
}
```

---

## 9. 附录：更改汇总

### 所有修改的文件

| 文件 | 操作 |
|------|------|
| `/etc/sysctl.d/99-swappiness.conf` | **新建** — swappiness 持久化 |
| `/etc/default/zramswap` | **编辑** — 40% 容量 + zstd |
| `/etc/profile.d/nvidia-vaapi-env.sh` | **编辑** — 移除 MOZ_DISABLE_RDD_SANDBOX |
| `/etc/modprobe.d/nvidia-options.conf` | **编辑** — 启用 2 个电源管理选项 |
| `~/.config/environment.d/10-fcitx5.conf` | **编辑** — 清空 CLUTTER_IM_MODULE |
| `~/.config/fontconfig/fonts.conf` | **新建** — CJK 字体优先级 |
| `~/.bash_aliases` | **新建** — 常用别名 |
| `~/.config/autostart/org.gnome.Evolution-alarm-notify.desktop` | **新建** — 隐藏 Evolution 提醒 |

### 所有 mask 的服务

```bash
evolution-addressbook-factory.service
evolution-calendar-factory.service
evolution-source-registry.service
evolution-user-prompter.service
app-geoclue-demo-agent@autostart.service
at-spi-dbus-bus.service
app-polkit-mate-authentication-agent-1@autostart.service
app-pika-welcome-autostart@autostart.service
```

### 需重新登录生效的更改

- `~/.config/environment.d/` — 环境变量（section 4.5, systemd user session）
- systemd `--user mask` — 服务禁用（section 2）
- `~/.config/fontconfig/` — 新应用立即生效，已有应用需重启（section 7）
- `~/.bash_aliases` — 新 shell 自动加载（section 8）

### 需重启系统生效的更改

- `/etc/sysctl.d/99-swappiness.conf` — 已在运行期间立即生效，重启后持久化
- `/etc/default/zramswap` — 已重启 zram 服务，重启系统后自动保持
- `/etc/modprobe.d/nvidia-options.conf` — NVIDIA 模块参数，需重启加载
- `update-initramfs` — 已生成新 initramfs，重启后生效

---

> 最后更新: 2026-05-24 | 作者: Edouardlicn
