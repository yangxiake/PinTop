import AppKit

@MainActor final class SettingsPanelController: NSObject {
    private let window: NSWindow
    private let badgeSwitch = NSSwitch()
    private let dockSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()

    var onBadgeChange: ((Bool) -> Void)?
    var onDockChange: ((Bool) -> Void)?
    var onLoginChange: ((Bool) -> Void)?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 260),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()
        buildContent()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(badge: Bool, dock: Bool, login: Bool) {
        badgeSwitch.state = badge ? .on : .off
        dockSwitch.state = dock ? .on : .off
        loginSwitch.state = login ? .on : .off
    }

    private func buildContent() {
        guard let content = window.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            root.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])

        let general = sectionLabel("通用")
        root.addArrangedSubview(general)
        root.setCustomSpacing(15, after: general)
        let windowHeading = sectionLabel("窗口")
        windowHeading.textColor = .secondaryLabelColor
        root.addArrangedSubview(windowHeading)
        root.setCustomSpacing(5, after: windowHeading)
        badgeSwitch.target = self
        badgeSwitch.action = #selector(changeBadge)
        let badgeRow = settingRow("显示窗口角标", control: badgeSwitch)
        root.addArrangedSubview(badgeRow)
        badgeRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let note = NSTextField(wrappingLabelWithString: "角标显示在已置顶窗口上，可直接取消置顶。已置顶窗口可能遮挡其他应用的菜单或输入法候选窗。")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .tertiaryLabelColor
        root.addArrangedSubview(note)
        note.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        root.setCustomSpacing(18, after: note)

        let appHeading = sectionLabel("应用")
        appHeading.textColor = .secondaryLabelColor
        root.addArrangedSubview(appHeading)
        root.setCustomSpacing(5, after: appHeading)
        dockSwitch.target = self
        dockSwitch.action = #selector(changeDock)
        loginSwitch.target = self
        loginSwitch.action = #selector(changeLogin)
        let dockRow = settingRow("在程序坞中显示", control: dockSwitch)
        let loginRow = settingRow("登录时打开", control: loginSwitch)
        root.addArrangedSubview(dockRow)
        root.addArrangedSubview(loginRow)
        dockRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        loginRow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }

    private func sectionLabel(_ value: String) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        return label
    }

    private func settingRow(_ title: String, control: NSSwitch) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        let row = NSStackView(views: [label, NSView(), control])
        row.alignment = .centerY
        row.spacing = 8
        row.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return row
    }

    @objc private func changeBadge() { onBadgeChange?(badgeSwitch.state == .on) }
    @objc private func changeDock() { onDockChange?(dockSwitch.state == .on) }
    @objc private func changeLogin() { onLoginChange?(loginSwitch.state == .on) }
}
