# 仓库文档复核 · 2026-10-04

源码基线：公开仓库 `e16119d`，0.1.7（build 8）。本次变更只整理文档，不修改应用代码、工程版本或发布新版本。

环境：MacBook Air（Mac17,4）/ Apple M5、16 GB 内存、单内置显示器；macOS 27.0.1（26A434）、Xcode 27.0（27A266a）、Apple Swift 6.4，工程使用 Swift 6 语言模式；SIP 开启。

## 原窗口能力审查

| 描述 | 当前依据 |
| --- | --- |
| 置顶原窗口 | `PinCoordinator` 保存目标 CGWindowID、进程启动身份与原 Space，为该窗口增加辅助 Space 成员关系；检查成员关系与 CG 排序，取消时撤销添加的关系。 |
| 没有截图 / 镜像替代 | 应用源码没有目标画面捕获或镜像渲染路径。`CGWindowListCopyWindowInfo` 读取窗口元数据，提示边框和角标是 PinTop 自己的操作界面。 |
| 没有目标进程代码注入 | `SLSBridge` 在 PinTop 自身进程运行时加载 SkyLight，通过 WindowServer bridge 操作窗口；helper 也是 PinTop 自身可执行文件，没有注入目标应用。 |
| 不要求关闭 SIP | 当前构建与窗口夹具测试在 SIP 开启的环境完成；代码未要求调整 SIP 或安装目标进程内插件。 |

## 构建与现有测试

| 检查 | 实际结果 |
| --- | --- |
| `./scripts/build_app.sh` | Debug 构建通过，脚本内 `codesign --verify --deep --strict` 通过；权限探针返回 `AX_TRUSTED=true`。 |
| Xcode Release build | 通过，ad-hoc 签名校验通过；默认 Release 构建含 x86_64 / arm64。仅在这台 arm64 Mac 运行过诊断，x86_64 可编译不代表 Intel 运行验收。打包脚本另行限制为 arm64。 |
| `--smoke-pin` | 原窗口置顶与取消成功。 |
| `--smoke-multi` | 不同应用双窗口置顶、单项取消互不影响成功。 |
| `--smoke-three` | 三窗口排序、重新激活第一个窗口及中间窗口独立取消成功。 |
| `--smoke-same` | 同应用双窗口置顶，取消第一个后第二个成员关系保持成功。 |
| `--smoke-suspend` | 使用 `same.json` 的 `first` 后，最小化暂停与还原恢复成功。首次误用 `second` 返回失败，因为夹具 `m` 指令只最小化第一个窗口；这是无效测试输入，不作为应用回归失败。 |
| XCTest | 执行 `xcodebuild test` 返回退出码 66：`Scheme PinTop is not currently configured for the test action.` 没有配置 XCTest target，不能记为通过。 |
| 测试清理 | 本次夹具的恢复记录为解除守护或 helper `PASS`，没有存活的夹具恢复进程；临时应用在测试后停止。 |

诊断使用本次公开仓库 Debug 构建与既有夹具，未增加替代实现的测试。完整桌面选择需要真实输入；没有使用模拟 Esc 来确认实体键盘行为。

## 当前界面核对

运行中的 0.1.7 开发构建与公开仓库 `PinTop/` 源码逐文件比较一致。实际窗口和可访问性信息确认：

- 工具栏为“添加窗口…”、刷新、更多、设置；列表使用图钉切换，已经没有旧控制面板的文字动作按钮或“退出程序”按钮。
- 在列表置顶临时 AppKit 窗口后，控制窗口收起，目标窗口出现“取消置顶”角标；点击角标后，列表刷新为 0 个已置顶。
- `⌘R` 刷新，`⌘N` 显示“点按窗口以置顶 · Esc 退出”提示，“取消选择”按钮能退出。
- 设置为独立窗口，保留“显示窗口角标”“在程序坞中显示”“登录时打开”，`⌘W` 可关闭设置。
- 其余应用菜单、双击行切换、菜单栏左右键路径与 `⌘,` / `⌘Q` 对照当前源码和同日原生 UI 记录核实；本轮未重复退出正在使用的主应用。

仓库中只有应用图标资源，没有可确认属于当前界面的 UI 截图，因此 README 未加入图片。

## 版本与文档一致性

- 工程 Debug / Release 的 Marketing Version 与 Info.plist 均为 0.1.7，Build Number 均为 8；本次 Release 产物读回相同。
- 初次 GitHub API 查询返回 0.1.0–0.1.6 共七个已发布预览版，最新为 `v0.1.6-preview`；0.1.7 没有对应 Release。源码先于发布包是开发状态差异，不通过新建 tag 或 Release 掩盖。
- README 中 0.1.3 / 0.1.7 的界面变更移入 CHANGELOG；本机验收细节归入测试索引；定向权限重置与重复实例处理移到 Troubleshooting。
- 公开仓库原 README 指向缺失的 `acceptance-2026-09-30.md`，现从研究开发仓库迁入原记录并注明历史目录与 UI 语义。
- 原生 UI 记录曾声称诊断入口不进入 Release。复核发现 Release 配置显式定义 `DEBUG`，因此该结论已加注纠正，构建设置保留原状。
- README、CHANGELOG、CONTRIBUTING、测试索引和 Troubleshooting 的本地文件链接及标题锚点通过检查。
- MIT LICENSE 保持原样；已跟踪文件及本次文档未发现常见凭据格式。构建产物、DerivedData、dist、`.DS_Store`、`xcuserdata` 和用户状态均被现有 `.gitignore` 排除，无需新增忽略规则。

本次没有重新验收多显示器、多个 Desktop / Space、全屏、睡眠唤醒、目标应用重启、实体 Esc、登录启动或其他系统 / 硬件。异常退出及下次启动恢复仍引用 2026-09-30 历史实测，不把文档复核当作完整产品验收。
