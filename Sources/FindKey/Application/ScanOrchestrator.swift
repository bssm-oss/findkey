import Foundation

struct ScanOrchestrator: Sendable {
    private let cloneService: RepositoryCloneService
    private let gitleaksRunner: GitleaksRunner
    private let truffleHogRunner: TruffleHogRunner

    init(
        cloneService: RepositoryCloneService,
        gitleaksRunner: GitleaksRunner,
        truffleHogRunner: TruffleHogRunner
    ) {
        self.cloneService = cloneService
        self.gitleaksRunner = gitleaksRunner
        self.truffleHogRunner = truffleHogRunner
    }

    func scan(
        repositories: [RepositoryRecord],
        token: String?,
        onEvent: @escaping @MainActor (ScanEvent) -> Void
    ) async throws -> ScanResult {
        let workspace = try TemporaryWorkspace.create()
        defer {
            do {
                try workspace.cleanup()
            } catch {
                fputs("FindKey warning: failed to remove temporary workspace at \(workspace.root.path): \(error.localizedDescription)\n", stderr)
            }
        }

        var findings: [ScanFinding] = []
        var rawReports: [RawReport] = []
        var failedRepositories: [String] = []

        for (index, repository) in repositories.enumerated() {
            try Task.checkCancellation()

            let total = repositories.count
            do {
                await onEvent(.progress(message: "Cloning \(repository.fullName)…", completed: index, total: total))
                try Task.checkCancellation()
                let cloneURL = try await cloneService.clone(repository: repository, token: token, into: workspace.clonesDirectory)

                // Defer deletion of the clone for this specific repository
                defer {
                    workspace.cleanup(at: cloneURL)
                }

                await onEvent(.progress(message: "Running Gitleaks on \(repository.fullName)…", completed: index, total: total))
                try Task.checkCancellation()
                let gitleaksResult = try await gitleaksRunner.scan(
                    repository: repository,
                    repositoryPath: cloneURL,
                    reportsDirectory: workspace.reportsDirectory
                )

                await onEvent(.progress(message: "Running TruffleHog on \(repository.fullName)…", completed: index, total: total))
                try Task.checkCancellation()
                let truffleHogResult = try await truffleHogRunner.scan(
                    repository: repository,
                    repositoryPath: cloneURL,
                    reportsDirectory: workspace.reportsDirectory
                )

                let repoFindings = gitleaksResult.findings + truffleHogResult.findings
                let repoReports = [gitleaksResult.rawReport, truffleHogResult.rawReport]
                findings.append(contentsOf: repoFindings)
                rawReports.append(contentsOf: repoReports)

                await onEvent(
                    .repositoryFinished(
                        repository: repository,
                        findings: repoFindings,
                        rawReports: repoReports,
                        completed: index + 1,
                        total: total
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedRepositories.append(repository.fullName)
                await onEvent(
                    .repositoryFailed(
                        repository: repository,
                        message: error.localizedDescription,
                        completed: index + 1,
                        total: total
                    )
                )
            }
        }

        return ScanResult(findings: findings, rawReports: rawReports, failedRepositories: failedRepositories)
    }
}
