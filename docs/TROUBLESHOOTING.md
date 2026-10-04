# Troubleshooting

## 已授权，PinTop 却仍提示需要权限

先确认授权的是正在运行的那份 `PinTop.app`。在系统设置的“隐私与安全”中找到辅助功能授权页（部分版本显示为“设备控制和数据访问”），重新开启 PinTop 后，回到控制窗口刷新。

本地构建使用 ad-hoc 签名，重新编译可能使系统保留的授权记录不再适用于当前构建。可以先正常退出 PinTop，在授权页移除旧记录，再添加当前 `build/PinTop.app`。

如果旧记录仍无法刷新，可在终端定向重置 PinTop 的辅助功能记录：

```sh
tccutil reset Accessibility local.pintop.app
```

这会撤销 PinTop 的现有辅助功能授权。随后为当前应用重新授权并启动、刷新列表；它不是首次使用的必需步骤。不要重置其他应用的授权来排查 PinTop。

## 提示“PinTop 已在运行”

同一用户会话只运行一个主实例。点击菜单栏 PinTop 或已启用的程序坞图标，打开现有控制窗口；需要换用另一份构建时，先从 PinTop 菜单或 `⌘Q` 正常退出。

Xcode 和构建脚本共用项目的 `build/PinTop.app`。如果电脑上还有其他目录中的旧构建，检查 Spotlight 找到的应用路径，避免打开或授权了另一份应用。

## macOS 拦截下载的预览包

GitHub Releases 的现有 ZIP 采用 ad-hoc 签名，没有 Developer ID 签名或 Apple 公证。确认下载来自 [PinTop Releases](https://github.com/yangxiake/PinTop/releases)，同时下载 ZIP 和同名 `.sha256`，在两者所在目录运行：

```sh
shasum -a 256 -c PinTop-v0.1.6-macos-arm64.zip.sha256
```

上例对应 0.1.6 预览版，其他版本请使用其实际文件名。校验通过后解压，将 `PinTop.app` 放入“应用程序”。如首次打开被拦截，可按 [Apple 的单次“仍要打开”说明](https://support.apple.com/en-us/102445) 为这个应用放行。授权前应再次确认应用来源和路径。

当前下载包仅含 arm64；0.1.6 的界面早于当前源码中的 0.1.7。运行下载包不需要 Xcode，功能测试范围仍以对应发布说明与 [Tests](../Tests/TESTING.md) 为准。

## 菜单或输入法候选窗口被遮挡

这是已有实测记录的限制。先点击目标窗口上的“取消置顶”，或从 PinTop 的列表、菜单取消置顶，再使用被遮挡的临时窗口。

## 置顶失败或启动提示遗留资源

如果窗口已关闭、最小化、切换桌面，或提示“恢复进程未就绪”，先让目标窗口在当前桌面可见，再重新选择。PinTop 会检查并尝试回滚失败的置顶操作。

若启动提示仍有旧置顶资源需要人工检查，保留错误信息并提交 [Issue](https://github.com/yangxiake/PinTop/issues)，附上 [CONTRIBUTING](../CONTRIBUTING.md) 要求的环境与步骤。恢复记录位于用户的 `~/Library/Application Support/PinTop/Recovery`；分享前移除其中的个人路径。不要仅为消除提示而删除恢复记录，以免丢失清理依据。
