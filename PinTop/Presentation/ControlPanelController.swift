import AppKit

@MainActor final class ControlPanelController: NSObject {
    struct Choice {
        let id: UInt32
        let appName: String
        let windowTitle: String
        let pinned: Bool
        let icon: NSImage?
    }

    private let window: NSWindow
    private let windowList = NSStackView()
    private let listScroll = NSScrollView()
    private var listHeightConstraint: NSLayoutConstraint?
    private let permissionButton = PinTopButton(frame: .zero)
    private let countLabel = NSTextField(labelWithString: "")
    private let unpinAllButton = PinTopButton(frame: .zero)
    private let badgeSwitch = NSSwitch()
    private let dockSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()

    var onToggle: ((UInt32) -> Void)?
    var onStartNeedle: (() -> Void)?
    var onUnpinAll: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onQuit: (() -> Void)?
    var onBadgeChange: ((Bool) -> Void)?
    var onDockChange: ((Bool) -> Void)?
    var onLoginChange: ((Bool) -> Void)?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 590),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "PinTop"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()
        buildContent()
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() { window.orderOut(nil) }

    func update(permission: Bool, choices: [Choice], badge: Bool, dock: Bool, login: Bool) {
        permissionButton.title = permission ? "已授权" : "需要授权"
        permissionButton.image = PinTopButton.symbol(permission ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                                                    description: "辅助功能权限")
        permissionButton.foregroundColor = permission ? .systemGreen : .systemOrange
        badgeSwitch.state = badge ? .on : .off
        dockSwitch.state = dock ? .on : .off
        loginSwitch.state = login ? .on : .off
        let pinnedCount = choices.filter(\.pinned).count
        countLabel.stringValue = "\(pinnedCount) 个已置顶 · \(choices.count) 个窗口"
        unpinAllButton.isEnabled = pinnedCount > 0
        listHeightConstraint?.constant = min(220, max(120, CGFloat(choices.count) * 58))

        for view in windowList.arrangedSubviews {
            windowList.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        if choices.isEmpty {
            let empty = NSTextField(labelWithString: "当前桌面没有可置顶的普通窗口")
            empty.textColor = .secondaryLabelColor
            empty.alignment = .center
            empty.frame = NSRect(x: 0, y: 0, width: 512, height: 58)
            windowList.addArrangedSubview(empty)
        } else {
            for choice in choices { windowList.addArrangedSubview(makeRow(choice)) }
        }
        windowList.setFrameSize(NSSize(width: 512,
                                        height: max(220, CGFloat(max(choices.count, 1)) * 58)))
        windowList.needsLayout = true
        window.contentView?.layoutSubtreeIfNeeded()
        let top = windowList.isFlipped ? 0 : max(0, windowList.bounds.height - listScroll.contentView.bounds.height)
        listScroll.contentView.scroll(to: NSPoint(x: 0, y: top))
        listScroll.reflectScrolledClipView(listScroll.contentView)
    }

    private func buildContent() {
        guard let content = window.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ])

        let mark = NSView()
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.wantsLayer = true
        mark.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        mark.layer?.cornerRadius = 11
        let pin = imageView("pin.fill", size: 22, color: .white)
        mark.addSubview(pin)
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 44),
            mark.heightAnchor.constraint(equalToConstant: 44),
            pin.centerXAnchor.constraint(equalTo: mark.centerXAnchor),
            pin.centerYAnchor.constraint(equalTo: mark.centerYAnchor)
        ])

        let title = NSTextField(labelWithString: "PinTop")
        title.font = .systemFont(ofSize: 21, weight: .bold)
        let subtitle = NSTextField(labelWithString: "让重要窗口留在眼前")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        let headerSpacer = NSView()
        permissionButton.heightAnchor.constraint(equalToConstant: PinTopButton.standardHeight).isActive = true
        permissionButton.widthAnchor.constraint(equalToConstant: PinTopButton.standardWidth).isActive = true
        permissionButton.target = self
        permissionButton.action = #selector(requestPermission)
        let header = NSStackView(views: [mark, titleStack, headerSpacer, permissionButton])
        header.alignment = .centerY
        header.spacing = 12
        addWide(header, to: root)

        let choose = actionButton("选择窗口", icon: "pin.fill", action: #selector(startNeedle))
        choose.style = .primary
        choose.heightAnchor.constraint(equalToConstant: PinTopButton.standardHeight).isActive = true
        choose.widthAnchor.constraint(equalToConstant: PinTopButton.standardWidth).isActive = true
        let refresh = actionButton("刷新", icon: "arrow.clockwise", action: #selector(refresh))
        refresh.heightAnchor.constraint(equalToConstant: PinTopButton.standardHeight).isActive = true
        refresh.widthAnchor.constraint(equalToConstant: PinTopButton.standardWidth).isActive = true
        unpinAllButton.title = "全部取消"
        unpinAllButton.image = PinTopButton.symbol("pin.slash", description: "取消置顶")
        unpinAllButton.heightAnchor.constraint(equalToConstant: PinTopButton.standardHeight).isActive = true
        unpinAllButton.widthAnchor.constraint(equalToConstant: PinTopButton.standardWidth).isActive = true
        unpinAllButton.target = self
        unpinAllButton.action = #selector(unpinAll)
        let actionSpacer = NSView()
        let actions = NSStackView(views: [choose, refresh, actionSpacer, unpinAllButton])
        actions.alignment = .centerY
        actions.spacing = 8
        addWide(actions, to: root)

        let listTitle = NSTextField(labelWithString: "窗口")
        listTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        let listSpacer = NSView()
        let listHeader = NSStackView(views: [listTitle, listSpacer, countLabel])
        listHeader.alignment = .centerY
        addWide(listHeader, to: root)

        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = true
        listScroll.backgroundColor = .controlBackgroundColor
        listScroll.wantsLayer = true
        listScroll.layer?.cornerRadius = 11
        listScroll.layer?.masksToBounds = true
        listScroll.layer?.borderWidth = 1
        listScroll.layer?.borderColor = NSColor.separatorColor.cgColor
        windowList.orientation = .vertical
        windowList.alignment = .leading
        windowList.spacing = 0
        windowList.frame = NSRect(x: 0, y: 0, width: 512, height: 220)
        listScroll.documentView = windowList
        addWide(listScroll, to: root)
        listHeightConstraint = listScroll.heightAnchor.constraint(equalToConstant: 220)
        listHeightConstraint?.isActive = true

        let settingsTitle = NSTextField(labelWithString: "偏好设置")
        settingsTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        let settingsIcon = imageView("gearshape", size: 14, color: .secondaryLabelColor)
        let settingsHeader = NSStackView(views: [settingsIcon, settingsTitle])
        settingsHeader.alignment = .centerY
        settingsHeader.spacing = 7
        addWide(settingsHeader, to: root)

        badgeSwitch.target = self
        badgeSwitch.action = #selector(changeBadge)
        dockSwitch.target = self
        dockSwitch.action = #selector(changeDock)
        loginSwitch.target = self
        loginSwitch.action = #selector(changeLogin)
        let settings = NSStackView(views: [settingRow("窗口取消角标", icon: "pin.circle", control: badgeSwitch),
                                            settingRow("在程序坞显示", icon: "dock.rectangle", control: dockSwitch),
                                            settingRow("登录时启动", icon: "power", control: loginSwitch)])
        settings.orientation = .vertical
        settings.alignment = .leading
        settings.spacing = 5
        addWide(settings, to: root)

        let warningIcon = imageView("exclamationmark.triangle", size: 13, color: .systemOrange)
        let warning = NSTextField(labelWithString: "已钉窗口可能遮挡其他应用的菜单或输入法候选窗")
        warning.font = .systemFont(ofSize: 11)
        warning.textColor = .secondaryLabelColor
        let footerSpacer = NSView()
        let quit = actionButton("退出程序", icon: "power", action: #selector(quit))
        quit.heightAnchor.constraint(equalToConstant: PinTopButton.standardHeight).isActive = true
        quit.widthAnchor.constraint(equalToConstant: PinTopButton.standardWidth).isActive = true
        quit.toolTip = "退出 PinTop 并取消所有置顶"
        let footer = NSStackView(views: [warningIcon, warning, footerSpacer, quit])
        footer.alignment = .centerY
        footer.spacing = 7
        addWide(footer, to: root)
    }

    private func addWide(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func settingRow(_ title: String, icon: String, control: NSSwitch) -> NSView {
        let symbolView = imageView(icon, size: 15, color: .secondaryLabelColor)
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        let spacer = NSView()
        let row = NSStackView(views: [symbolView, label, spacer, control])
        row.alignment = .centerY
        row.spacing = 10
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        row.widthAnchor.constraint(equalToConstant: 512).isActive = true
        return row
    }

    private func makeRow(_ choice: Choice) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 512, height: 58))
        row.wantsLayer = true
        if choice.pinned {
            row.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        }
        let icon = NSImageView(image: choice.icon ?? symbol("macwindow", description: choice.appName) ?? NSImage())
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        let app = NSTextField(labelWithString: choice.appName)
        app.font = .systemFont(ofSize: 12, weight: .semibold)
        app.lineBreakMode = .byTruncatingTail
        app.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let title = NSTextField(labelWithString: choice.windowTitle)
        title.font = .systemFont(ofSize: 11)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingMiddle
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let labels = NSStackView(views: [app, title])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false
        let action = actionButton(choice.pinned ? "取消" : "置顶",
                                  icon: choice.pinned ? "pin.slash" : "pin",
                                  action: #selector(toggle(_:)))
        action.tag = Int(choice.id)
        action.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(icon)
        row.addSubview(labels)
        row.addSubview(action)
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: 512),
            row.heightAnchor.constraint(equalToConstant: 58),
            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 30),
            icon.heightAnchor.constraint(equalToConstant: 30),
            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: action.leadingAnchor, constant: -12),
            action.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            action.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            action.widthAnchor.constraint(equalToConstant: PinTopButton.standardWidth),
            action.heightAnchor.constraint(equalToConstant: PinTopButton.standardHeight)
        ])
        return row
    }

    private func actionButton(_ title: String, icon: String, action: Selector) -> PinTopButton {
        let button = PinTopButton(frame: .zero)
        button.title = title
        button.target = self
        button.action = action
        button.image = PinTopButton.symbol(icon, description: title)
        return button
    }

    @objc private func quit() { onQuit?() }

    private func symbol(_ name: String, description: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: description)
    }

    private func imageView(_ name: String, size: CGFloat, color: NSColor) -> NSImageView {
        let image = symbol(name, description: name)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size, weight: .medium)) ?? NSImage()
        let view = NSImageView(image: image)
        view.contentTintColor = color
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: size + 2).isActive = true
        view.heightAnchor.constraint(equalToConstant: size + 2).isActive = true
        return view
    }

    @objc private func toggle(_ sender: NSButton) { onToggle?(UInt32(sender.tag)) }
    @objc private func startNeedle() { onStartNeedle?() }
    @objc private func unpinAll() { onUnpinAll?() }
    @objc private func refresh() { onRefresh?() }
    @objc private func requestPermission() { onRequestPermission?() }
    @objc private func changeBadge() { onBadgeChange?(badgeSwitch.state == .on) }
    @objc private func changeDock() { onDockChange?(dockSwitch.state == .on) }
    @objc private func changeLogin() { onLoginChange?(loginSwitch.state == .on) }
}
