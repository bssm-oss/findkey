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

        print("Self-test succeeded: 7 assertions passed.")
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
