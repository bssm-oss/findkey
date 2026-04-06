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
    private let enumerateButton = NSButton(title: "저장소 조회", target: nil, action: nil)
    private let scanButton = NSButton(title: "스캔 시작", target: nil, action: nil)
    private let repoCountLabel = LabelFactory.body("아직 조회된 저장소가 없습니다.")
    private let sidebarStatusLabel = LabelFactory.body("Gitleaks와 TruffleHog가 로컬에 설치되어 있어야 합니다.")

    private let topStatusLabel = NSTextField(labelWithString: "GitHub 저장소 목록 URL을 입력해 시작하세요.")
    private let countsLabel = NSTextField(labelWithString: "저장소 0개 • 결과 0건")
    private let progressIndicator = NSProgressIndicator()
    private let errorLabel = NSTextField(labelWithString: "")

    private let repositoryTableView = NSTableView()
    private let findingsTableView = NSTableView()
    private let resultsSegmentedControl = NSSegmentedControl(labels: ["결과", "원본 리포트"], trackingMode: .selectOne, target: nil, action: nil)
    private let findingsContainer = NSScrollView()
    private let rawReportContainer = NSScrollView()
    private let rawReportTextView = NSTextView()
    private let rootContentView = ThemedContainerView()
    private(set) var hasBuiltInterface = false

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
        window.isOpaque = true

        rootContentView.fillColor = Theme.background
        rootContentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = rootContentView

        super.init(window: window)
        ensureInterfaceBuilt()
        render(state: appController.state)

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
        ensureInterfaceBuilt()
        render(state: appController.state)
    }

    private func ensureInterfaceBuilt() {
        guard !hasBuiltInterface else { return }
        buildInterface()
    }

    private func buildInterface() {
        hasBuiltInterface = true

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

        rootContentView.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: rootContentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: rootContentView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: rootContentView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: rootContentView.bottomAnchor),
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

        let brandRow = NSStackView()
        brandRow.orientation = .horizontal
        brandRow.alignment = .centerY
        brandRow.spacing = 12

        let logoView = LogoMarkView()
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        logoView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        brandRow.addArrangedSubview(logoView)
        brandRow.addArrangedSubview(title)

        let subtitle = LabelFactory.body("GitHub 조직 또는 사용자 저장소 URL을 입력한 뒤, 각 저장소를 Gitleaks와 TruffleHog로 검사합니다.")

        githubURLField.placeholderString = "https://github.com/orgs/bssm-oss/repositories"
        githubURLField.font = Theme.font(size: 13)
        githubURLField.focusRingType = .none

        tokenField.placeholderString = "ghp_... (선택 사항)"
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
        repoColumn.title = "저장소"
        repoColumn.width = 240
        repositoryTableView.addTableColumn(repoColumn)

        let repoScrollView = NSScrollView()
        repoScrollView.borderType = .noBorder
        repoScrollView.drawsBackground = false
        repoScrollView.documentView = repositoryTableView
        repoScrollView.hasVerticalScroller = true
        repoScrollView.translatesAutoresizingMaskIntoConstraints = false
        repoScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        stack.addArrangedSubview(brandRow)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(LabelFactory.section("대상 URL"))
        stack.addArrangedSubview(githubURLField)
        stack.addArrangedSubview(LabelFactory.section("접근 토큰 (선택 사항)"))
        stack.addArrangedSubview(tokenField)
        stack.addArrangedSubview(enumerateButton)
        stack.addArrangedSubview(scanButton)
        stack.addArrangedSubview(repoCountLabel)
        stack.addArrangedSubview(sidebarStatusLabel)
        stack.addArrangedSubview(LabelFactory.section("조회된 저장소"))
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

        let title = NSTextField(labelWithString: "스캔 결과")
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
            column.title = switch identifier {
            case "repository": "저장소"
            case "tool": "도구"
            case "detector": "탐지기"
            case "path": "경로"
            case "status": "상태"
            default: identifier.capitalized
            }
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
            ? "저장소 \(state.repositories.count)개 • 결과 \(state.findings.count)건"
            : "저장소 \(state.repositories.count)개 • 결과 \(state.findings.count)건 • 실패 \(state.failedRepositories.count)개"
        repoCountLabel.stringValue = state.repositories.isEmpty
            ? "아직 조회된 저장소가 없습니다."
            : "저장소 \(state.repositories.count)개를 불러왔습니다."
        sidebarStatusLabel.stringValue = state.isScanning
            ? "로컬 clone을 Gitleaks와 TruffleHog로 검사하는 중입니다."
            : "Gitleaks와 TruffleHog가 로컬에 설치되어 있어야 합니다."
        rawReportTextView.string = state.rawReportText.isEmpty ? "아직 원본 리포트가 없습니다." : state.rawReportText
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
