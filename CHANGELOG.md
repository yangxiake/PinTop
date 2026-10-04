# Changelog

这里区分源码开发版本与 GitHub 已发布预览版。日期取自对应 Release 的发布时间，变更依据源码提交与测试记录；不把本地构建当作发布。所有已发布版本均为 prerelease。

## 0.1.7 — 开发版本，尚未发布

源码：[`e16119d`](https://github.com/yangxiake/PinTop/commit/e16119d)，build 8。

- 控制窗口改用 AppKit Toolbar 与 `NSTableView`；工具栏提供“添加窗口…”、刷新、更多与设置，列表使用图钉切换置顶。
- 设置改为独立窗口；退出与设置使用应用菜单，提供 `⌘N`、`⌘R`、`⌘,`、`⌘W` 和 `⌘Q` 菜单快捷键。
- 增加窗口缩放、列表空状态与滚动布局，应用图标加入 Asset Catalog。

界面、授权与置顶检查见 [0.1.7 测试记录](Tests/acceptance-2026-10-04-native-ui.md)。该版本没有对应 Git tag 或 GitHub Release。

## [0.1.6-preview](https://github.com/yangxiake/PinTop/releases/tag/v0.1.6-preview) — 2026-10-04

- 每次启动显示控制窗口，关闭控制窗口后仍在后台运行；菜单栏左键用于重新打开控制窗口。
- 当时的控制窗口增加“退出程序”按钮，正常退出取消全部置顶。
- 新安装默认显示程序坞图标，允许在设置中关闭。

见 [启动与退出检查](Tests/acceptance-2026-10-04-discovery.md)。这是目前最新的已发布预览版，界面早于 0.1.7 的源码。

## [0.1.5-preview](https://github.com/yangxiake/PinTop/releases/tag/v0.1.5-preview) — 2026-10-04

- 当时的控制面板按钮统一为 96×28 点，图标和文字为 12 点；窗口列表动作与面板右侧对齐，短列表收紧高度。
- 统一悬停与按下反馈，遵循系统“减少动态效果”设置。
- 窗口角标文案改为“取消置顶”。

见 [界面一致性复测](Tests/acceptance-2026-10-04-ui.md)。控制面板布局已在 0.1.7 改为原生工具栏与表格。

## [0.1.4-preview](https://github.com/yangxiake/PinTop/releases/tag/v0.1.4-preview) — 2026-10-03

- 修正当时“选择窗口”按钮中的图钉与文字整体居中。

见 [按钮对齐与窗口操作复测](Tests/acceptance-2026-10-03-alignment.md)。

## [0.1.3-preview](https://github.com/yangxiake/PinTop/releases/tag/v0.1.3-preview) — 2026-10-03

- 控制窗口使用 SF Symbols 与目标应用图标，补齐 PinTop 应用图标；列表显示应用名和窗口标题。
- 取消角标改用系统材质，以 60 Hz 检查目标几何位置；没有置顶窗口时停止检查。
- 修正未授权时窗口标题的提示。

见 [界面与角标跟随验收](Tests/acceptance-2026-10-03.md)。0.1.3 有真实 GitHub 预览版，属于已发布版本。

## [0.1.2-preview](https://github.com/yangxiake/PinTop/releases/tag/v0.1.2-preview) — 2026-09-30

- 最低启动版本恢复为 macOS 14.0，明确区分启动元数据与仅在 macOS 27.0 实测的功能范围。
- 置顶功能与 0.1.1 相同；macOS 14–26 的功能没有据此记为通过。

## [0.1.1-preview](https://github.com/yangxiake/PinTop/releases/tag/v0.1.1-preview) — 2026-09-30

- 曾把最低启动版本设为 macOS 27.0，以对齐当时唯一实测环境；此限制在 0.1.2 撤销。
- 置顶功能与 0.1.0 相同。此包已被 0.1.2 替代。

## [0.1.0-preview](https://github.com/yangxiake/PinTop/releases/tag/v0.1.0-preview) — 2026-09-30

- 首次公开原窗口置顶、窗口角标取消、菜单栏管理、恢复 helper 与源码工程。
- 发布仅含 arm64 的 ad-hoc 签名 ZIP 和 SHA-256 文件，无 Developer ID 签名或 Apple 公证。此包已被 0.1.2 替代。

早期窗口与异常恢复证据见 [2026-09-30 开发验收](Tests/acceptance-2026-09-30.md)。
