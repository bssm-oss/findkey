import Foundation

@MainActor
final class AppController {
    private let repositoryService: GitHubRepositoryService
    private let scanOrchestrator: ScanOrchestrator
    private var activeTask: Task<Void, Never>?
    private(set) var state = AppViewState()

    var onStateChange: ((AppViewState) -> Void)?

    init(repositoryService: GitHubRepositoryService, scanOrchestrator: ScanOrchestrator) {
        self.repositoryService = repositoryService
        self.scanOrchestrator = scanOrchestrator
    }

    func enumerateRepositories(urlString: String, token: String?) {
        activeTask?.cancel()
        state.repositories = []
        state.findings = []
        state.rawReports = []
        state.rawReportText = ""
        state.failedRepositories = []
        state.isEnumerating = true
        state.isScanning = false
        state.errorMessage = nil
        state.statusMessage = "Resolving repositories…"
        state.progressMode = .indeterminate
        publish()

        activeTask = Task {
            do {
                let repositories = try await repositoryService.enumerateRepositories(from: urlString, token: token)

                guard !Task.isCancelled else { return }

                state.repositories = repositories
                state.findings = []
                state.rawReports = []
                state.rawReportText = ""
                state.failedRepositories = []
                state.isEnumerating = false
                state.progressMode = .idle
                state.statusMessage = repositories.isEmpty
                    ? "No repositories were returned for that GitHub target."
                    : "Resolved \(repositories.count) repositories. Ready to scan."
                publish()
            } catch {
                guard !Task.isCancelled else { return }
                apply(error: error, fallbackMessage: "Failed to resolve repositories.")
            }
        }
    }

    func scanRepositories(token: String?) {
        guard !state.repositories.isEmpty else {
            state.errorMessage = "Resolve repositories before starting a scan."
            publish()
            return
        }

        activeTask?.cancel()
        state.findings = []
        state.rawReports = []
        state.rawReportText = ""
        state.failedRepositories = []
        state.isScanning = true
        state.isEnumerating = false
        state.errorMessage = nil
        state.progress = 0
        state.progressMode = .determinate
        state.statusMessage = "Preparing scan workspace…"
        publish()

        activeTask = Task {
            do {
                let result = try await scanOrchestrator.scan(repositories: state.repositories, token: token) { [weak self] event in
                    self?.apply(event: event)
                }

                guard !Task.isCancelled else { return }

                state.isScanning = false
                state.progress = 1
                state.progressMode = .determinate
                state.findings = result.findings
                state.rawReports = result.rawReports
                state.failedRepositories = result.failedRepositories
                state.rawReportText = Self.renderRawReports(result.rawReports)
                state.statusMessage = Self.finalStatusMessage(
                    findingsCount: result.findings.count,
                    repositoryCount: state.repositories.count,
                    failedRepositoryCount: result.failedRepositories.count
                )
                publish()
            } catch {
                guard !Task.isCancelled else { return }
                apply(error: error, fallbackMessage: "Scan failed.")
            }
        }
    }

    private func apply(event: ScanEvent) {
        switch event {
        case let .progress(message, completed, total):
            state.statusMessage = message
            state.progress = total == 0 ? 0 : Double(completed) / Double(total)
            state.progressMode = .determinate
        case let .repositoryFinished(_, findings, rawReports, completed, total):
            state.findings.append(contentsOf: findings)
            state.rawReports.append(contentsOf: rawReports)
            state.rawReportText = Self.renderRawReports(state.rawReports)
            state.statusMessage = "Scanned \(completed)/\(total) repositories. Findings so far: \(state.findings.count)."
            state.progress = total == 0 ? 0 : Double(completed) / Double(total)
            state.progressMode = .determinate
        case let .repositoryFailed(repository, message, completed, total):
            state.failedRepositories.append(repository.fullName)
            state.errorMessage = message
            state.statusMessage = "Skipped \(repository.fullName). Completed \(completed)/\(total) repositories."
            state.progress = total == 0 ? 0 : Double(completed) / Double(total)
            state.progressMode = .determinate
        }

        publish()
    }

    private func apply(error: Error, fallbackMessage: String) {
        state.isEnumerating = false
        state.isScanning = false
        state.progressMode = .idle
        state.errorMessage = error.localizedDescription
        state.statusMessage = fallbackMessage
        publish()
    }

    private func publish() {
        onStateChange?(state)
    }

    private static func renderRawReports(_ reports: [RawReport]) -> String {
        reports
            .sorted { lhs, rhs in
                if lhs.repository == rhs.repository {
                    return lhs.tool.rawValue < rhs.tool.rawValue
                }

                return lhs.repository < rhs.repository
            }
            .map { report in
                "# \(report.repository) • \(report.tool.rawValue)\n\(report.contents.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            .joined(separator: "\n\n")
    }

    private static func finalStatusMessage(findingsCount: Int, repositoryCount: Int, failedRepositoryCount: Int) -> String {
        let base = findingsCount == 0
            ? "Scan completed. No findings detected."
            : "Scan completed. \(findingsCount) findings detected across \(repositoryCount) repositories."

        guard failedRepositoryCount > 0 else { return base }
        return "\(base) \(failedRepositoryCount) repositories failed and were skipped."
    }
}

struct AppViewState {
    var repositories: [RepositoryRecord] = []
    var findings: [ScanFinding] = []
    var rawReports: [RawReport] = []
    var rawReportText: String = ""
    var failedRepositories: [String] = []
    var statusMessage = "Enter a GitHub repositories URL to begin."
    var errorMessage: String?
    var progress: Double = 0
    var progressMode: ProgressMode = .idle
    var isEnumerating = false
    var isScanning = false
}

enum ProgressMode {
    case idle
    case indeterminate
    case determinate
}
