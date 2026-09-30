# 测试范围

本机基线：Apple Silicon、macOS 27.0、Xcode 27.0、SIP 开启。Release/Debug 可构建，应用使用本地 ad-hoc 签名。0.1.2 发布包的最低启动版本为 macOS 14.0，仅含 arm64 架构；14–26 允许尝试，但没有功能实测，不构成兼容性承诺。窗口 ID 仅在每次运行中有效。

## 已验证

- 独立 AppKit 临时窗口、Finder、Safari、微信和 ChatGPT 的原窗口置顶路径已有本机实测；独立临时窗口之间的前后顺序与焦点分离通过。
- 同应用双窗口及三窗口分别置顶、单项取消互不影响；最小化后暂停、还原后恢复。
- 主进程异常结束时独立 helper 清理，以及主进程与 helper 均结束后的下次启动恢复。
- 临时 AppKit 窗口和 ChatGPT 窗口的蓝色取消按钮经整屏观察位于各自原窗口上方；点击按钮后恢复记录解除。

这些是开发机上的实测，不代表所有系统、窗口类型或显示器配置均通过。

## 待回归

- 普通双桌面切换、Mission Control/全屏与多显示器；窗口跨屏与调整尺寸后的角标位置。
- 实体键盘 Esc、中文输入法、菜单、弹出窗、拖拽和不同目标应用的完整交互。
- 已知失败项：其他应用的菜单或输入法候选窗有时会被已钉窗口遮挡。

## 临时夹具

`python3 Tests/fixture/setup.py` 启动两个独立 AppKit 窗口；`python3 Tests/fixture/setup.py --stop` 结束它们。`python3 Tests/fixture_c.py` 可启动第三个窗口，`python3 Tests/fixture_same.py` 可启动同应用双窗口；对应脚本均支持 `--stop`。夹具应用和状态只写入 `/tmp/pintop-no-sip-lab`。测试后请结束夹具，并在 PinTop 中取消全部置顶。
