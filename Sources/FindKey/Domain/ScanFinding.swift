import Foundation

enum ScanTool: String, Codable, Hashable, Sendable {
    case gitleaks = "Gitleaks"
    case truffleHog = "TruffleHog"
}

enum ScanFindingStatus: String, Codable, Hashable, Sendable {
    case detected = "detected"
    case verified = "verified"
    case unverified = "unverified"
    case unknown = "unknown"
}

struct ScanFinding: Hashable, Identifiable, Sendable {
    let id = UUID()
    let repository: String
    let tool: ScanTool
    let detector: String
    let path: String
    let line: Int?
    let status: ScanFindingStatus
    let preview: String
    let rawReportURL: URL

    var pathWithLine: String {
        guard let line else { return path }
        return "\(path):\(line)"
    }
}

struct RawReport: Hashable, Sendable {
    let repository: String
    let tool: ScanTool
    let url: URL
    let contents: String
}

struct ScanResult: Sendable {
    let findings: [ScanFinding]
    let rawReports: [RawReport]
    let failedRepositories: [String]
}

enum ScanEvent: Sendable {
    case progress(message: String, completed: Int, total: Int)
    case repositoryFinished(repository: RepositoryRecord, findings: [ScanFinding], rawReports: [RawReport], completed: Int, total: Int)
    case repositoryFailed(repository: RepositoryRecord, message: String, completed: Int, total: Int)
}
