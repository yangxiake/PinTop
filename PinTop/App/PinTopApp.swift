import AppKit
import ApplicationServices
import Darwin
import ServiceManagement

@MainActor private enum StartupLock {
    private static var descriptor: Int32 = -1

    static func acquire() throws -> Bool {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PinTop", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("main.lock").path
        let file = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard file >= 0 else { throw PinError.invalid("无法创建单实例锁文件") }
        guard flock(file, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(file)
            return false
        }
        descriptor = file
        return true
    }
}

@main struct PinTopApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--recovery-helper" {
            app.finishLaunching()
            do {
                try RecoveryHelper.run(journalURL: URL(fileURLWithPath: CommandLine.arguments[2]),
                                       nonce: CommandLine.arguments[3])
            } catch {
                fputs("PinTop recovery: \(error)\n", stderr)
                exit(1)
            }
            return
        }
        #if DEBUG
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--probe-needle" {
            app.finishLaunching()
            let trusted = AXWindowCatalog.permission(prompt: false)
            var result = "AX_TRUSTED=\(trusted) NEEDLE_TAP="
            if trusted {
                do {
                    let needle = try NeedleController(onSelect: { _ in }, onError: { _ in })
                    try needle.start()
                    result += "available"
                    needle.stop()
                } catch { result += "unavailable: \(error.localizedDescription)" }
            } else { result += "not_tested" }
            do { try Data(result.utf8).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic) }
            catch { fputs("PROBE ERROR: \(error)\n", stderr) }
            return
        }
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--probe-needle-ui" {
            app.finishLaunching()
            let output = URL(fileURLWithPath: CommandLine.arguments[2])
            let timeout = min(max(Double(CommandLine.arguments[3]) ?? 10, 1), 30)
            var result = "TIMEOUT"
            do {
                let needle = try NeedleController(onSelect: { id in result = "SELECTED=\(id)" },
                                                  onError: { message in result = "ERROR=\(message)" })
                try needle.start()
                let deadline = Date().addingTimeInterval(timeout)
                while Date() < deadline, needle.isActive, result == "TIMEOUT" {
                    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                }
                if result == "TIMEOUT", !needle.isActive { result = "CANCELLED" }
                result += " EVENTS=\(needle.eventCount) HOVER=\(needle.hoverWindowID ?? 0)"
                needle.stop()
            } catch { result = "ERROR=\(error.localizedDescription)" }
            do { try Data(result.utf8).write(to: output, options: .atomic) }
            catch { fputs("PROBE UI ERROR: \(error)\n", stderr) }
            return
        }
        if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--permission-probe" {
            app.finishLaunching()
            print("AX_TRUSTED=\(AXWindowCatalog.permission(prompt: false))")
            return
        }
        if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--smoke-pin",
           let id = UInt32(CommandLine.arguments[2]) {
            app.finishLaunching()
            do {
                let coordinator = try PinCoordinator()
                try coordinator.pin(id)
                print("SMOKE PIN OK id=\(id)")
                fflush(stdout)
                let seconds = CommandLine.arguments.count >= 4 ? (Double(CommandLine.arguments[3]) ?? 8) : 8
                RunLoop.current.run(until: Date().addingTimeInterval(seconds))
                try coordinator.unpin(id)
                print("SMOKE UNPIN OK id=\(id)")
                fflush(stdout)
                exit(0)
            } catch {
                fputs("SMOKE ERROR: \(error)\n", stderr)
                exit(1)
            }
        }
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--smoke-multi",
           let first = UInt32(CommandLine.arguments[2]), let second = UInt32(CommandLine.arguments[3]) {
            app.finishLaunching()
            do {
                let coordinator = try PinCoordinator()
                defer { coordinator.unpinAll() }
                try coordinator.pin(first)
                print("MULTI FIRST OK id=\(first)")
                if let pid = WindowCatalog.owner(id: second) {
                    _ = NSRunningApplication(processIdentifier: pid)?.activate()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                try coordinator.pin(second)
                print("MULTI SECOND OK id=\(second)")
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
                for (index, row) in rows.enumerated() {
                    if let id = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                       id == first || id == second { print("MULTI ORDER index=\(index) id=\(id)") }
                }
                try coordinator.unpin(first)
                guard coordinator.entries[second] != nil else { throw PinError.invalid("第二个 pin 被误取消") }
                print("MULTI INDEPENDENT CANCEL OK")
                exit(0)
            } catch { fputs("MULTI ERROR: \(error)\n", stderr); exit(1) }
        }
        if CommandLine.arguments.count == 5, CommandLine.arguments[1] == "--smoke-three",
           let first = UInt32(CommandLine.arguments[2]),
           let second = UInt32(CommandLine.arguments[3]),
           let third = UInt32(CommandLine.arguments[4]) {
            app.finishLaunching()
            do {
                let coordinator = try PinCoordinator()
                let ids = [first, second, third]
                for id in ids {
                    if let pid = WindowCatalog.owner(id: id) {
                        _ = NSRunningApplication(processIdentifier: pid)?.activate()
                    }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
                    try coordinator.pin(id)
                    print("THREE PIN OK id=\(id)")
                }
                let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
                let order = rows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
                    .filter { ids.contains($0) }
                print("THREE ORDER \(order)")
                guard order == [third, second, first] else { throw PinError.invalid("三窗口排序不符") }
                if let pid = WindowCatalog.owner(id: first) {
                    _ = NSRunningApplication(processIdentifier: pid)?.activate()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
                let reorderedRows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
                let reordered = reorderedRows.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
                    .filter { ids.contains($0) }
                print("THREE AFTER ACTIVATE FIRST \(reordered)")
                try coordinator.unpin(second)
                guard coordinator.entries[first] != nil, coordinator.entries[third] != nil else {
                    throw PinError.invalid("取消中间 pin 误伤其他窗口")
                }
                coordinator.unpinAll()
                print("THREE INDEPENDENT CANCEL OK")
                exit(0)
            } catch { fputs("THREE ERROR: \(error)\n", stderr); exit(1) }
        }
        if CommandLine.arguments.count == 5, CommandLine.arguments[1] == "--smoke-same",
           let first = UInt32(CommandLine.arguments[2]), let second = UInt32(CommandLine.arguments[3]) {
            app.finishLaunching()
            do {
                let coordinator = try PinCoordinator()
                try coordinator.pin(first)
                print("SAME FIRST OK id=\(first)")
                try Data("2-\(UUID().uuidString)".utf8)
                    .write(to: URL(fileURLWithPath: CommandLine.arguments[4]), options: .atomic)
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                try coordinator.pin(second)
                print("SAME SECOND OK id=\(second)")
                try coordinator.unpin(first)
                guard try coordinator.membershipVerified(second) else {
                    throw PinError.invalid("同应用窗口取消误伤")
                }
                coordinator.unpinAll()
                print("SAME INDEPENDENT CANCEL OK")
                exit(0)
            } catch { fputs("SAME ERROR: \(error)\n", stderr); exit(1) }
        }
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--smoke-suspend",
           let id = UInt32(CommandLine.arguments[2]) {
            app.finishLaunching()
            do {
                let coordinator = try PinCoordinator()
                let command = URL(fileURLWithPath: CommandLine.arguments[3])
                try coordinator.pin(id)
                try Data("m-\(UUID().uuidString)".utf8).write(to: command, options: .atomic)
                RunLoop.current.run(until: Date().addingTimeInterval(0.8))
                coordinator.reconcile()
                guard coordinator.entries[id]?.pin.visible == false else {
                    throw PinError.invalid("最小化后未暂停置顶")
                }
                print("SUSPEND HIDDEN OK")
                try Data("d-\(UUID().uuidString)".utf8).write(to: command, options: .atomic)
                RunLoop.current.run(until: Date().addingTimeInterval(0.8))
                coordinator.reconcile()
                guard coordinator.entries[id]?.pin.visible == true,
                      try coordinator.membershipVerified(id) else {
                    throw PinError.invalid("还原窗口后未恢复置顶")
                }
                print("SUSPEND RESUMED OK")
                try coordinator.unpin(id)
                exit(0)
            } catch { fputs("SUSPEND ERROR: \(error)\n", stderr); exit(1) }
        }
        #endif
        do {
            guard try StartupLock.acquire() else {
                app.finishLaunching()
                let alert = NSAlert()
                alert.messageText = "PinTop 已在运行"
                alert.informativeText = "请从程序坞或菜单栏打开正在运行的 PinTop。可通过 PinTop 菜单或 ⌘Q 退出。"
                alert.runModal()
                return
            }
        } catch {
            fputs("PinTop startup: \(error)\n", stderr)
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: PinCoordinator?
    private var statusItem: NSStatusItem?
    private var popupMenu: NSMenu?
    private var timer: Timer?
    private var needle: NeedleController?
    private let badges = BadgeController()
    private let controlPanel = ControlPanelController()
    private let settingsPanel = SettingsPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let coordinator = try PinCoordinator()
            self.coordinator = coordinator
            badges.configure(bridge: try SLSBridge())
            badges.isEnabled = (UserDefaults.standard.object(forKey: "ShowPinBadges") as? Bool) ?? true
            if (UserDefaults.standard.object(forKey: "ShowDockIcon") as? Bool) ?? true {
                _ = NSApp.setActivationPolicy(.regular)
            }
            do {
                let recoveryProblems = try RecoveryHelper.recoverAbandoned()
                if !recoveryProblems.isEmpty {
                    showError("有旧置顶资源需要人工检查：\n" + recoveryProblems.joined(separator: "\n"))
                }
            } catch { showError("启动恢复检查失败：\(error.localizedDescription)") }
            self.needle = try NeedleController(onSelect: { [weak self] id in
                do {
                    if let pid = WindowCatalog.owner(id: id),
                       NSWorkspace.shared.frontmostApplication?.processIdentifier != pid {
                        _ = NSRunningApplication(processIdentifier: pid)?.activate()
                        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                    }
                    try self?.coordinator?.toggle(id)
                }
                catch { self?.showError(error.localizedDescription) }
            }, onError: { [weak self] message in self?.showError(message) })
            coordinator.onChange = { [weak self] in
                self?.rebuildMenu()
                self?.badges.synchronize(coordinator.entries)
                self?.refreshPanel()
            }
            badges.onUnpin = { [weak self] id in
                do { try self?.coordinator?.unpin(id) }
                catch { self?.showError(error.localizedDescription) }
            }
            badges.onError = { [weak self] id, message in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    do { try self.coordinator?.unpin(id) }
                    catch { self.showError("窗口置顶标记失败，自动取消也失败：\(error.localizedDescription)"); return }
                    self.showError("窗口置顶已取消：\(message)")
                }
            }
            coordinator.onError = { [weak self] message in self?.showError(message) }
            controlPanel.onToggle = { [weak self] id in self?.toggleFromPanel(id) }
            controlPanel.onStartNeedle = { [weak self] in self?.startNeedle() }
            controlPanel.onUnpinAll = { [weak self] in self?.coordinator?.unpinAll() }
            controlPanel.onRefresh = { [weak self] in self?.refreshPanel() }
            controlPanel.onRequestPermission = { [weak self] in
                _ = AXWindowCatalog.permission(prompt: true)
                self?.refreshPanel()
            }
            controlPanel.onShowSettings = { [weak self] in self?.showSettings() }
            settingsPanel.onBadgeChange = { [weak self] enabled in
                UserDefaults.standard.set(enabled, forKey: "ShowPinBadges")
                self?.badges.isEnabled = enabled
                self?.badges.synchronize(coordinator.entries)
            }
            settingsPanel.onDockChange = { [weak self] enabled in
                if NSApp.setActivationPolicy(enabled ? .regular : .accessory) {
                    UserDefaults.standard.set(enabled, forKey: "ShowDockIcon")
                }
                self?.refreshPanel()
            }
            settingsPanel.onLoginChange = { [weak self] enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch { self?.showError("开机启动设置失败：\(error.localizedDescription)") }
                self?.refreshPanel()
            }
            buildMainMenu()
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem = item
            item.button?.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "PinTop")
            item.button?.imagePosition = .imageLeft
            item.button?.title = "PinTop"
            item.button?.toolTip = "PinTop · 点按打开窗口列表，右键显示菜单"
            item.button?.target = self
            item.button?.action = #selector(statusClicked)
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            rebuildMenu()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.coordinator?.reconcile()
                }
            }
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(desktopChanged),
                                                               name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(desktopChanged),
                                                   name: NSApplication.didChangeScreenParametersNotification, object: nil)
            showPanel()
        } catch { showError("PinTop 无法启动：\(error.localizedDescription)") }
    }

    @objc private func desktopChanged() { coordinator?.reconcile() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            rebuildMenu()
            if let button = statusItem?.button, let menu = popupMenu {
                button.menu = menu
                button.performClick(nil)
                button.menu = nil
            }
        } else { showPanel() }
    }

    private func rebuildMenu() {
        guard let item = statusItem else { return }
        let menu = NSMenu()
        let select = NSMenuItem(title: "添加窗口…", action: #selector(startNeedle), keyEquivalent: "")
        select.target = self
        menu.addItem(select)
        let permission = NSMenuItem(title: AXWindowCatalog.permission(prompt: false) ?
            "辅助功能：已授权" : "辅助功能：待授权", action: nil, keyEquivalent: "")
        permission.isEnabled = false
        menu.addItem(permission)
        let front = NSMenuItem(title: "钉住或取消当前窗口", action: #selector(pinFrontmost), keyEquivalent: "")
        front.target = self
        menu.addItem(front)
        let panel = NSMenuItem(title: "打开窗口列表…", action: #selector(showPanel), keyEquivalent: "")
        panel.target = self
        menu.addItem(panel)
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        if let coordinator {
            for entry in coordinator.entries.values.sorted(by: { $0.pin.title < $1.pin.title }) {
                let id = entry.pin.identity.windowID
                let row = NSMenuItem(title: "取消 · \(entry.pin.title)", action: #selector(unpinMenuItem(_:)), keyEquivalent: "")
                row.target = self
                row.representedObject = NSNumber(value: id)
                menu.addItem(row)
            }
            if coordinator.entries.isEmpty {
                let empty = NSMenuItem(title: "暂无已钉窗口", action: nil, keyEquivalent: "")
                empty.isEnabled = false
                menu.addItem(empty)
            }
        }
        menu.addItem(.separator())
        let all = NSMenuItem(title: "全部取消置顶", action: #selector(unpinAll), keyEquivalent: "")
        all.target = self
        all.isEnabled = !(coordinator?.entries.isEmpty ?? true)
        menu.addItem(all)
        let help = NSMenuItem(title: "注意：菜单或候选窗可能被遮挡…", action: #selector(showLimit), keyEquivalent: "")
        help.target = self
        menu.addItem(help)
        let quit = NSMenuItem(title: "退出 PinTop", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        popupMenu = menu
        item.button?.image = NSImage(systemSymbolName: coordinator?.entries.isEmpty == false ? "pin.fill" : "pin",
                                     accessibilityDescription: "PinTop")
    }

    @objc private func startNeedle() {
        controlPanel.hide()
        do { try needle?.start() }
        catch {
            showError(error.localizedDescription)
            showPanel()
        }
    }

    @objc private func showPanel() {
        refreshPanel()
        controlPanel.show()
    }

    @objc private func showSettings() {
        refreshPanel()
        settingsPanel.show()
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "PinTop")
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 PinTop", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        main.addItem(appItem)
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        let add = NSMenuItem(title: "添加窗口…", action: #selector(startNeedle), keyEquivalent: "n")
        add.target = self
        fileMenu.addItem(add)
        let close = NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(close)
        main.addItem(fileItem)
        fileItem.submenu = fileMenu

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "显示")
        let refresh = NSMenuItem(title: "刷新窗口列表", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refresh.target = self
        viewMenu.addItem(refresh)
        let unpin = NSMenuItem(title: "全部取消置顶", action: #selector(unpinAll), keyEquivalent: "")
        unpin.target = self
        viewMenu.addItem(unpin)
        main.addItem(viewItem)
        viewItem.submenu = viewMenu
        NSApp.mainMenu = main
    }

    @objc private func refreshFromMenu() { refreshPanel() }

    private func refreshPanel() {
        let pins = coordinator?.entries ?? [:]
        let pinnedIDs = pins.keys.sorted()
        let visibleIDs = WindowCatalog.visibleOrdinary(ownPID: getpid())
            .filter { pins[$0] == nil }
        let ids = pinnedIDs + visibleIDs
        let names = ids.map { id in
            let app = (WindowCatalog.row(id: id)?[kCGWindowOwnerName as String] as? String) ?? "应用"
            return (app, AXWindowCatalog.windowTitle(id: id))
        }
        let keys = names.map { "\($0.0)\u{1F}\($0.1)" }
        let counts = Dictionary(keys.map { ($0, 1) }, uniquingKeysWith: +)
        let choices = zip(ids, names).map { id, name in
            let key = "\(name.0)\u{1F}\(name.1)"
            let detail = counts[key, default: 0] > 1 ? "\(name.1) · 窗口 \(id)" : name.1
            let icon = WindowCatalog.owner(id: id).flatMap {
                NSRunningApplication(processIdentifier: $0)?.icon
            }
            return ControlPanelController.Choice(id: id, appName: name.0, windowTitle: detail,
                                                 pinned: pins[id] != nil, icon: icon)
        }
        let loginStatus = SMAppService.mainApp.status
        let loginEnabled = loginStatus == .enabled || loginStatus == .requiresApproval
        controlPanel.update(permission: AXWindowCatalog.permission(prompt: false), choices: choices)
        settingsPanel.update(badge: badges.isEnabled,
                             dock: NSApp.activationPolicy() == .regular,
                             login: loginEnabled)
    }

    private func toggleFromPanel(_ id: UInt32) {
        let wasPinned = coordinator?.entries[id] != nil
        if !wasPinned { controlPanel.hide() }
        do {
            if !wasPinned, !AXWindowCatalog.permission(prompt: true) {
                throw PinError.invalid("请先在系统设置中授权 PinTop 控制其他应用")
            }
            if !wasPinned, let pid = WindowCatalog.owner(id: id) {
                _ = NSRunningApplication(processIdentifier: pid)?.activate()
                if let target = AXWindowCatalog.windowElement(id: id) {
                    _ = AXUIElementPerformAction(target, kAXRaiseAction as CFString)
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            }
            try coordinator?.toggle(id)
        } catch {
            showError(error.localizedDescription)
            if !wasPinned { showPanel() }
        }
    }

    @objc private func pinFrontmost() {
        do {
            try coordinator?.pinFrontmost()
        } catch { showError(error.localizedDescription) }
    }

    @objc private func unpinMenuItem(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? NSNumber)?.uint32Value else { return }
        do { try coordinator?.unpin(id) } catch { showError(error.localizedDescription) }
    }

    @objc private func unpinAll() { coordinator?.unpinAll() }

    @objc private func showLimit() {
        let alert = NSAlert()
        alert.messageText = "窗口置顶的已知限制"
        alert.informativeText = "已钉窗口可能遮挡其他应用的菜单或输入法候选窗。遇到这种情况，可先取消钉住；菜单兼容仍在实验阶段。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "PinTop"
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        needle?.stop()
        badges.clear()
        coordinator?.unpinAll()
    }
}
