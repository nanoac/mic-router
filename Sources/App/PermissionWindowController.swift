import Cocoa

/// A draggable tile representing `MicRouter.app` that users can drag directly
/// into macOS System Settings → Privacy & Security → Input Monitoring.
final class DraggableAppIconView: NSView, NSDraggingSource {
    private let appURL = Bundle.main.bundleURL
    private let iconView = NSImageView()
    private let badgeLabel = NSTextField(labelWithString: "")

    var badgeText: String = "" {
        didSet { badgeLabel.stringValue = badgeText }
    }

    private func resolvedAppIcon() -> NSImage {
        if let bundleIcon = NSImage(named: "AppIcon") {
            return bundleIcon
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let icon = resolvedAppIcon()
        icon.size = NSSize(width: 60, height: 60)
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.alignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 96),
            heightAnchor.constraint(equalToConstant: 104),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),

            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            badgeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            badgeLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
        let icon = resolvedAppIcon()
        icon.size = NSSize(width: 60, height: 60)
        let frame = NSRect(x: (bounds.width - 60) / 2, y: (bounds.height - 60) / 2, width: 60, height: 60)
        item.setDraggingFrame(frame, contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

/// A single structured step row: circular number badge + bold title + 1-line description.
final class StepRowView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let descLabel = NSTextField(wrappingLabelWithString: "")

    init(number: Int) {
        super.init(frame: .zero)

        let badge = NSTextField(labelWithString: "\(number)")
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textColor = .white
        badge.alignment = .center
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 11
        badge.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        descLabel.font = .systemFont(ofSize: 11.5)
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [titleLabel, descLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(badge)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            badge.widthAnchor.constraint(equalToConstant: 22),
            badge.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.topAnchor.constraint(equalTo: topAnchor),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }
}

final class PermissionWindowController: NSWindowController {
    var onOpenSettings: (() -> Void)?
    var onRelaunch: (() -> Void)?

    private let headingLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")
    private let dragIcon = DraggableAppIconView()
    private let step1 = StepRowView(number: 1)
    private let step2 = StepRowView(number: 2)
    private let step3 = StepRowView(number: 3)
    private let whyToggleButton = NSButton(title: "", target: nil, action: nil)
    private let whyCardView = NSView()
    private let whyBodyLabel = NSTextField(wrappingLabelWithString: "")
    private let viewSourceButton = NSButton(title: "", target: nil, action: nil)
    private let openSettingsButton = NSButton(title: "", target: nil, action: nil)
    private let relaunchButton = NSButton(title: "", target: nil, action: nil)
    private let spinner = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")

    private var isGranted = false
    private var isWhyExpanded = false

    private let collapsedHeight: CGFloat = 345
    private let expandedHeight: CGFloat = 485

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 476, height: 345),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        setupUI()
        refreshTexts()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func show() {
        refreshTexts()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func markGrantedAndCloseSoon() {
        isGranted = true
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        statusLabel.stringValue = L10n.t(.permGrantedStatus)
        statusLabel.textColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.window?.close()
        }
    }

    func refreshTexts() {
        window?.title = L10n.t(.permWindowTitle)
        headingLabel.stringValue = L10n.t(.permHeading)
        subtitleLabel.stringValue = L10n.t(.permSubtitle)
        dragIcon.badgeText = L10n.t(.permDragBadge)

        step1.titleLabel.stringValue = L10n.t(.permStep1Title)
        step1.descLabel.stringValue = L10n.t(.permStep1Desc)
        step2.titleLabel.stringValue = L10n.t(.permStep2Title)
        step2.descLabel.stringValue = L10n.t(.permStep2Desc)
        step3.titleLabel.stringValue = L10n.t(.permStep3Title)
        step3.descLabel.stringValue = L10n.t(.permStep3Desc)

        whyToggleButton.title = L10n.t(isWhyExpanded ? .permWhyToggleOpen : .permWhyToggleClosed)
        whyBodyLabel.stringValue = L10n.t(.permWhyBody)
        viewSourceButton.title = L10n.t(.permViewSourceLink)

        openSettingsButton.title = L10n.t(.permOpenSettings)
        relaunchButton.title = L10n.t(.permRelaunch)

        if isGranted {
            statusLabel.stringValue = L10n.t(.permGrantedStatus)
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = L10n.t(.permWaitingStatus)
            statusLabel.textColor = .secondaryLabelColor
        }
    }

    // MARK: - UI Layout

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        headingLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headingLabel.textColor = .labelColor

        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2

        let headerStack = NSStackView(views: [headingLabel, subtitleLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 4

        // Main structured card: Left = draggable icon, Right = 3 numbered steps
        let cardView = NSView()
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 12
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor.separatorColor.cgColor
        cardView.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.06).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false

        dragIcon.translatesAutoresizingMaskIntoConstraints = false

        let stepsStack = NSStackView(views: [step1, step2, step3])
        stepsStack.orientation = .vertical
        stepsStack.alignment = .leading
        stepsStack.spacing = 12
        stepsStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(dragIcon)
        cardView.addSubview(stepsStack)

        NSLayoutConstraint.activate([
            dragIcon.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            dragIcon.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            stepsStack.leadingAnchor.constraint(equalTo: dragIcon.trailingAnchor, constant: 18),
            stepsStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            stepsStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            stepsStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),

            step1.widthAnchor.constraint(equalTo: stepsStack.widthAnchor),
            step2.widthAnchor.constraint(equalTo: stepsStack.widthAnchor),
            step3.widthAnchor.constraint(equalTo: stepsStack.widthAnchor),
        ])

        // Progressive-disclosure "Why is Input Monitoring needed?" section
        whyToggleButton.isBordered = false
        whyToggleButton.font = .systemFont(ofSize: 12, weight: .medium)
        whyToggleButton.contentTintColor = .secondaryLabelColor
        whyToggleButton.target = self
        whyToggleButton.action = #selector(toggleWhySection)

        whyCardView.wantsLayer = true
        whyCardView.layer?.cornerRadius = 10
        whyCardView.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.08).cgColor
        whyCardView.translatesAutoresizingMaskIntoConstraints = false
        whyCardView.isHidden = true

        whyBodyLabel.font = .systemFont(ofSize: 11.5)
        whyBodyLabel.textColor = .secondaryLabelColor
        whyBodyLabel.maximumNumberOfLines = 8

        viewSourceButton.isBordered = false
        viewSourceButton.font = .systemFont(ofSize: 11.5, weight: .medium)
        viewSourceButton.contentTintColor = .linkColor
        viewSourceButton.target = self
        viewSourceButton.action = #selector(openSourceCodeClicked)

        let whyStack = NSStackView(views: [whyBodyLabel, viewSourceButton])
        whyStack.orientation = .vertical
        whyStack.alignment = .leading
        whyStack.spacing = 6
        whyStack.translatesAutoresizingMaskIntoConstraints = false

        whyCardView.addSubview(whyStack)
        NSLayoutConstraint.activate([
            whyStack.topAnchor.constraint(equalTo: whyCardView.topAnchor, constant: 10),
            whyStack.bottomAnchor.constraint(equalTo: whyCardView.bottomAnchor, constant: -10),
            whyStack.leadingAnchor.constraint(equalTo: whyCardView.leadingAnchor, constant: 12),
            whyStack.trailingAnchor.constraint(equalTo: whyCardView.trailingAnchor, constant: -12),
            whyBodyLabel.widthAnchor.constraint(equalTo: whyStack.widthAnchor),
        ])

        // Bottom bar: status on left, primary + secondary buttons on right
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        let statusStack = NSStackView(views: [spinner, statusLabel])
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = 6

        relaunchButton.bezelStyle = .rounded
        relaunchButton.target = self
        relaunchButton.action = #selector(relaunchClicked)

        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.keyEquivalent = "\r"
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSettingsClicked)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let footerStack = NSStackView(views: [statusStack, spacer, relaunchButton, openSettingsButton])
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 8

        let rootStack = NSStackView(views: [headerStack, cardView, whyToggleButton, whyCardView, footerStack])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 12
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18),

            headerStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            cardView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            whyCardView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            footerStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func toggleWhySection() {
        isWhyExpanded.toggle()
        whyCardView.isHidden = !isWhyExpanded
        whyToggleButton.title = L10n.t(isWhyExpanded ? .permWhyToggleOpen : .permWhyToggleClosed)

        guard let win = window else { return }
        let targetH = isWhyExpanded ? expandedHeight : collapsedHeight
        var frame = win.frame
        let delta = targetH - frame.size.height
        frame.size.height = targetH
        frame.origin.y -= delta
        win.setFrame(frame, display: true, animate: true)
    }

    @objc private func openSourceCodeClicked() {
        if let url = URL(string: "https://github.com/nanoac/mic-router/blob/main/Sources/Core/RemoteHIDMonitor.swift") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSettingsClicked() {
        onOpenSettings?()
    }

    @objc private func relaunchClicked() {
        onRelaunch?()
    }
}
