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

        // Perform cleanup of leftover temporary directories from previous runs.
        TemporaryWorkspace.garbageCollect()
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
        state.statusMessage = "저장소 목록을 조회하는 중입니다…"
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
                    ? "입력한 GitHub 대상에서 반환된 저장소가 없습니다."
                    : "저장소 \(repositories.count)개를 확인했습니다. 이제 스캔할 수 있습니다."
                publish()
            } catch {
                guard !Task.isCancelled else { return }
                apply(error: error, fallbackMessage: "저장소 목록 조회에 실패했습니다.")
            }
        }
    }

    func scanRepositories(token: String?) {
        guard !state.repositories.isEmpty else {
            state.errorMessage = "먼저 저장소 목록을 조회해야 스캔을 시작할 수 있습니다."
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
        state.statusMessage = "스캔 작업 공간을 준비하는 중입니다…"
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
                apply(error: error, fallbackMessage: "스캔에 실패했습니다.")
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
            state.statusMessage = "저장소 \(completed)/\(total)개를 검사했습니다. 현재 결과는 \(state.findings.count)건입니다."
            state.progress = total == 0 ? 0 : Double(completed) / Double(total)
            state.progressMode = .determinate
        case let .repositoryFailed(repository, message, completed, total):
            state.failedRepositories.append(repository.fullName)
            state.errorMessage = message
            state.statusMessage = "\(repository.fullName) 검사를 건너뛰었습니다. 현재 \(completed)/\(total)개 저장소를 처리했습니다."
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
            ? "스캔이 완료되었습니다. 탐지된 항목이 없습니다."
            : "스캔이 완료되었습니다. 저장소 \(repositoryCount)개에서 결과 \(findingsCount)건을 확인했습니다."

        guard failedRepositoryCount > 0 else { return base }
        return "\(base) 실패한 저장소 \(failedRepositoryCount)개는 건너뛰었습니다."
    }
}

struct AppViewState {
    var repositories: [RepositoryRecord] = []
    var findings: [ScanFinding] = []
    var rawReports: [RawReport] = []
    var rawReportText: String = ""
    var failedRepositories: [String] = []
    var statusMessage = "GitHub 저장소 목록 URL을 입력해 시작하세요."
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
