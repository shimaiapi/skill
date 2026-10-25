# Agent Skills

可供 Codex agent 安装的技能集合。

## ChatGPT 桌面中文与启动修复

[chatgpt-desktop-local-repair](chatgpt-desktop-local-repair/SKILL.md) 用于处理 Windows ChatGPT/Codex 桌面版中文设置不生效、语言配置服务超时导致的启动慢，以及自定义启动器导致的更新失效。

仅调整应用网络，保留官方应用文件、第三方模型 API 配置及系统网络设置。包含版本探测、每台电脑独立生成的本地证书、保留 Windows 包身份的启动器、便携安装包生成和卸载流程。

### 一句话安装或更新

在 Codex agent 中发送：

```text
从 https://github.com/shimaiapi/skill/tree/main/chatgpt-desktop-local-repair 安装或更新 chatgpt-desktop-local-repair skill；已安装则先暂存下载并备份旧版后替换，只更新技能文件，不重启当前应用。
```

安装器默认不会覆盖已存在目录；上述更新指令要求 agent 暂存下载、核对并备份替换，而不是直接重复安装。更新 skill 不会自动升级已部署的语言服务。

安装或更新后下一轮调用：

```text
使用 $chatgpt-desktop-local-repair 修复当前 Windows 应用的中文和启动慢，仅调整应用网络；若目标承载当前会话，先完成准备且不要重启，待我手动重新打开后继续验证中文和更新。
```

也可以一句话安装/更新并开始处理：

```text
从 https://github.com/shimaiapi/skill/tree/main/chatgpt-desktop-local-repair 安装或更新 skill（已有版本先备份替换），再用它修复当前 Windows 应用的中文和启动慢；不得中断当前会话，需要重启时先交付手动步骤，待我重新打开后继续验证。
```

### 兼容范围

目前实测界面版本 **26.1021.31345**、Windows MSIX **26.1021.3705.0**。自动适配器面向 OpenAI.Codex MSIX 且仍使用对应 Statsig 语言层的客户端。其他版本先探测实际结构；结构匹配不等于已通过运行验证，未知结构需要分析适配。

目标 Windows 需要 Node.js 18+。普通 ChatGPT 的其他安装方式及 macOS/Linux 尚未提供自动适配器。

### 直接部署到 Windows

下载本仓库后，在当前用户的 Windows PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\chatgpt-desktop-local-repair\assets\windows\Install.ps1 -CheckOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\chatgpt-desktop-local-repair\assets\windows\Install.ps1
```

如果正在目标应用里执行，请先保存本轮交接结果，再手动完全退出应用（包括托盘），使用新增的“ChatGPT 中文启动”桌面入口。重新打开后回到原聊天发送“继续验证中文和更新，不要重启应用”。安装 skill 本身不会自动安装辅助服务。

移除时先退出应用，再运行安装目录中的 `Remove.ps1`；默认目录为 `%LOCALAPPDATA%\OpenAI\ChatGPTDesktopLocalRepair`。详细验证、适配与限制见 [Windows 参考](chatgpt-desktop-local-repair/references/windows.md)。

### 生成便携安装包

```sh
python3 chatgpt-desktop-local-repair/scripts/build_bundle.py --output chatgpt-desktop-local-repair-windows.zip
```

安装包不包含预先生成的证书、私钥、机器配置或 API Key。

### 验证辅助服务

```sh
node chatgpt-desktop-local-repair/scripts/test_helper.cjs
```

该测试使用临时密钥并监听本机回环端口 18769；它不替代目标 Windows 上的界面、原生包身份和更新检查。
