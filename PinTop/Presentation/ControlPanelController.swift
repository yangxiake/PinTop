import AppKit

@MainActor final class ControlPanelController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate {
    struct Choice {
        let id: UInt32
        let appName: String
        let windowTitle: String
        let pinned: Bool
        let icon: NSImage?
    }

    private enum ToolbarID {
        static let add = NSToolbarItem.Identifier("addWindow")
        static let refresh = NSToolbarItem.Identifier("refreshWindows")
        static let more = NSToolbarItem.Identifier("moreActions")
        static let settings = NSToolbarItem.Identifier("settings")
    }

    private let window: NSWindow
    private let table = NSTableView()
    private let scrollView = NSScrollView()
    private let countLabel = NSTextField(labelWithString: "")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "授权…", target: nil, action: nil)
    private let statusIcon = NSImageView()
    private let emptyView = NSStackView()
    private var choices: [Choice] = []
    private var didSetInitialSize = false

    var onToggle: ((UInt32) -> Void)?
    var onStartNeedle: (() -> Void)?
    var onUnpinAll: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onShowSettings: (() -> Void)?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 350),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "PinTop"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 440, height: 260)
        window.center()
        buildContent()
        buildToolbar()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() { window.close() }

    func update(permission: Bool, choices: [Choice]) {
        self.choices = choices
        let pinned = choices.filter(\.pinned).count
        countLabel.stringValue = "\(choices.count) 个窗口 · \(pinned) 个已置顶"
        permissionLabel.stringValue = permission ? "辅助功能权限已开启" : "需要辅助功能权限"
        permissionLabel.textColor = permission ? .secondaryLabelColor : .labelColor
        statusIcon.image = symbol(permission ? "checkmark.circle.fill" : "exclamationmark.triangle",
                                  description: "辅助功能权限")
        statusIcon.contentTintColor = permission ? .systemGreen : .systemOrange
        permissionButton.isHidden = permission
        if !didSetInitialSize {
            let height = max(260, min(430, 125 + 55 * choices.count))
            window.setContentSize(NSSize(width: 520, height: height))
            didSetInitialSize = true
        }
        table.reloadData()
        emptyView.isHidden = !choices.isEmpty
        scrollView.isHidden = choices.isEmpty
    }

    private func buildToolbar() {
        let toolbar = NSToolbar(identifier: "PinTop.MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarID.add, ToolbarID.refresh, .flexibleSpace, ToolbarID.more, ToolbarID.settings]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.target = self
        switch identifier {
        case ToolbarID.add:
            item.label = "添加窗口…"
            item.paletteLabel = item.label
            item.toolTip = "选择一个窗口置顶 (⌘N)"
            let button = NSButton(title: item.label, target: self, action: #selector(startNeedle))
            button.image = symbol("plus", description: item.label)
            button.imagePosition = .imageLeft
            button.bezelStyle = .rounded
            button.controlSize = .regular
            button.bezelColor = .controlAccentColor
            button.contentTintColor = .white
            button.toolTip = item.toolTip
            button.frame = NSRect(x: 0, y: 0, width: 126, height: 28)
            item.view = button
        case ToolbarID.refresh:
            item.label = "刷新"
            item.toolTip = "刷新窗口列表 (⌘R)"
            item.image = symbol("arrow.clockwise", description: item.label)
            item.action = #selector(refresh)
        case ToolbarID.more:
            item.label = "更多"
            item.toolTip = "更多操作"
            item.image = symbol("ellipsis.circle", description: item.label)
            item.action = #selector(showMore(_:))
        case ToolbarID.settings:
            item.label = "设置"
            item.toolTip = "设置 (⌘,)"
            item.image = symbol("gearshape", description: item.label)
            item.action = #selector(showSettings)
        default:
            return nil
        }
        return item
    }

    private func buildContent() {
        guard let content = window.contentView else { return }
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -22),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ])

        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
        statusIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true
        permissionLabel.font = .systemFont(ofSize: 12)
        permissionButton.bezelStyle = .rounded
        permissionButton.controlSize = .small
        permissionButton.target = self
        permissionButton.action = #selector(requestPermission)
        permissionButton.setContentHuggingPriority(.required, for: .horizontal)
        let permissionRow = NSStackView(views: [statusIcon, permissionLabel, permissionButton, NSView()])
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .centerY
        permissionRow.spacing = 7
        permissionRow.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(permissionRow)
        NSLayoutConstraint.activate([
            permissionRow.topAnchor.constraint(equalTo: root.topAnchor),
            permissionRow.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            permissionRow.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            permissionRow.heightAnchor.constraint(equalToConstant: 26)
        ])

        let heading = NSTextField(labelWithString: "窗口")
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        let sectionHeader = NSStackView(views: [heading, NSView(), countLabel])
        sectionHeader.orientation = .horizontal
        sectionHeader.alignment = .centerY
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(sectionHeader)
        NSLayoutConstraint.activate([
            sectionHeader.topAnchor.constraint(equalTo: permissionRow.bottomAnchor, constant: 16),
            sectionHeader.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sectionHeader.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sectionHeader.heightAnchor.constraint(equalToConstant: 18)
        ])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("window"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 55
        table.intercellSpacing = .zero
        table.selectionHighlightStyle = .none
        table.backgroundColor = .clear
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(doubleClickRow)
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .legacy
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: sectionHeader.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])

        let emptyTitle = NSTextField(labelWithString: "尚未添加窗口")
        emptyTitle.font = .systemFont(ofSize: 14, weight: .medium)
        let emptyDetail = NSTextField(labelWithString: "选择一个窗口，让它保持在其他窗口上方。")
        emptyDetail.font = .systemFont(ofSize: 12)
        emptyDetail.textColor = .secondaryLabelColor
        let emptyButton = NSButton(title: "添加窗口…", target: self, action: #selector(startNeedle))
        emptyButton.bezelStyle = .rounded
        emptyButton.keyEquivalent = "\r"
        emptyView.orientation = .vertical
        emptyView.alignment = .centerX
        emptyView.spacing = 8
        [emptyTitle, emptyDetail, emptyButton].forEach(emptyView.addArrangedSubview)
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(emptyView)
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyView.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor),
            emptyView.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor)
        ])
    }

    func numberOfRows(in tableView: NSTableView) -> Int { choices.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let view = HoverRowView()
        view.pinned = choices[row].pinned
        return view
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let choice = choices[row]
        let cell = NSTableCellView()
        let icon = NSImageView(image: choice.icon ?? symbol("macwindow", description: choice.appName) ?? NSImage())
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        let appLabel = NSTextField(labelWithString: choice.appName)
        appLabel.font = .systemFont(ofSize: 12, weight: .medium)
        appLabel.lineBreakMode = .byTruncatingTail
        let titleText = choice.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleLabel = NSTextField(labelWithString: titleText.isEmpty ? "无法读取窗口标题" : titleText)
        titleLabel.font = .systemFont(ofSize: 11)
        titleLabel.textColor = titleText.isEmpty ? .tertiaryLabelColor : .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        let labels = NSStackView(views: [appLabel, titleLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false
        let toggle = NSButton(image: symbol(choice.pinned ? "pin.fill" : "pin", description: "置顶") ?? NSImage(),
                              target: self, action: #selector(toggle(_:)))
        toggle.tag = Int(choice.id)
        toggle.isBordered = false
        toggle.contentTintColor = choice.pinned ? .controlAccentColor : .secondaryLabelColor
        toggle.toolTip = choice.pinned ? "取消置顶" : "置顶"
        toggle.setAccessibilityLabel(toggle.toolTip ?? "置顶")
        toggle.translatesAutoresizingMaskIntoConstraints = false
        [icon, labels, toggle].forEach(cell.addSubview)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            labels.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 11),
            labels.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -10),
            toggle.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            toggle.widthAnchor.constraint(equalToConstant: 28),
            toggle.heightAnchor.constraint(equalToConstant: 28)
        ])
        return cell
    }

    @objc private func toggle(_ sender: NSButton) { onToggle?(UInt32(sender.tag)) }
    @objc private func doubleClickRow() {
        let row = table.clickedRow
        if row >= 0 && row < choices.count { onToggle?(choices[row].id) }
    }
    @objc private func startNeedle() { onStartNeedle?() }
    @objc private func refresh() { onRefresh?() }
    @objc private func requestPermission() { onRequestPermission?() }
    @objc private func showSettings() { onShowSettings?() }
    @objc private func showMore(_ sender: Any?) {
        let menu = NSMenu()
        let all = NSMenuItem(title: "全部取消置顶", action: #selector(unpinAll), keyEquivalent: "")
        all.target = self
        all.isEnabled = choices.contains(where: \.pinned)
        menu.addItem(all)
        let point = window.contentView?.convert(window.mouseLocationOutsideOfEventStream, from: nil) ?? .zero
        menu.popUp(positioning: nil, at: point, in: window.contentView)
    }
    @objc private func unpinAll() { onUnpinAll?() }

    private func symbol(_ name: String, description: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: description)
    }
}

@MainActor private final class HoverRowView: NSTableRowView {
    var pinned = false { didSet { updateBackground() } }
    private var hovered = false { didSet { updateBackground() } }
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        trackingAreaRef = NSTrackingArea(rect: .zero,
                                         options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                         owner: self, userInfo: nil)
        addTrackingArea(trackingAreaRef!)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }
    private func updateBackground() {
        wantsLayer = true
        let color = pinned ? NSColor.controlAccentColor.withAlphaComponent(hovered ? 0.12 : 0.07)
                           : NSColor.labelColor.withAlphaComponent(hovered ? 0.055 : 0)
        layer?.backgroundColor = color.cgColor
    }
}
