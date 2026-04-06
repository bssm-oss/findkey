import AppKit

@MainActor
final class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private enum ResultTab: Int {
        case findings
        case rawReports
    }

    private let appController: AppController

    private let githubURLField = NSTextField(string: "")
    private let tokenField = NSSecureTextField(string: "")
    private let enumerateButton = NSButton(title: "Resolve", target: nil, action: nil)
    private let scanButton = NSButton(title: "Scan", target: nil, action: nil)
    private let repoCountLabel = LabelFactory.body("No repositories loaded.")
    private let sidebarStatusLabel = LabelFactory.body("Gitleaks and TruffleHog must be installed locally.")

    private let topStatusLabel = NSTextField(labelWithString: "Enter a GitHub repositories URL to begin.")
    private let countsLabel = NSTextField(labelWithString: "repos 0 • findings 0")
    private let progressIndicator = NSProgressIndicator()
    private let errorLabel = NSTextField(labelWithString: "")

    private let repositoryTableView = NSTableView()
    private let findingsTableView = NSTableView()
    private let resultsSegmentedControl = NSSegmentedControl(labels: ["Findings", "Raw Report"], trackingMode: .selectOne, target: nil, action: nil)
    private let findingsContainer = NSScrollView()
    private let rawReportContainer = NSScrollView()
    private let rawReportTextView = NSTextView()

    init(appController: AppController) {
        self.appController = appController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1260, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "FindKey"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.background

        super.init(window: window)

        appController.onStateChange = { [weak self] state in
            self?.render(state: state)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        buildInterface()
        render(state: appController.state)
    }

    private func buildInterface() {
        guard let contentView = window?.contentView else { return }

        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.wantsLayer = true

        let sidebar = buildSidebar()
        let mainPane = buildMainPane()

        splitView.addArrangedSubview(sidebar)
        splitView.addArrangedSubview(mainPane)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
        splitView.setPosition(320, ofDividerAt: 0)

        contentView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 320),
        ])
    }

    private func buildSidebar() -> NSView {
        let sidebar = ThemedContainerView()
        sidebar.fillColor = Theme.background
        sidebar.strokeColor = Theme.subtleBorder
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "FindKey")
        title.font = Theme.font(size: 20, weight: .bold)
        title.textColor = Theme.textPrimary

        let subtitle = LabelFactory.body("Resolve a GitHub organization or user URL, then scan each repository with Gitleaks and TruffleHog.")

        githubURLField.placeholderString = "https://github.com/orgs/bssm-oss/repositories"
        githubURLField.font = Theme.font(size: 13)
        githubURLField.focusRingType = .none

        tokenField.placeholderString = "ghp_... (optional)"
        tokenField.font = Theme.font(size: 13)
        tokenField.focusRingType = .none

        configure(button: enumerateButton, primary: false, action: #selector(didTapResolve))
        configure(button: scanButton, primary: true, action: #selector(didTapScan))

        repositoryTableView.headerView = nil
        repositoryTableView.usesAlternatingRowBackgroundColors = false
        repositoryTableView.backgroundColor = Theme.surface
        repositoryTableView.selectionHighlightStyle = .regular
        repositoryTableView.rowHeight = 30
        repositoryTableView.delegate = self
        repositoryTableView.dataSource = self

        let repoColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("repository"))
        repoColumn.title = "Repository"
        repoColumn.width = 240
        repositoryTableView.addTableColumn(repoColumn)

        let repoScrollView = NSScrollView()
        repoScrollView.borderType = .noBorder
        repoScrollView.drawsBackground = false
        repoScrollView.documentView = repositoryTableView
        repoScrollView.hasVerticalScroller = true
        repoScrollView.translatesAutoresizingMaskIntoConstraints = false
        repoScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(LabelFactory.section("Target"))
        stack.addArrangedSubview(githubURLField)
        stack.addArrangedSubview(LabelFactory.section("Access Token (optional)"))
        stack.addArrangedSubview(tokenField)
        stack.addArrangedSubview(enumerateButton)
        stack.addArrangedSubview(scanButton)
        stack.addArrangedSubview(repoCountLabel)
        stack.addArrangedSubview(sidebarStatusLabel)
        stack.addArrangedSubview(LabelFactory.section("Repositories"))
        stack.addArrangedSubview(repoScrollView)

        sidebar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor),
            stack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor),
        ])

        return sidebar
    }

    private func buildMainPane() -> NSView {
        let container = ThemedContainerView()
        container.fillColor = Theme.background
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        topStatusLabel.font = Theme.font(size: 13, weight: .medium)
        topStatusLabel.textColor = Theme.textPrimary

        countsLabel.font = Theme.font(size: 12)
        countsLabel.textColor = Theme.textSecondary

        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.controlTint = .blueControlTint

        errorLabel.font = Theme.font(size: 12)
        errorLabel.textColor = Theme.danger
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.maximumNumberOfLines = 2

        let statusGrid = NSGridView(views: [[topStatusLabel, countsLabel]])
        statusGrid.xPlacement = .fill

        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.spacing = 12
        headerRow.alignment = .centerY

        let title = NSTextField(labelWithString: "Results")
        title.font = Theme.font(size: 16, weight: .bold)
        title.textColor = Theme.textPrimary

        resultsSegmentedControl.selectedSegment = ResultTab.findings.rawValue
        resultsSegmentedControl.target = self
        resultsSegmentedControl.action = #selector(didChangeResultTab)

        headerRow.addArrangedSubview(title)
        headerRow.addArrangedSubview(NSView())
        headerRow.addArrangedSubview(resultsSegmentedControl)

        findingsTableView.headerView = nil
        findingsTableView.backgroundColor = Theme.surface
        findingsTableView.usesAlternatingRowBackgroundColors = false
        findingsTableView.rowHeight = 30
        findingsTableView.delegate = self
        findingsTableView.dataSource = self

        ["repository", "tool", "detector", "path", "status"].forEach { identifier in
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = identifier.capitalized
            column.width = identifier == "detector" ? 250 : 150
            findingsTableView.addTableColumn(column)
        }

        findingsContainer.documentView = findingsTableView
        findingsContainer.hasVerticalScroller = true
        findingsContainer.drawsBackground = false
        findingsContainer.translatesAutoresizingMaskIntoConstraints = false

        rawReportTextView.isEditable = false
        rawReportTextView.font = Theme.font(size: 12)
        rawReportTextView.backgroundColor = Theme.surface
        rawReportTextView.textColor = Theme.textPrimary
        rawReportContainer.documentView = rawReportTextView
        rawReportContainer.hasVerticalScroller = true
        rawReportContainer.drawsBackground = false
        rawReportContainer.translatesAutoresizingMaskIntoConstraints = false
        rawReportContainer.isHidden = true

        let contentStack = NSStackView(views: [findingsContainer, rawReportContainer])
        contentStack.orientation = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(statusGrid)
        stack.addArrangedSubview(progressIndicator)
        stack.addArrangedSubview(errorLabel)
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(contentStack)

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            contentStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 540),
        ])

        return container
    }

    private func configure(button: NSButton, primary: Bool, action: Selector) {
        button.target = self
        button.action = action
        button.font = Theme.font(size: 13, weight: .medium)
        button.bezelStyle = .rounded
        button.contentTintColor = primary ? Theme.textPrimary : Theme.textSecondary
    }

    private func render(state: AppViewState) {
        topStatusLabel.stringValue = state.statusMessage
        countsLabel.stringValue = state.failedRepositories.isEmpty
            ? "repos \(state.repositories.count) • findings \(state.findings.count)"
            : "repos \(state.repositories.count) • findings \(state.findings.count) • failed \(state.failedRepositories.count)"
        repoCountLabel.stringValue = state.repositories.isEmpty
            ? "No repositories loaded."
            : "Loaded \(state.repositories.count) repositories."
        sidebarStatusLabel.stringValue = state.isScanning
            ? "Scanning local clones with Gitleaks and TruffleHog."
            : "Gitleaks and TruffleHog must be installed locally."
        rawReportTextView.string = state.rawReportText.isEmpty ? "No raw reports yet." : state.rawReportText
        errorLabel.stringValue = state.errorMessage ?? ""
        errorLabel.isHidden = state.errorMessage == nil

        enumerateButton.isEnabled = !state.isEnumerating && !state.isScanning
        scanButton.isEnabled = !state.isEnumerating && !state.isScanning && !state.repositories.isEmpty
        githubURLField.isEnabled = !state.isScanning
        tokenField.isEnabled = !state.isScanning

        switch state.progressMode {
        case .idle:
            progressIndicator.stopAnimation(self)
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = 0
        case .indeterminate:
            progressIndicator.isIndeterminate = true
            progressIndicator.startAnimation(self)
        case .determinate:
            progressIndicator.stopAnimation(self)
            progressIndicator.isIndeterminate = false
            progressIndicator.doubleValue = state.progress
        }

        repositoryTableView.reloadData()
        findingsTableView.reloadData()
    }

    @objc
    private func didTapResolve() {
        appController.enumerateRepositories(urlString: githubURLField.stringValue, token: tokenField.stringValue.nilIfEmpty)
    }

    @objc
    private func didTapScan() {
        appController.scanRepositories(token: tokenField.stringValue.nilIfEmpty)
    }

    @objc
    private func didChangeResultTab() {
        let showFindings = resultsSegmentedControl.selectedSegment == ResultTab.findings.rawValue
        findingsContainer.isHidden = !showFindings
        rawReportContainer.isHidden = showFindings
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == repositoryTableView {
            return appController.state.repositories.count
        }

        return appController.state.findings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier.rawValue ?? "cell"
        let value: String

        if tableView == repositoryTableView {
            let repository = appController.state.repositories[row]
            value = repository.fullName
        } else {
            let finding = appController.state.findings[row]
            switch identifier {
            case "repository": value = finding.repository
            case "tool": value = finding.tool.rawValue
            case "detector": value = finding.detector
            case "path": value = finding.pathWithLine
            case "status": value = finding.status.rawValue
            default: value = finding.preview
            }
        }

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: value)
        textField.font = Theme.font(size: 12)
        textField.textColor = Theme.textPrimary
        textField.lineBreakMode = .byTruncatingMiddle
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
