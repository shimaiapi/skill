# 现场部署、兼容与验证

## 诊断依据

已验证环境：Windows 11，OpenAI.Codex MSIX `26.1021.3705.0`，界面版本 `26.1021.31345`。表现为 Language 已选简体中文但主体英文，使用第三方 API/无 ChatGPT 身份时 Statsig 请求直连 `https://ab.chatgpt.com/v1` 超时。客户端 i18n 受 layer `72216192` 的 `enable_i18n` 控制，默认 false；单改 localeOverride 或模型 base_url 不能替代这个开关。

应用专用 PAC 与本地服务让配置初始化及时返回。实测一次隔离 UI 数据目录的配置就绪从约44秒变为11秒，中文约14秒出现；这不是各机器性能保证。WSL、项目扫描、插件与其他域名超时需独立定位。

官方当前 Windows 使用说明：[Windows desktop](https://learn.chatgpt.com/docs/app/windows)。以下内部开关来自对应版本实测，**不是官方稳定配置接口**。

## 部署与恢复

用户账户需已安装对应 MSIX，Node.js 18+ 在 PATH。不要默认获得管理员权限，也无需管理员运行。

- 安装前：`Install.ps1 -CheckOnly`，输出签名检查后的应用路径、包版本、ASAR 结构证据。
- 安装：`Install.ps1`；默认目录 `%LOCALAPPDATA%\OpenAI\ChatGPTDesktopLocalRepair`。创建当前用户桌面“ChatGPT 中文启动”。安装不会自动重启用户应用。
- 实测：退出托盘实例，从新增入口启动。版本每次动态解析；升级后首次启动重新检查 ASAR。每次启动只使用此进程的 PAC/SPKI 参数，常规官方入口不会使用这些参数。
- 移除：先完全退出应用，再运行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "安装目录\Remove.ps1"`；恢复使用官方入口。不会删除用户聊天、项目或第三方 API 配置。
- 证书有效期一年；到期需要退出应用、移除本辅助方案后重新安装。安装生成新密钥，不在 skill 或 ZIP 中附带密钥。
- 端口18769与其他方案冲突时先确认归属。不要终止未知进程；只能在用户要求替换方案时移除已识别的旧方案。
- 重装时若目录有 ownership marker 但辅助进程未运行，可以重装；已有桌面快捷方式将被保护，先移除旧安装或使用 `-NoShortcut`。用户数据不在辅助目录中。

远程 SSH 输入 PowerShell 时注意 UTF-8 BOM、编码与引号。推荐 scp 上传 `.ps1` 后 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...`。如果创建临时计划任务：`New-ScheduledTaskPrincipal -UserId 当前交互用户 -LogonType Interactive -RunLevel Limited`。从 SSH 的 Session 0 直接调用包启动可能 E_ACCESSDENIED；不要据此改用裸 EXE。`Invoke-CommandInDesktopPackage` 启动的进程不继承调用进程环境，本方案只依赖显式参数。

## 三层验证

1. **静态与辅助服务**：`Install.ps1 -CheckOnly` 成功；签名有效、清单入口明确、ASAR 匹配。`node scripts/test_helper.cjs` 验证新证书、TLS、限定 CONNECT、PAC 与响应。其他版本到此只能称“结构匹配”。
2. **原生身份与 UI**：在交互桌面启动实际应用；查其主进程 PID，运行 `ProcessIdentity.ps1 -TargetProcessId PID`。结果应等于 `Get-AppxPackage OpenAI.Codex` 的 PackageFamilyName，不能是 NO_PACKAGE。确认中文菜单、侧栏和设置主体，不只看语言下拉框。原先聊天/项目/模型配置仍可见；在用户允许发送测试请求时验证第三方 API。没有发送测试请求时明确未端到端验证模型请求，不额外索要 API Key。
3. **更新与清理**：实际“帮助→检查更新”。成功证据是“已是最新版本”或显示可用版本；网络错误只证明更新器已初始化，不能声称更新成功。不要点击下载/安装新版本，除非用户授权升级。完成后检查没有 `--remote-debugging-port`，临时端口关闭，任务与临时目录清除。原生更新弹窗可能仍为英文，这与主界面语言验证不同。

必要时临时 `Launch.ps1 -DiagnosticPort 空闲端口`，只使用回环 CDP。Renderer 读取最小状态：document.documentElement.lang，是否包含中文菜单，Statsig readiness；不输出 document.body.innerText 的整个内容（可能包含聊天）。截图同样先考虑是否包含敏感内容。

Windows 日志可能在 `%LOCALAPPDATA%\Packages\<PackageFamily>\LocalCache\Local\Codex\Logs`，也可能在 `%LOCALAPPDATA%\Codex\Logs`。只筛选相关 PID 和 updater/Statsig 事件，避免整份日志泄露数据。实测更新成功日志：`[windows-offers] Windows update eligibility ... hasUpdate=false source=store`。

## 新版本适配

现有 `inspect.cjs` 只读取 ASAR 内 JS，不解包修改。定位相邻 `72216192` / `enable_i18n` / `locale_source`、绝对 Statsig 端点、原生包身份更新器特征。结构匹配是部署前的筛查，不是未来兼容性证明。

若失败，先只读检查新清单及源码，查 `localeOverride`、`enable_i18n`、`locale_source`、`getLayer`、`statsig`、`initialize`、`check-for-updates`、`getCurrentPackageFamily`。确认：

- 如果新版本已移除远程语言开关、官方已修好，就移除辅助方案并用原入口验证，避免强行保留补丁。
- 若 layer ID、字段、返回协议或端点改变，新增具名 adapter，附真实结构证据与实测版本；服务只返回经实际 bundled SDK 验证的 JSON。不要猜 ID 或伪造所有功能开关。
- 如果支持客户端配置语言端点且经实测有效，优先采用更小范围的官方配置，保留原值可撤回。模型 `base_url` 不等于应用 Statsig 端点。
- 安装器或运行时从固定 adapter 扩展为多 adapter 时，必须将探测结果传入 proxy；不能只改探测接受条件却仍返回旧层。
- 产品、OS、打包方式变化需要不同启动策略和身份/更新验证，不把当前 Windows 逻辑当跨平台方案。

保留包身份的相关 Windows API：[Invoke-CommandInDesktopPackage](https://learn.microsoft.com/en-us/powershell/module/appx/invoke-commandindesktoppackage?view=windowsserver2025-ps)。该命令用于包上下文启动，需交互用户会话；实际进程身份应额外验证。

## 最少交付记录

记录产品和两个版本号（UI/MSIX）、适配器、结构匹配、UI实测结果、包身份、更新检查结果、性能测量条件、未验证项目、创建的辅助目录/快捷方式与清理结果。无需在 skill 中保存任何机器地址、用户名、API、密钥或原始日志。
