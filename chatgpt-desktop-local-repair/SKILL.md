---
name: chatgpt-desktop-local-repair
description: 修复 Windows ChatGPT/Codex 桌面版中文设置不生效、配置服务超时导致的启动慢，以及自定义启动器造成的更新失效；仅调整应用网络，生成可迁移安装包，并按实际版本检查兼容性。
---

# Windows 桌面应用中文与启动修复

目标：在保留官方应用、第三方模型 API、用户数据及 Windows 更新功能的前提下，生成应用专用的本地语言配置服务和桌面入口。用户要求在其他电脑生成时，直接构建并交付可安装 ZIP，不只提供操作建议。

## 范围与版本决策

先识别目标电脑、产品、安装方式和问题含义；不要把窗口名 ChatGPT 等同于固定产品。当前自动适配器支持 **Windows、OpenAI.Codex MSIX、Electron ASAR 中仍使用 Statsig layer 72216192 的版本**。普通 ChatGPT 的其他安装包、macOS/Linux 和未知布局只做诊断，需另建有证据的适配器。

已实际验证：界面版本 `26.1021.31345`，MSIX `26.1021.3705.0`。其他版本的结构匹配仅意味着可尝试；中文界面、更新及性能必须分别运行验证，不能声称支持所有版本。升级后由版本和归档时间戳触发重新探测；不要锁死安装目录、Windows 用户名或散列文件名。

针对部署、升级或现场排障，读取 [references/windows.md](references/windows.md)。新版本结构不匹配时，读取其中的适配流程，分析实际客户端再改适配器；不得放宽匹配只为让检查通过。

## 执行

1. 对已有正常运行的官方界面先确认是否无需此补丁。区分模型 API 失败、官方服务网络超时、WSL/项目扫描慢与语言配置问题。读取配置只提取必要字段，避免输出 API Key、聊天或认证信息。
2. 从 `assets/windows` 生成部署包：
   ```sh
   python3 scripts/build_bundle.py --output /absolute/output/chatgpt-desktop-local-repair-windows.zip
   ```
   若就在目标 Windows 执行，可直接运行 skill 内 `assets/windows/Install.ps1`，无需 Python 或先压缩。目标 Windows 用户需 Node.js 18+（无需 npm 依赖或 OpenSSL）。解压后使用当前用户的 Windows PowerShell：
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1 -CheckOnly
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
   ```
   安装只创建辅助文件和“ChatGPT 中文启动”桌面入口，不自动关闭现有应用或启动修复。用户授权现场修复时可直接完成安装、必要的重启与验证；不要重复索要已有授权。
3. 完全退出现有应用，包括托盘，从新增入口启动。SSH 会话通常处于 Session 0，不能直接完成带包身份的启动；应使用当前登录用户的临时 `Interactive`/`Limited` 计划任务运行入口，并在验证后删除任务。无需存储用户密码或永久计划任务。
4. 验证原生包身份、实际中文界面、模型接口路由以及“帮助→检查更新”。按需测启动时间，不把某次独立测试目录的时间当成普适结果。验证方法与完成条件见参考文档。
5. 交付修改范围、实测版本与结果、使用入口、移除方式和已知限制。打包 skill 本身时排除缓存、临时数据、证书、私钥及现场验证文件。

## 必须保留的实现边界

- 不修改系统代理、DNS、hosts、防火墙、根证书、全局环境变量或执行策略，不改应用二进制/ASAR，不改 `.codex/config.toml`。`-ExecutionPolicy Bypass` 仅对子进程生效。
- **不能裸启动 MSIX 的 EXE**：会丢失包身份，更新器报 `missing current windows package family`。使用清单中的 AppId 与 `Invoke-CommandInDesktopPackage`，并实测新进程的包身份。不要退回裸 EXE 作为失败兜底。
- PAC 只路由 `ab.chatgpt.com` 到 IPv4 回环；其余域名（包括自定义模型 API、登录及更新域名）DIRECT。只允许该主机的 CONNECT，不做通用代理。
- TLS 例外仅绑定本机新生成证书的 SPKI，应用参数需配套 `--user-data-dir`；不得使用 `--ignore-certificate-errors` 或系统信任根。保留现有数据目录，首次部署及新版本需检查不会打开空白替代配置。
- 本地响应只提供语言层，其余远程功能开关回退客户端默认值；明确这一限制。该方案不提供完整官方服务镜像，也不修复所有启动慢或账号功能。
- 先验证旧入口/服务是否属于本 skill，再覆盖或移除；不删除其他方案、用户数据或无归属文件。端口占用、未知结构、签名失效、证书过期均停止并报告具体原因。
- CDP/临时诊断只监听回环，完成后正常重启为无调试参数实例、检查诊断端口关闭、删除临时任务和测试文件。不要将带调试端口的入口作为最终交付。

## 维护验证

脚本变化后运行 `node scripts/test_helper.cjs`，以及 Windows 实际包的 `Install.ps1 -CheckOnly`。安装器变化还需在独立临时安装目录以 `-NoShortcut` 测试安装与移除；不要为测试重装用户当前的工作入口。结构探测、辅助服务单测和真实 UI/更新验证分别记录，不能互相替代。
