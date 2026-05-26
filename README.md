# PikaOS 系统优化与中文环境配置工具

PikaOS 4 (COSMIC) 一键系统优化、中文环境配置、常用软件安装脚本。

## 快速开始

```bash
bash setup_pikaos.sh
```

脚本自动缓存 sudo 凭证，三步菜单操作：

1. **系统汉化美化** — fcitx5 环境变量 & 自启动、CJK 字体回退优先级、Shell 别名（一键确认）
2. **系统优化** — 包含 5 个子项，每项每步 1/2 询问，可选执行
3. **软件推荐** — 微信 / VS Code / 百度网盘 / 网易云音乐 / WPS Office

所有操作记录到脚本同目录的 `setup_pikaos_YYYYMMDD_HHMMSS.log`。

> **两种使用方式**：Markdown 文档（`PikaOS系统优化及中文环境设置.md`、`软件安装推荐.md`）可供 AI（如 opencode）读取后逐项执行优化；`setup_pikaos.sh` 脚本则适合直接运行，交互式菜单驱动，无需 AI 介入。

## 文件说明

| 文件 | 说明 |
|------|------|
| `setup_pikaos.sh` | **主脚本** — 交互式菜单驱动，支持 sudo 缓存、彩色输出、操作日志 |
| `PikaOS系统优化及中文环境设置.md` | 系统优化详细方案（参考文档，脚本已实现） |
| `软件安装推荐.md` | 软件安装指南（参考文档，脚本已实现） |
| `github.sh` | GitHub SSH 一键配置脚本。手动执行：`bash github.sh` |
| `setup_proxy.sh` | 代理配置脚本（风格参考） |
| `AI_INSTRUCTIONS.md` | 旧版 AI 手动操作指令（已由 `setup_pikaos.sh` 替代） |
