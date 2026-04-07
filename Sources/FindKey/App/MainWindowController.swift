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
    private let statusLineLabel = NSTextField(labelWithString: "GitHub 저장소 목록 URL을 입력해 시작하세요.")
    private let progressIndicator = NSProgressIndicator()
    private let errorLabel = NSTextField(labelWithString: "")

    private let findingsTableView = NSTableView()
    private let resultsSegmentedControl = NSSegmentedControl(labels: ["결과", "원본"], trackingMode: .selectOne, target: nil, action: nil)
    private let findingsContainer = NSScrollView()
    private let rawReportContainer = NSScrollView()
    private let rawReportTextView = NSTextView()
    private let rootContentView = ThemedContainerView()
    private var findingDetailWindowController: NSWindowController?
    private(set) var hasBuiltInterface = false

    init(appController: AppController) {
        self.appController = appController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "FindKey"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.background
        window.isOpaque = true
        window.minSize = NSSize(width: 660, height: 520)

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
        window?.initialFirstResponder = githubURLField
        window?.makeFirstResponder(githubURLField)
    }

    private func buildInterface() {
        hasBuiltInterface = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(buildControlPane())
        stack.addArrangedSubview(buildResultsPane())

        rootContentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: rootContentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: rootContentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: rootContentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: rootContentView.bottomAnchor),
        ])
    }

    private func buildControlPane() -> NSView {
        let container = ThemedContainerView()
        container.fillColor = Theme.surface
        container.strokeColor = Theme.subtleBorder
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        configureInputField(githubURLField, placeholder: "GitHub 저장소 목록 URL")
        configureInputField(tokenField, placeholder: "GitHub 토큰 (선택)")

        configure(button: enumerateButton, primary: false, action: #selector(didTapResolve))
        configure(button: scanButton, primary: true, action: #selector(didTapScan))

        statusLineLabel.font = Theme.font(size: 12, weight: .medium)
        statusLineLabel.textColor = Theme.textPrimary
        statusLineLabel.lineBreakMode = .byTruncatingTail

        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.controlTint = .blueControlTint
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.heightAnchor.constraint(equalToConstant: 10).isActive = true

        errorLabel.font = Theme.font(size: 11)
        errorLabel.textColor = Theme.danger
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.maximumNumberOfLines = 2

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually
        buttonRow.addArrangedSubview(enumerateButton)
        buttonRow.addArrangedSubview(scanButton)

        stack.addArrangedSubview(githubURLField)
        stack.addArrangedSubview(tokenField)
        stack.addArrangedSubview(buttonRow)
        stack.addArrangedSubview(statusLineLabel)
        stack.addArrangedSubview(progressIndicator)
        stack.addArrangedSubview(errorLabel)

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func buildResultsPane() -> NSView {
        let container = ThemedContainerView()
        container.fillColor = Theme.surface
        container.strokeColor = Theme.subtleBorder
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        resultsSegmentedControl.selectedSegment = ResultTab.findings.rawValue
        resultsSegmentedControl.target = self
        resultsSegmentedControl.action = #selector(didChangeResultTab)
        resultsSegmentedControl.segmentStyle = .separated

        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .centerY

        headerRow.addArrangedSubview(NSView())
        headerRow.addArrangedSubview(resultsSegmentedControl)

        findingsTableView.headerView = nil
        findingsTableView.backgroundColor = Theme.surface
        findingsTableView.usesAlternatingRowBackgroundColors = false
        findingsTableView.rowHeight = 24
        findingsTableView.delegate = self
        findingsTableView.dataSource = self
        findingsTableView.target = self
        findingsTableView.doubleAction = #selector(didDoubleClickFindingRow)

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
            column.width = switch identifier {
            case "repository": 150
            case "tool": 70
            case "detector": 150
            case "path": 220
            case "status": 70
            default: 120
            }
            findingsTableView.addTableColumn(column)
        }

        findingsContainer.documentView = findingsTableView
        findingsContainer.hasVerticalScroller = true
        findingsContainer.drawsBackground = false
        findingsContainer.translatesAutoresizingMaskIntoConstraints = false
        findingsContainer.borderType = .noBorder

        rawReportTextView.isEditable = false
        rawReportTextView.isSelectable = true
        rawReportTextView.font = Theme.font(size: 12)
        rawReportTextView.backgroundColor = Theme.surface
        rawReportTextView.textColor = Theme.textPrimary
        rawReportTextView.textContainerInset = NSSize(width: 4, height: 6)
        rawReportContainer.documentView = rawReportTextView
        rawReportContainer.hasVerticalScroller = true
        rawReportContainer.drawsBackground = false
        rawReportContainer.translatesAutoresizingMaskIntoConstraints = false
        rawReportContainer.borderType = .noBorder
        rawReportContainer.isHidden = true

        let contentStack = NSStackView(views: [findingsContainer, rawReportContainer])
        contentStack.orientation = .vertical
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(contentStack)

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            contentStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        return container
    }

    private func configure(button: NSButton, primary: Bool, action: Selector) {
        button.target = self
        button.action = action
        button.font = Theme.font(size: 12, weight: .medium)
        button.bezelStyle = .regularSquare
        button.isBordered = true
        button.wantsLayer = true
        button.contentTintColor = Theme.textPrimary
        button.layer?.cornerRadius = 4
        button.layer?.borderWidth = 1
        button.layer?.borderColor = Theme.subtleBorder.cgColor
        button.layer?.backgroundColor = (primary ? Theme.background : Theme.surface).cgColor
        button.heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    private func configureInputField(_ field: NSTextField, placeholder: String) {
        field.font = Theme.font(size: 12)
        field.textColor = Theme.textPrimary
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = Theme.background
        field.wantsLayer = true
        field.layer?.cornerRadius = 4
        field.layer?.borderWidth = 1
        field.layer?.borderColor = Theme.subtleBorder.cgColor
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 30).isActive = true
        field.placeholderString = placeholder
    }

    private func render(state: AppViewState) {
        statusLineLabel.stringValue = statusText(for: state)
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

        findingsTableView.reloadData()
    }

    private func statusText(for state: AppViewState) -> String {
        let counts = state.failedRepositories.isEmpty
            ? "저장소 \(state.repositories.count) • 결과 \(state.findings.count)"
            : "저장소 \(state.repositories.count) • 결과 \(state.findings.count) • 실패 \(state.failedRepositories.count)"

        return "\(counts) — \(state.statusMessage)"
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

    @objc
    private func didDoubleClickFindingRow() {
        let row = findingsTableView.clickedRow >= 0 ? findingsTableView.clickedRow : findingsTableView.selectedRow
        guard appController.state.findings.indices.contains(row) else { return }

        findingsTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        presentFindingDetailSheet(for: appController.state.findings[row])
    }

    @objc
    private func dismissFindingDetailWindow() {
        findingDetailWindowController?.close()
        findingDetailWindowController = nil
    }

    private func presentFindingDetailSheet(for finding: ScanFinding) {
        if let existingWindow = findingDetailWindowController?.window {
            existingWindow.close()
        }

        let detailWindow = buildFindingDetailWindow(for: finding)
        let controller = NSWindowController(window: detailWindow)
        findingDetailWindowController = controller
        controller.showWindow(self)
        detailWindow.center()
        detailWindow.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildFindingDetailWindow(for finding: ScanFinding) -> NSWindow {
        let detailWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        detailWindow.title = "결과 상세"
        detailWindow.titleVisibility = .visible
        detailWindow.titlebarAppearsTransparent = false
        detailWindow.backgroundColor = Theme.background
        detailWindow.isOpaque = true
        detailWindow.minSize = NSSize(width: 800, height: 600)
        detailWindow.maxSize = NSSize(width: 1200, height: 1000)
        detailWindow.setFrameAutosaveName("FindKeyDetailWindow")

        let contentView = ThemedContainerView()
        contentView.fillColor = Theme.background
        contentView.translatesAutoresizingMaskIntoConstraints = false
        detailWindow.contentView = contentView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = LabelFactory.section("결과 상세")
        let closeButton = NSButton(title: "닫기", target: nil, action: nil)
        configure(button: closeButton, primary: false, action: #selector(dismissFindingDetailWindow))
        closeButton.widthAnchor.constraint(equalToConstant: 72).isActive = true

        let headerRow = NSStackView()
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8
        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(NSView())
        headerRow.addArrangedSubview(closeButton)

        let summaryContainer = ThemedContainerView()
        summaryContainer.fillColor = Theme.surface
        summaryContainer.strokeColor = Theme.subtleBorder
        summaryContainer.translatesAutoresizingMaskIntoConstraints = false

        let summaryStack = NSStackView()
        summaryStack.orientation = .vertical
        summaryStack.alignment = .centerX
        summaryStack.spacing = 8
        summaryStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        summaryStack.translatesAutoresizingMaskIntoConstraints = false

        let detectorLabel = NSTextField(labelWithString: "탐지된 키 유형")
        detectorLabel.font = Theme.font(size: 11, weight: .medium)
        detectorLabel.textColor = Theme.textSecondary
        detectorLabel.alignment = .center

        let detectorValue = NSTextField(labelWithString: finding.detector)
        detectorValue.font = Theme.font(size: 14, weight: .semibold)
        detectorValue.textColor = Theme.textPrimary
        detectorValue.lineBreakMode = .byWordWrapping
        detectorValue.alignment = .center
        detectorValue.maximumNumberOfLines = 2

        let keyLabel = NSTextField(labelWithString: "탐지된 키")
        keyLabel.font = Theme.font(size: 11, weight: .medium)
        keyLabel.textColor = Theme.textSecondary
        keyLabel.alignment = .center

        let keyValue = NSTextField(wrappingLabelWithString: finding.preview)
        keyValue.font = Theme.font(size: 13, weight: .medium)
        keyValue.textColor = Theme.accent
        keyValue.alignment = .center
        keyValue.lineBreakMode = .byCharWrapping
        keyValue.isSelectable = true
        keyValue.maximumNumberOfLines = 0

        let detailPreviewLabel = NSTextField(labelWithString: "탐지된 내용 (미리보기)")
        detailPreviewLabel.font = Theme.font(size: 11, weight: .medium)
        detailPreviewLabel.textColor = Theme.textSecondary
        detailPreviewLabel.alignment = .center

        let detailPreviewValue = NSTextField(wrappingLabelWithString: compactPreview(for: finding.detail))
        detailPreviewValue.font = Theme.font(size: 12)
        detailPreviewValue.textColor = Theme.textPrimary
        detailPreviewValue.alignment = .center
        detailPreviewValue.lineBreakMode = .byWordWrapping
        detailPreviewValue.isSelectable = true
        detailPreviewValue.maximumNumberOfLines = 8

        summaryStack.addArrangedSubview(detectorLabel)
        summaryStack.addArrangedSubview(detectorValue)
        summaryStack.addArrangedSubview(keyLabel)
        summaryStack.addArrangedSubview(keyValue)
        summaryStack.addArrangedSubview(detailPreviewLabel)
        summaryStack.addArrangedSubview(detailPreviewValue)

        summaryStack.setCustomSpacing(4, after: detectorLabel)
        summaryStack.setCustomSpacing(16, after: detectorValue)
        summaryStack.setCustomSpacing(4, after: keyLabel)
        summaryStack.setCustomSpacing(16, after: keyValue)
        summaryStack.setCustomSpacing(4, after: detailPreviewLabel)

        summaryContainer.addSubview(summaryStack)

        NSLayoutConstraint.activate([
            summaryStack.leadingAnchor.constraint(equalTo: summaryContainer.leadingAnchor),
            summaryStack.trailingAnchor.constraint(equalTo: summaryContainer.trailingAnchor),
            summaryStack.topAnchor.constraint(equalTo: summaryContainer.topAnchor),
            summaryStack.bottomAnchor.constraint(equalTo: summaryContainer.bottomAnchor),
        ])

        let metadataContainer = ThemedContainerView()
        metadataContainer.fillColor = Theme.surface
        metadataContainer.strokeColor = Theme.subtleBorder
        metadataContainer.translatesAutoresizingMaskIntoConstraints = false

        let metadataStack = NSStackView()
        metadataStack.orientation = .vertical
        metadataStack.alignment = .width
        metadataStack.spacing = 6
        metadataStack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        metadataStack.translatesAutoresizingMaskIntoConstraints = false

        [
            makeMetadataRow(label: "저장소", value: finding.repository),
            makeMetadataRow(label: "도구", value: finding.tool.rawValue),
            makeMetadataRow(label: "상태", value: finding.status.rawValue),
            makeMetadataRow(label: "경로", value: finding.pathWithLine),
        ].forEach { metadataStack.addArrangedSubview($0) }

        metadataContainer.addSubview(metadataStack)

        NSLayoutConstraint.activate([
            metadataStack.leadingAnchor.constraint(equalTo: metadataContainer.leadingAnchor),
            metadataStack.trailingAnchor.constraint(equalTo: metadataContainer.trailingAnchor),
            metadataStack.topAnchor.constraint(equalTo: metadataContainer.topAnchor),
            metadataStack.bottomAnchor.constraint(equalTo: metadataContainer.bottomAnchor),
        ])

        let detailBlock = makeCombinedDetailBlock(
            finding: finding,
            rawReport: rawReportContents(for: finding)
        )
        detailBlock.setContentHuggingPriority(.defaultLow, for: .vertical)

        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(summaryContainer)
        stack.addArrangedSubview(metadataContainer)
        stack.addArrangedSubview(detailBlock)

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        return detailWindow
    }

    private func rawReportContents(for finding: ScanFinding) -> String {
        if let rawReport = appController.state.rawReports.first(where: { $0.repository == finding.repository && $0.tool == finding.tool }) {
            let contents = rawReport.contents.trimmingCharacters(in: .whitespacesAndNewlines)
            return contents.isEmpty ? "원본 리포트 내용이 없습니다." : contents
        }

        return "연결된 원본 리포트를 찾을 수 없습니다."
    }

    private func makeMetadataRow(label: String, value: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 8

        let labelField = NSTextField(labelWithString: label)
        labelField.font = Theme.font(size: 11, weight: .medium)
        labelField.textColor = Theme.textSecondary
        labelField.setContentHuggingPriority(.required, for: .horizontal)
        labelField.widthAnchor.constraint(equalToConstant: 54).isActive = true

        let valueField = NSTextField(wrappingLabelWithString: value)
        valueField.font = Theme.font(size: 11)
        valueField.textColor = Theme.textPrimary
        valueField.lineBreakMode = .byWordWrapping
        valueField.maximumNumberOfLines = 0

        row.addArrangedSubview(labelField)
        row.addArrangedSubview(valueField)
        return row
    }

    private func makeCombinedDetailBlock(finding: ScanFinding, rawReport: String) -> NSView {
        let container = ThemedContainerView()
        container.fillColor = Theme.surface
        container.strokeColor = Theme.subtleBorder
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "상세 내용")
        titleLabel.font = Theme.font(size: 11, weight: .medium)
        titleLabel.textColor = Theme.textSecondary

        let textView = NSTextView()
        textView.string = combinedDetailText(finding: finding, rawReport: rawReport)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = Theme.font(size: 12)
        textView.textColor = Theme.textPrimary
        textView.backgroundColor = Theme.background
        textView.drawsBackground = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 220)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = textView
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(scrollView)
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func compactPreview(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "표시할 상세 내용이 없습니다." }
        return trimmed
    }

    private func combinedDetailText(finding: ScanFinding, rawReport: String) -> String {
        let key = finding.preview.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = finding.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "표시할 상세 내용이 없습니다."
            : finding.detail.trimmingCharacters(in: .whitespacesAndNewlines)

        let report = rawReport.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "원본 리포트 내용이 없습니다."
            : rawReport.trimmingCharacters(in: .whitespacesAndNewlines)

        return "감지된 키\n\n\(key)\n\n탐지된 내용\n\n\(detail)\n\n원본 리포트\n\n\(report)"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return appController.state.findings.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier.rawValue ?? "cell"
        let finding = appController.state.findings[row]
        let value: String = switch identifier {
        case "repository": finding.repository
        case "tool": finding.tool.rawValue
        case "detector": finding.detector
        case "path": finding.pathWithLine
        case "status": finding.status.rawValue
        default: finding.preview
        }

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: value)
        textField.font = Theme.font(size: 11)
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
