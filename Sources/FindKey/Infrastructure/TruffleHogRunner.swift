import Foundation

struct TruffleHogRunner: Sendable {
    private let toolLocator: ExternalToolLocator
    private let commandRunner: CommandRunning
    private let parser = TruffleHogEventParser()

    init(toolLocator: ExternalToolLocator, commandRunner: CommandRunning) {
        self.toolLocator = toolLocator
        self.commandRunner = commandRunner
    }

    func scan(repository: RepositoryRecord, repositoryPath: URL, reportsDirectory: URL) async throws -> (findings: [ScanFinding], rawReport: RawReport) {
        let executable = try toolLocator.findExecutable(named: "trufflehog")
        let reportURL = reportsDirectory.appendingPathComponent("\(reportFileStem(for: repository))-trufflehog.ndjson")

        let result = try await commandRunner.run(
            executable: executable,
            arguments: [
                "git",
                "file://\(repositoryPath.path)",
                "--json",
                "--no-verification",
                "--no-update",
                "--results=verified,unverified,unknown",
            ],
            currentDirectory: repositoryPath,
            environment: [:],
            acceptedExitCodes: [0]
        )

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        try output.write(to: reportURL, atomically: true, encoding: .utf8)

        let findings = try parser.parse(output: output, repository: repository.fullName, rawReportURL: reportURL)
        let rawReport = RawReport(
            repository: repository.fullName,
            tool: .truffleHog,
            url: reportURL,
            contents: output
        )

        return (findings, rawReport)
    }

    private func reportFileStem(for repository: RepositoryRecord) -> String {
        repository.fullName.replacingOccurrences(of: "/", with: "__")
    }
}

struct TruffleHogEventParser: Sendable {
    func parse(output: String, repository: String, rawReportURL: URL) throws -> [ScanFinding] {
        guard !output.isEmpty else { return [] }

        let decoder = JSONDecoder()
        return try output
            .split(whereSeparator: \ .isNewline)
            .compactMap { line in
                guard line.first == "{" else { return nil }
                let event = try decoder.decode(TruffleHogFindingPayload.self, from: Data(line.utf8))
                let path = event.sourceMetadata?.data?.git?.file ?? "unknown"
                let repositoryName = event.sourceMetadata?.data?.git?.repository ?? repository
                let preview = event.raw ?? event.redacted ?? "Credential candidate detected by TruffleHog."
                let status: ScanFindingStatus = if event.verified == true {
                    .verified
                } else if event.verified == false {
                    .unverified
                } else {
                    .unknown
                }

                return ScanFinding(
                    repository: repositoryName,
                    tool: .truffleHog,
                    detector: event.detectorName ?? "TruffleHog detector",
                    path: path,
                    line: event.sourceMetadata?.data?.git?.line,
                    status: status,
                    preview: preview,
                    detail: event.raw ?? event.redacted ?? "Credential candidate detected by TruffleHog.",
                    rawReportURL: rawReportURL
                )
            }
    }
}

private struct TruffleHogFindingPayload: Decodable {
    let detectorName: String?
    let verified: Bool?
    let raw: String?
    let redacted: String?
    let sourceMetadata: SourceMetadata?

    enum CodingKeys: String, CodingKey {
        case detectorName = "DetectorName"
        case verified = "Verified"
        case raw = "Raw"
        case redacted = "Redacted"
        case sourceMetadata = "SourceMetadata"
    }

    struct SourceMetadata: Decodable {
        let data: DataPayload?

        enum CodingKeys: String, CodingKey {
            case data = "Data"
        }
    }

    struct DataPayload: Decodable {
        let git: GitPayload?

        enum CodingKeys: String, CodingKey {
            case git = "Git"
        }
    }

    struct GitPayload: Decodable {
        let file: String?
        let repository: String?
        let line: Int?
    }
}
