# 0.1.6 可发现性与退出检查

环境：本机 Apple Silicon、macOS 27.0.1、Xcode 27.0；SIP 保持开启。图形操作使用开发工程 `build/PinTop.app` 的 Debug 构建。

| 检查项 | 结果 |
| --- | --- |
| 重复应用 | Spotlight 曾索引开发目录和公开仓库 `build` 下的两份 `PinTop.app`，但仅开发目录的一份进程在运行。公开仓库构建产物已移入废纸篓，`mdfind` 只返回开发目录这一份。公开源码与 GitHub Release 保留。 |
| 启动显示 | 复现旧版：已用过的应用再次启动只出现后台进程、无控制窗口。修复后重启时，Computer Use 立即识别到标准窗口 `PinTop`，包括窗口列表与“退出程序”按钮。 |
| 窗口内退出 | 点击“退出程序”后，进程列表不再有 PinTop 主进程；再次启动可重新显示控制窗口。退出时走 `applicationWillTerminate`，会取消全部置顶。 |
| 授权 | 最终 Debug 构建后，在“设备控制和数据访问”移除旧 PinTop 记录并重新添加当前 `build/PinTop.app`；点击控制窗口“刷新”后显示“已授权”。 |
| 构建 | 0.1.6 Debug 构建成功，`codesign --verify --deep --strict` 通过。 |
| 发布包 | 0.1.6 Release 构建成功，arm64、最低启动版本 14.0、ad-hoc 签名、ZIP 完整性及 SHA-256 校验通过；打包生成的第二份本地应用随后移入废纸篓。ZIP 摘要为 `7b3e716e91e23231806b7130a735bde0dcaa1777170ab2c2f221cd4efc09f6b0`。 |

菜单栏左键打开控制窗口、程序坞点击重新打开窗口由 AppKit 路径实现；本轮没有独立的菜单栏坐标点击记录。Release 包未在这台机器上单独重复辅助功能授权测试。
