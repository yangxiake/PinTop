# 测试范围与记录

测试结论按版本和场景阅读，不能把一次开发机测试扩展为所有 macOS、硬件或窗口类型的兼容性保证。窗口 ID 只在当次运行中有效。

## 环境

历史记录覆盖 Apple Silicon（arm64）、macOS 27.0 / 27.0.1、Xcode 27.0、SIP 开启。当前复核环境为 MacBook Air（Mac17,4）/ Apple M5、16 GB 内存、单内置显示器、macOS 27.0.1（26A434）、Xcode 27.0（27A266a）；Swift 工具链为 6.4，工程按 Swift 6 语言模式编译。

当前源码为 0.1.7（build 8），GitHub 最新已发布版本为 0.1.6-preview。部署目标与 `LSMinimumSystemVersion` 均为 macOS 14.0；下载包仅含 arm64。14.0 是启动下限，不是低版本功能已通过的证据。本地 Debug / Release 均使用 ad-hoc 签名。

## 覆盖摘要

| 场景 | 证据与边界 |
| --- | --- |
| 原窗口置顶与交互 | 临时 AppKit 窗口有窗口 ID、CG 排序、焦点与文本输入记录；没有使用截图或镜像替代。Finder、Safari、微信、ChatGPT 的置顶路径有历史实测，未逐一完成所有交互回归。 |
| 不同应用多窗口 | A/B/C 夹具有双窗口、三窗口排序、重新激活及单项取消互不影响的记录。 |
| 同应用多窗口 | 双窗口独立置顶、单项取消与成员关系读回已有验证。 |
| 最小化 / 还原 | 同应用夹具已有暂停与恢复记录；不代表所有目标应用均通过。 |
| 移动 / 缩放 / 输入 | 临时窗口通过自身按钮或 Accessibility 移动、缩放和输入；自动标题栏拖拽未获得可靠结果，不能把它记为通过。角标移动中曾有短暂偏移。 |
| 正常取消 / 退出 | 列表图钉、窗口角标取消已有记录；正常退出走清理路径。 |
| 异常退出恢复 | 2026-09-30 验证了主进程 SIGKILL 后 helper 清理，以及主进程与 helper 同时结束后的下次启动恢复。属于该次环境的历史结论。 |
| 目标窗口关闭 / 目标应用退出 | 代码检查窗口与进程身份并尝试清理；完整用户流程与目标应用重启后的窗口重建尚未验收。 |
| 权限 | 已授权、未授权提示及开发构建重新授权有记录；首次拒绝、撤销、重新授予的完整流程尚未全面回归。 |
| 桌面选择 | 实体鼠标悬停、边框与点击选择有历史记录；提示按钮取消已有验证。自动化输入曾未经过 CGEventTap，不能用它确认实体 Esc 通过或失败。 |
| 菜单 / 输入法候选窗 | 已知存在被置顶窗口遮挡的情况；复杂 popover、拖拽、右键与中文输入仍需回归。 |
| 多显示器 / 跨屏 / 多桌面 / Mission Control / 全屏 / 系统安全窗口 | 尚未完整验证。 |
| 睡眠唤醒 / 目标应用重新启动 / 登录时打开 | 尚未完整验证；登录启动开关存在不等于重新登录已实测。 |
| 其他系统 / Intel / 其他 Xcode | macOS 14–26、其他 macOS 版本、Intel Mac 与其他 Xcode 版本尚未完整验证。 |

## 记录索引

历史记录保留当时的 UI 名称、构建与验收过程；当前操作以 README 与源码为准。

| 记录 | 主要内容 |
| --- | --- |
| [2026-09-30 开发验收](acceptance-2026-09-30.md) | 原窗口排序、三窗口、同应用双窗口、最小化、异常恢复、针模式、角标与权限；从研究开发仓库迁入的历史证据 |
| [0.1.3 界面与角标跟随](acceptance-2026-10-03.md) | SF Symbols、窗口移动与角标位置、直接取消 |
| [0.1.4 按钮对齐与操作](acceptance-2026-10-03-alignment.md) | 多窗口、移动、缩放、文本输入与清理 |
| [0.1.5 界面一致性](acceptance-2026-10-04-ui.md) | 当时的按钮、布局、选择提示与角标取消 |
| [0.1.6 启动与退出](acceptance-2026-10-04-discovery.md) | 重复实例、启动显示、旧界面退出按钮、授权与包检查 |
| [0.1.7 原生界面](acceptance-2026-10-04-native-ui.md) | 当前工具栏、表格、设置、快捷键、浅深色与一次 helper 就绪失败；附构建配置结论修正 |
| [2026-10-04 仓库文档复核](audit-2026-10-04-documentation.md) | 当前构建、既有诊断测试、版本、文档链接与证据边界 |

## 运行现有夹具

项目没有配置 XCTest test target，共享 scheme 的 Testables 为空。`xcodebuild test` 会报告 scheme 未配置 test action，不应写成自动测试通过。现有测试使用临时 AppKit 应用、应用内诊断入口与人工界面检查；暂未建立 CI。

先运行 `./scripts/build_app.sh`，再准备临时窗口：

```sh
python3 Tests/fixture/setup.py
python3 Tests/fixture_c.py
python3 Tests/fixture_same.py
```

这些脚本不是测试断言，只负责构建并启动夹具。状态写入 `/tmp/pintop-no-sip-lab/A.json`、`B.json`、`C.json` 和 `same.json`；从当次状态读取窗口 ID 后，使用：

```sh
build/PinTop.app/Contents/MacOS/PinTop --smoke-pin WINDOW_ID 1
build/PinTop.app/Contents/MacOS/PinTop --smoke-multi A_ID B_ID
build/PinTop.app/Contents/MacOS/PinTop --smoke-three A_ID B_ID C_ID
build/PinTop.app/Contents/MacOS/PinTop --smoke-same FIRST_ID SECOND_ID /tmp/pintop-no-sip-lab/same-command
build/PinTop.app/Contents/MacOS/PinTop --smoke-suspend FIRST_ID /tmp/pintop-no-sip-lab/same-command
```

替换占位符，确保目标窗口可见。`same-command` 的 `m` / `d` 指令只控制第一个窗口，所以 suspend 测试必须使用 `same.json` 的 `first`；测试另一个窗口会得到无效的失败结果。诊断入口绕过主应用单实例锁，仅对临时夹具运行，避免与正在使用的已置顶窗口混用。

诊断命令被 `#if DEBUG` 包围，但当前工程的 **Debug 和 Release 均显式定义了 `DEBUG`**，因此它们目前也会进入 Release。本次只整理文档，没有调整构建行为；原生 UI 记录中的相反结论已加注修正。

完成后先取消夹具置顶，再结束临时应用：

```sh
python3 Tests/fixture/setup.py --stop
python3 Tests/fixture_c.py --stop
python3 Tests/fixture_same.py --stop
```

## 文档维护

README 保留长期使用流程与测试摘要；版本变化写入 CHANGELOG，复现步骤与环境写在本目录。历史未测项不会因为界面更新或构建成功而自动变为通过。新增记录请注明源码版本、实际构建、测试环境、结果和未覆盖项。
