# Contributing to PinTop

## Reporting bugs

请在 [Issues](https://github.com/yangxiake/PinTop/issues) 中提供：

- macOS 版本、Mac 型号和芯片（Apple Silicon / Intel）；
- PinTop 版本、build number 或源码 commit，并说明使用的是下载包还是本地构建；
- 目标应用名称与版本；
- 复现步骤、预期结果和实际结果。

涉及窗口行为时，请补充是否使用多显示器、多个 Desktop / Space、同应用多个窗口；是否最小化过窗口、经历睡眠唤醒或重新启动过目标应用。提供截图或日志前请移除私密窗口标题、文件路径和其他个人信息。

测试范围与已知缺口见 [Tests/TESTING.md](Tests/TESTING.md)，授权和启动问题见 [Troubleshooting](docs/TROUBLESHOOTING.md)。未测过的环境也可以反馈，请注明实际观察，不把能够启动或编译等同于功能通过。

## Pull requests

- 一个 PR 尽量解决一个问题，不顺便大规模格式化无关代码。
- 说明具体问题、修改后的行为和验证结果。
- 修改窗口层级、Space 管理、Accessibility 或 recovery 时，说明 macOS、硬件、显示器 / Space 配置与实际测试场景。
- 确保 `./scripts/build_app.sh` 可以构建；如有相关夹具或回归测试，补充结果及未覆盖项。
- 保持 README 对当前用户流程的描述准确；版本变化写入 [CHANGELOG](CHANGELOG.md)，详细测试记录写入 `Tests/`。不要把计划功能写成已实现，也不要把开发版本自动视为已发布版本。

项目只有共享的 `PinTop` scheme，目前没有配置 XCTest test target；现有窗口夹具和诊断入口见 [测试说明](Tests/TESTING.md)。
