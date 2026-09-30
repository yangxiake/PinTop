import AppKit

@MainActor final class ControlPanelController: NSObject {
    struct Choice {
        let id: UInt32
        let title: String
        let pinned: Bool
        let icon: NSImage?
    }

    private let window: NSWindow
    private let permissionLabel = NSTextField(labelWithString: "")
    private let windowList = NSStackView()
    private let listScroll = NSScrollView()
    private let badgeToggle = NSButton(checkboxWithTitle: "显示图钉角标", target: nil, action: nil)
    private let dockToggle = NSButton(checkboxWithTitle: "在程序坞显示图标", target: nil, action: nil)
    private let loginToggle = NSButton(checkboxWithTitle: "登录时启动", target: nil, action: nil)
    var onToggle: ((UInt32) -> Void)?
    var onStartNeedle: (() -> Void)?
    var onUnpinAll: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onBadgeChange: ((Bool) -> Void)?
    var onDockChange: ((Bool) -> Void)?
    var onLoginChange: ((Bool) -> Void)?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "PinTop · 窗口图钉"
        window.isReleasedWhenClosed = false
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
        permissionLabel.stringValue = permission ? "辅助功能：已授权" : "辅助功能：待授权"
        badgeToggle.state = badge ? .on : .off
        dockToggle.state = dock ? .on : .off
        loginToggle.state = login ? .on : .off
        for view in windowList.arrangedSubviews {
            windowList.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        if choices.isEmpty {
            let empty = NSTextField(labelWithString: "当前桌面没有可钉住的普通窗口")
            empty.textColor = .secondaryLabelColor
            windowList.addArrangedSubview(empty)
        }
        for choice in choices { windowList.addArrangedSubview(makeRow(choice)) }
        windowList.setFrameSize(NSSize(width: 458,
                                        height: max(230, CGFloat(max(choices.count, 1)) * 38)))
        windowList.needsLayout = true
        window.contentView?.layoutSubtreeIfNeeded()
        let top = windowList.isFlipped ? 0 : max(0, windowList.bounds.height - listScroll.contentView.bounds.height)
        listScroll.contentView.scroll(to: NSPoint(x: 0, y: top))
        listScroll.reflectScrolledClipView(listScroll.contentView)
    }

    private func buildContent() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "把原窗口留在其他普通窗口上方")
        title.font = .boldSystemFont(ofSize: 17)
        root.addArrangedSubview(title)
        let help = NSTextField(labelWithString: "选择下面的窗口，或用菜单栏图钉在桌面上点选。再次选择可取消。")
        help.textColor = .secondaryLabelColor
        root.addArrangedSubview(help)
        root.addArrangedSubview(permissionLabel)
        let actions = NSStackView(views: [button("用图钉选择", #selector(startNeedle)),
                                          button("刷新窗口", #selector(refresh)),
                                          button("检查授权", #selector(requestPermission)),
                                          button("全部取消", #selector(unpinAll))])
        actions.spacing = 10
        root.addArrangedSubview(actions)
        let divider = NSBox()
        divider.boxType = .separator
        root.addArrangedSubview(divider)
        let listTitle = NSTextField(labelWithString: "当前桌面窗口")
        listTitle.font = .boldSystemFont(ofSize: 13)
        root.addArrangedSubview(listTitle)
        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = false
        windowList.orientation = .vertical
        windowList.alignment = .leading
        windowList.spacing = 8
        windowList.frame = NSRect(x: 0, y: 0, width: 458, height: 230)
        listScroll.documentView = windowList
        root.addArrangedSubview(listScroll)
        let settings = NSTextField(labelWithString: "设置")
        settings.font = .boldSystemFont(ofSize: 13)
        root.addArrangedSubview(settings)
        let toggles = NSStackView(views: [badgeToggle, dockToggle, loginToggle])
        toggles.spacing = 12
        root.addArrangedSubview(toggles)
        badgeToggle.target = self
        badgeToggle.action = #selector(changeBadge)
        dockToggle.target = self
        dockToggle.action = #selector(changeDock)
        loginToggle.target = self
        loginToggle.action = #selector(changeLogin)
        let limit = NSTextField(labelWithString: "提示：已钉窗口可能遮挡其他应用的菜单或输入法候选窗。")
        limit.textColor = .secondaryLabelColor
        root.addArrangedSubview(limit)
        guard let content = window.contentView else { return }
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            listScroll.widthAnchor.constraint(equalTo: root.widthAnchor),
            listScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 175),
            divider.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    private func makeRow(_ choice: Choice) -> NSView {
        let icon = NSImageView(image: choice.icon ?? NSImage())
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let label = NSTextField(labelWithString: choice.title)
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let action = button(choice.pinned ? "取消置顶" : "钉住", #selector(toggle(_:)))
        action.tag = Int(choice.id)
        let row = NSStackView(views: [icon, label, action])
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: 458).isActive = true
        return row
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func toggle(_ sender: NSButton) { onToggle?(UInt32(sender.tag)) }
    @objc private func startNeedle() { onStartNeedle?() }
    @objc private func unpinAll() { onUnpinAll?() }
    @objc private func refresh() { onRefresh?() }
    @objc private func requestPermission() { onRequestPermission?() }
    @objc private func changeBadge() { onBadgeChange?(badgeToggle.state == .on) }
    @objc private func changeDock() { onDockChange?(dockToggle.state == .on) }
    @objc private func changeLogin() { onLoginChange?(loginToggle.state == .on) }
}
