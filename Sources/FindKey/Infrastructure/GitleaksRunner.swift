import Foundation

struct GitleaksRunner: Sendable {
    private let toolLocator: ExternalToolLocator
    private let commandRunner: CommandRunning
    private let parser = GitleaksReportParser()

    init(toolLocator: ExternalToolLocator, commandRunner: CommandRunning) {
        self.toolLocator = toolLocator
        self.commandRunner = commandRunner
    }

    func scan(repository: RepositoryRecord, repositoryPath: URL, reportsDirectory: URL) async throws -> (findings: [ScanFinding], rawReport: RawReport) {
        let executable = try toolLocator.findExecutable(named: "gitleaks")
        let reportURL = reportsDirectory.appendingPathComponent("\(reportFileStem(for: repository))-gitleaks.json")

        _ = try await commandRunner.run(
            executable: executable,
            arguments: [
                "git",
                "--report-format", "json",
                "--report-path", reportURL.path,
                "--exit-code", "0",
                repositoryPath.path,
            ],
            currentDirectory: repositoryPath,
            environment: [:],
            acceptedExitCodes: [0]
        )

        let data = (try? Data(contentsOf: reportURL)) ?? Data("[]".utf8)
        let findings = try parser.parse(data: data, repository: repository.fullName, rawReportURL: reportURL)
        let rawReport = RawReport(
            repository: repository.fullName,
            tool: .gitleaks,
            url: reportURL,
            contents: String(decoding: data, as: UTF8.self)
        )

        return (findings, rawReport)
    }

    private func reportFileStem(for repository: RepositoryRecord) -> String {
        repository.fullName.replacingOccurrences(of: "/", with: "__")
    }
}

struct GitleaksReportParser: Sendable {
    func parse(data: Data, repository: String, rawReportURL: URL) throws -> [ScanFinding] {
        let findings = try JSONDecoder().decode([GitleaksFindingPayload].self, from: data)
        return findings.map { finding in
            ScanFinding(
                repository: repository,
                tool: .gitleaks,
                detector: finding.ruleID ?? finding.description ?? "gitleaks finding",
                path: finding.file ?? "unknown",
                line: finding.startLine ?? finding.line,
                status: .detected,
                preview: finding.secret ?? finding.match ?? finding.description ?? "Secret detected by Gitleaks.",
                detail: finding.match ?? finding.secret ?? finding.description ?? "Secret detected by Gitleaks.",
                rawReportURL: rawReportURL
            )
        }
    }
}

private struct GitleaksFindingPayload: Decodable {
    let ruleID: String?
    let description: String?
    let file: String?
    let startLine: Int?
    let line: Int?
    let secret: String?
    let match: String?

    enum CodingKeys: String, CodingKey {
        case ruleID = "RuleID"
        case description = "Description"
        case file = "File"
        case startLine = "StartLine"
        case line = "Line"
        case secret = "Secret"
        case match = "Match"
    }
}
