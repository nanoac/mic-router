import Cocoa

/// A draggable tile representing `MicRouter.app` that users can drag directly
/// into macOS System Settings → Privacy & Security → Input Monitoring.
final class DraggableAppIconView: NSView, NSDraggingSource {
    private let appURL = Bundle.main.bundleURL
    private let iconView = NSImageView()
    private let captionLabel = NSTextField(labelWithString: "MicRouter.app")

    private func resolvedAppIcon() -> NSImage {
        if let bundleIcon = NSImage(named: "AppIcon") {
            return bundleIcon
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let icon = resolvedAppIcon()
        icon.size = NSSize(width: 56, height: 56)
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.alignment = .center
        captionLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(captionLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 96),
            heightAnchor.constraint(equalToConstant: 96),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),

            captionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            captionLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            captionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
        let icon = resolvedAppIcon()
        icon.size = NSSize(width: 56, height: 56)
        let frame = NSRect(x: (bounds.width - 56) / 2, y: (bounds.height - 56) / 2, width: 56, height: 56)
        item.setDraggingFrame(frame, contents: icon)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

final class PermissionWindowController: NSWindowController {
    var onOpenSettings: (() -> Void)?
    var onRelaunch: (() -> Void)?

    private let headingLabel = NSTextField(wrappingLabelWithString: "")
    private let explanationLabel = NSTextField(wrappingLabelWithString: "")
    private let dragTitleLabel = NSTextField(labelWithString: "")
    private let dragHintLabel = NSTextField(wrappingLabelWithString: "")
    private let openSettingsButton = NSButton(title: "", target: nil, action: nil)
    private let revealButton = NSButton(title: "", target: nil, action: nil)
    private let relaunchButton = NSButton(title: "", target: nil, action: nil)
    private let spinner = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")
    private let privacyLabel = NSTextField(wrappingLabelWithString: "")

    private var isGranted = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 375),
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
        explanationLabel.stringValue = L10n.t(.permExplanation)
        dragTitleLabel.stringValue = L10n.t(.permDragTitle)
        dragHintLabel.stringValue = L10n.t(.permDragHint)
        openSettingsButton.title = L10n.t(.permOpenSettings)
        revealButton.title = L10n.t(.permRevealFinder)
        relaunchButton.title = L10n.t(.permRelaunch)
        privacyLabel.stringValue = L10n.t(.permPrivacyFootnote)

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

        explanationLabel.font = .systemFont(ofSize: 12.5)
        explanationLabel.textColor = .secondaryLabelColor
        explanationLabel.maximumNumberOfLines = 4

        // Drag card container
        let cardView = NSView()
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = 10
        cardView.layer?.borderWidth = 1
        cardView.layer?.borderColor = NSColor.separatorColor.cgColor
        cardView.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.06).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let dragIcon = DraggableAppIconView()
        dragIcon.translatesAutoresizingMaskIntoConstraints = false

        dragTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        dragTitleLabel.textColor = .labelColor

        dragHintLabel.font = .systemFont(ofSize: 12)
        dragHintLabel.textColor = .secondaryLabelColor
        dragHintLabel.maximumNumberOfLines = 7

        let cardTextStack = NSStackView(views: [dragTitleLabel, dragHintLabel])
        cardTextStack.orientation = .vertical
        cardTextStack.alignment = .leading
        cardTextStack.spacing = 6
        cardTextStack.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(dragIcon)
        cardView.addSubview(cardTextStack)

        NSLayoutConstraint.activate([
            dragIcon.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            dragIcon.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            dragIcon.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
            dragIcon.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),

            cardTextStack.leadingAnchor.constraint(equalTo: dragIcon.trailingAnchor, constant: 14),
            cardTextStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            cardTextStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            cardTextStack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
            cardTextStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),
        ])

        // Buttons row
        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.keyEquivalent = "\r"
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSettingsClicked)

        revealButton.bezelStyle = .rounded
        revealButton.target = self
        revealButton.action = #selector(revealFinderClicked)

        relaunchButton.bezelStyle = .rounded
        relaunchButton.target = self
        relaunchButton.action = #selector(relaunchClicked)

        let buttonRow = NSStackView(views: [openSettingsButton, revealButton, relaunchButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        // Live status row
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        let statusRow = NSStackView(views: [spinner, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 6

        // Privacy footnote
        privacyLabel.font = .systemFont(ofSize: 11)
        privacyLabel.textColor = .tertiaryLabelColor
        privacyLabel.maximumNumberOfLines = 2

        let rootStack = NSStackView(views: [
            headingLabel,
            explanationLabel,
            cardView,
            buttonRow,
            statusRow,
            privacyLabel,
        ])
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

            cardView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            explanationLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            privacyLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func openSettingsClicked() {
        onOpenSettings?()
    }

    @objc private func revealFinderClicked() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    @objc private func relaunchClicked() {
        onRelaunch?()
    }
}
