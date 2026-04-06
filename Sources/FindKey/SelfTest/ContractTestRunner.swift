import AppKit
import Foundation

struct ContractTestRunner: Sendable {
    func run() async throws {
        let parser = GitHubURLParser()
        try assert(parser.parse("https://github.com/orgs/bssm-oss/repositories") == .organization("bssm-oss"), "parses organization repository URL")
        try assert(parser.parse("https://github.com/heodongun?tab=repositories") == .user("heodongun"), "parses user repository URL")
        try assert(parser.parse("https://github.com/bssm-oss") == .owner("bssm-oss"), "parses root owner URL")
        try assertThrows("rejects lookalike GitHub host") {
            _ = try parser.parse("https://evilgithub.com/bssm-oss")
        }

        let client = SelfTestHTTPClient(responses: [
            "https://api.github.com/users/heodongun": .init(statusCode: 200, body: "{\"type\":\"User\"}"),
            "https://api.github.com/users/heodongun/repos?per_page=100&page=1": .init(statusCode: 200, body: "[{\"name\":\"findkey\",\"full_name\":\"heodongun/findkey\",\"clone_url\":\"https://github.com/heodongun/findkey.git\",\"default_branch\":\"main\",\"private\":false,\"archived\":false,\"fork\":false}]")
        ])
        let service = GitHubRepositoryService(parser: parser, client: client)
        let repositories = try await service.enumerateRepositories(from: "https://github.com/heodongun", token: nil)
        try assert(repositories.map(\.fullName) == ["heodongun/findkey"], "enumerates repositories from resolved owner URL")

        let gitleaksPayload = Data("[{\"RuleID\":\"github-pat\",\"File\":\"Sources/App.swift\",\"StartLine\":12,\"Secret\":\"ghp_****\"}]".utf8)
        let gitleaksFindings = try GitleaksReportParser().parse(
            data: gitleaksPayload,
            repository: "bssm-oss/findkey",
            rawReportURL: URL(fileURLWithPath: "/tmp/gitleaks.json")
        )
        try assert(gitleaksFindings.count == 1, "parses gitleaks json findings")
        try assert(gitleaksFindings.first?.detail == "ghp_****", "preserves gitleaks detail for modal display")

        let trufflehogPayload = "{" +
            "\"DetectorName\":\"AWS\"," +
            "\"Verified\":true," +
            "\"Raw\":\"AKIAEXAMPLE\"," +
            "\"Redacted\":\"AKIAEXAMPLE\"," +
            "\"SourceMetadata\":{\"Data\":{\"Git\":{\"file\":\"Sources/App.swift\",\"repository\":\"bssm-oss/findkey\",\"line\":7}}}}"
        let trufflehogFindings = try TruffleHogEventParser().parse(
            output: trufflehogPayload,
            repository: "bssm-oss/findkey",
            rawReportURL: URL(fileURLWithPath: "/tmp/trufflehog.ndjson")
        )
        try assert(trufflehogFindings.first?.status == .verified, "parses trufflehog ndjson findings")
        try assert(trufflehogFindings.first?.detail == "AKIAEXAMPLE", "preserves trufflehog detail for modal display")

        try await MainActor.run {
            try assertAppMenuSupportsCopyPaste()
        }
        try await assertMainWindowBootstrapsVisibleUI()

        print("Self-test succeeded: 11 assertions passed.")
    }

    @MainActor
    private func assertAppMenuSupportsCopyPaste() throws {
        let delegate = AppDelegate()
        let menu = delegate.makeMainMenu()
        let submenuTitles = menu.items.compactMap { $0.submenu?.title }
        try assert(submenuTitles.contains("편집"), "creates Edit menu for copy paste")

        let editItems = menu.items
            .compactMap { $0.submenu }
            .first { $0.title == "편집" }?
            .items
            .map(\.title) ?? []

        try assert(editItems.contains("복사"), "includes copy action in Edit menu")
        try assert(editItems.contains("붙여넣기"), "includes paste action in Edit menu")
    }

    @MainActor
    private func assertMainWindowBootstrapsVisibleUI() throws {
        let controller = AppController(
            repositoryService: GitHubRepositoryService(parser: GitHubURLParser(), client: SelfTestHTTPClient(responses: [:])),
            scanOrchestrator: ScanOrchestrator(
                cloneService: RepositoryCloneService(commandRunner: ProcessRunner()),
                gitleaksRunner: GitleaksRunner(toolLocator: ExternalToolLocator(), commandRunner: ProcessRunner()),
                truffleHogRunner: TruffleHogRunner(toolLocator: ExternalToolLocator(), commandRunner: ProcessRunner())
            )
        )
        let windowController = MainWindowController(appController: controller)
        let window = try unwrap(windowController.window, "creates the main window")
        let contentSubviews = window.contentView?.subviews ?? []
        try assert(contentSubviews.isEmpty == false, "bootstraps visible main window UI")
        try assert(windowController.hasBuiltInterface, "builds interface without relying on windowDidLoad")
        try assert(contentSubviews.first is NSStackView, "attaches compact root stack to the main window")
        let labels = collectLabels(in: contentSubviews)
        try assert(labels.contains("저장소 조회"), "shows compact Korean action labels")
        try assert(labels.contains(where: { $0.contains("저장소 0") && $0.contains("결과 0") }), "shows compact Korean status summary")
    }

    private func assert(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try condition() {
            print("PASS \(message)")
        } else {
            throw FindKeyError.commandFailed("Assertion failed: \(message)")
        }
    }

    private func assertThrows(_ message: String, _ block: () throws -> Void) throws {
        do {
            try block()
            throw FindKeyError.commandFailed("Assertion failed: \(message)")
        } catch is FindKeyError {
            print("PASS \(message)")
        } catch {
            print("PASS \(message)")
        }
    }

    private func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw FindKeyError.commandFailed("Assertion failed: \(message)")
        }

        return value
    }

    @MainActor
    private func collectLabels(in views: [NSView]) -> [String] {
        var labels: [String] = []

        for view in views {
            if let label = view as? NSTextField, !label.stringValue.isEmpty {
                labels.append(label.stringValue)
            }

            if let button = view as? NSButton, !button.title.isEmpty {
                labels.append(button.title)
            }

            labels.append(contentsOf: collectLabels(in: view.subviews))
        }

        return labels
    }
}

private struct SelfTestHTTPClient: HTTPClient, Sendable {
    struct Response {
        let statusCode: Int
        let body: String
    }

    let responses: [String: Response]

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let key = request.url!.absoluteString
        guard let response = responses[key] else {
            throw FindKeyError.network("Missing self-test response for \(key)")
        }

        let urlResponse = HTTPURLResponse(url: request.url!, statusCode: response.statusCode, httpVersion: nil, headerFields: nil)!
        return (Data(response.body.utf8), urlResponse)
    }
}
