# PinTop

Keep original macOS windows on top without disabling SIP.

PinTop 是一个 macOS 窗口置顶工具。它让目标应用自己的原窗口保持在普通窗口之上，窗口仍由原应用绘制并处理交互。

## 原窗口，而不是截图

**The original window stays on top.**

PinTop 不通过复制窗口画面实现“看起来置顶”。它不会：

- 把目标窗口截成图片，再用图片代替原窗口；
- 创建镜像窗口来承载目标应用的画面与交互；
- 向目标应用注入代码；
- 要求关闭 System Integrity Protection（SIP）。

被置顶的仍然是目标应用自己的窗口。PinTop 的选择边框和取消角标只是操作提示，不替代目标窗口。

## Why PinTop

macOS 没有为普通第三方应用提供一个通用的 Windows 式 “Always on Top” 开关。PinTop 尝试在尽可能保留原窗口行为的情况下，让选中的窗口留在其他普通应用窗口之上。

## 使用

1. 启动 PinTop，控制窗口会自动打开。首次使用先按下方的 [Permissions](#permissions) 说明授予辅助功能权限。
2. 在列表中找到目标窗口，点击该行右侧的图钉按钮即可置顶；双击该行也可切换置顶状态。列表显示当前桌面可见的普通窗口和已经置顶的窗口，新开或关闭窗口后可点工具栏的“刷新”。
3. 也可以点击工具栏的“添加窗口…”：控制窗口收起，屏幕顶部出现选择提示；移到目标窗口上会显示边框，单击窗口完成选择并切换置顶状态。点击提示中的“取消选择”可退出。
4. 置顶成功后，控制窗口收起，目标应用成为活动应用。你可以继续在原窗口中输入和操作；默认开启的窗口角标显示在右上角。
5. 点击角标上的“取消置顶”（窄窗口可能显示“取消”），或回到列表点击填充的图钉，即可取消该窗口的置顶。工具栏“更多”中的“全部取消置顶”可以一次取消全部窗口。
6. 关闭控制窗口后 PinTop 继续运行。点击菜单栏的 PinTop，或程序坞图标（开启“在程序坞中显示”时），可重新打开控制窗口。右键或按住 Option 点击菜单栏 PinTop 可打开管理菜单，其中也能逐项或全部取消置顶。
7. 从 PinTop 应用菜单选择“退出 PinTop”可退出，正常退出时会取消全部置顶。

工具栏“设置”打开独立设置窗口，可调整“显示窗口角标”“在程序坞中显示”和“登录时打开”。关闭设置窗口即可继续使用控制窗口。

| 快捷键 | 操作 |
| --- | --- |
| `⌘N` | 添加窗口，进入桌面选择模式 |
| `⌘R` | 刷新窗口列表 |
| `⌘,` | 打开设置 |
| `⌘W` | 关闭当前 PinTop 窗口 |
| `⌘Q` | 退出 PinTop，并取消全部置顶 |
| `Esc` | 退出桌面选择模式；实体键盘行为尚未完整复核 |

`⌘` 快捷键在 PinTop 为活动应用时使用。桌面选择模式也提供“取消选择”按钮。

## Permissions

PinTop 需要识别和管理其他应用的窗口、读取窗口标题，并在桌面选择模式中接收选择操作，因此需要 macOS 的 **Accessibility（辅助功能）** 权限。

在 **System Settings → Privacy & Security → Accessibility**（系统设置 → 隐私与安全 → 辅助功能）中为正在使用的 PinTop 开启权限。部分系统版本或语言下，此页面可能显示为“设备控制和数据访问”。也可以从控制窗口的“授权…”进入系统授权提示；授权后返回 PinTop 刷新窗口列表。

开发构建重新编译后授权失效、重复实例及首次打开预览包的问题，见 [Troubleshooting](docs/TROUBLESHOOTING.md)。

## 从源码构建

需要完整的 Xcode 和 Swift 6 工具链。当前构建已在 **Xcode 27.0** 验证，其他 Xcode 版本尚未验证；工程的 macOS 部署目标为 **14.0**，功能验证范围见下方兼容性说明。

```sh
git clone https://github.com/yangxiake/PinTop.git
cd PinTop
./scripts/build_app.sh
open build/PinTop.app
```

也可以打开 [`PinTop.xcodeproj`](PinTop.xcodeproj)，选择共享的 **PinTop** scheme 和“我的 Mac”，按 `⌘R` 构建运行。这里的 `⌘R` 是 Xcode 的运行操作。

脚本与 Xcode 的 Debug 构建均输出到 `build/PinTop.app`。这是采用 **ad-hoc 签名的本地开发构建**。Release 构建也使用 ad-hoc 签名；`scripts/package_release.sh` 可在 Apple Silicon 上生成 arm64 ZIP 和 SHA-256 文件。

已发布的下载包见 [GitHub Releases](https://github.com/yangxiake/PinTop/releases)，均为预览版，使用 ad-hoc 签名，未经 Apple 公证。下载包可能早于当前源码，界面与使用说明应以对应版本的发布说明为准。

## 兼容性与测试范围

**允许启动的最低系统版本，不等于功能已经通过测试的系统版本。** PinTop 使用未公开的 macOS 窗口管理接口，系统更新后需要重新验证。

| 环境或场景 | 验证范围 |
| --- | --- |
| macOS 27.0 / 27.0.1、Apple Silicon（arm64）、SIP 开启 | 有开发机测试记录；当前开发机为 MacBook Air / Apple M5，使用单内置显示器 |
| macOS 14–26、其他系统版本、Intel Mac | 尚未完整验证；14.0 仅是工程与应用元数据的启动下限，现有下载包仅含 arm64 |
| 原窗口排序、输入、移动与缩放、单项取消 | 临时 AppKit 窗口已有实测；Finder、Safari、微信、ChatGPT 的置顶路径也有历史实测 |
| 同应用多窗口、不同应用多窗口、最小化与还原 | 有夹具测试记录；不代表所有应用及窗口类型均已验证 |
| 异常退出恢复 | 主进程异常结束后的 helper 清理、主进程与 helper 同时结束后的下次启动恢复，有历史测试记录 |
| 多显示器、跨屏、多 Desktop / Space、Mission Control、全屏、睡眠唤醒、目标应用重启 | 尚未完整验证；“登录时打开”也未通过重新登录实测 |

详细步骤、每次测试的版本及未覆盖项见 [`Tests/TESTING.md`](Tests/TESTING.md)。

## 已知限制

- 已置顶窗口可能遮挡其他应用的菜单或输入法候选窗口。遇到时先取消置顶；这项兼容问题尚未解决。
- 当前只选择当前桌面上可见的普通应用窗口，排除 PinTop 自身、部分系统进程及非普通层级窗口；最小化中的窗口不能作为新的选择目标。全屏和系统窗口不在已验证范围内。
- 窗口角标会跟随目标位置，但移动中可能有短暂偏移，跨屏行为尚未完整验证。
- 在一次系统设置窗口快速重复置顶的测试中，恢复 helper 未能就绪，置顶被安全回滚；该窗口场景尚未验证可靠。详见 [0.1.7 测试记录](Tests/acceptance-2026-10-04-native-ui.md)。

## How it works

PinTop 使用 Swift 与 AppKit 构建控制界面，通过 Accessibility APIs 识别窗口，通过运行时加载的私有 SkyLight / WindowServer 接口，为选中的**原窗口**添加独立辅助 Space 的成员关系，使它显示在普通窗口上方。它不是持续抢回焦点，也不是直接修改目标应用的代码。

每个置顶窗口都有独立恢复记录与 helper。置顶时检查窗口身份、成员关系和实际排序；取消时撤销 PinTop 添加的关系。helper 用于主进程异常结束后的清理，下一次启动还会检查遗留记录。当前窗口身份绑定目标进程的启动信息，目标应用重启后的新窗口需要重新选择。

## 开发状态

PinTop 处于 **experimental / 预览阶段**。当前源码版本为 **0.1.7（build 8）**，尚未发布对应 Release；已发布预览包的版本和真实变更见 [CHANGELOG](CHANGELOG.md)。兼容性测试仍在进行中。

## Contributing

欢迎提交可复现的窗口行为问题或范围明确的修复。Issue 所需信息、PR 要求和测试入口见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License

[MIT](LICENSE) © 2026 yangxiake.
