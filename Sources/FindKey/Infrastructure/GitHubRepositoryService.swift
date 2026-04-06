import Foundation

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

struct GitHubRepositoryService: Sendable {
    private let parser: GitHubURLParser
    private let client: HTTPClient

    init(parser: GitHubURLParser, client: HTTPClient = URLSession.shared) {
        self.parser = parser
        self.client = client
    }

    func enumerateRepositories(from input: String, token: String?) async throws -> [RepositoryRecord] {
        let target = try parser.parse(input)

        switch target {
        case let .organization(name):
            return try await fetchRepositories(path: "orgs/\(name)/repos", token: token)
        case let .user(name):
            return try await fetchRepositories(path: "users/\(name)/repos", token: token)
        case let .owner(name):
            let ownerType = try await resolveOwnerType(name: name, token: token)
            if ownerType == "Organization" {
                return try await fetchRepositories(path: "orgs/\(name)/repos", token: token)
            }

            return try await fetchRepositories(path: "users/\(name)/repos", token: token)
        }
    }

    private func resolveOwnerType(name: String, token: String?) async throws -> String {
        let request = try makeRequest(path: "users/\(name)", token: token)
        let (data, response) = try await client.data(for: request)
        try validate(response: response, data: data)

        let payload = try JSONDecoder().decode(OwnerPayload.self, from: data)
        return payload.type
    }

    private func fetchRepositories(path: String, token: String?) async throws -> [RepositoryRecord] {
        var page = 1
        var repositories: [RepositoryRecord] = []

        while true {
            let request = try makeRequest(path: "\(path)?per_page=100&page=\(page)", token: token)
            let (data, response) = try await client.data(for: request)
            try validate(response: response, data: data)

            let pagePayload = try JSONDecoder().decode([RepositoryPayload].self, from: data)
            repositories.append(contentsOf: pagePayload.map { payload in
                RepositoryRecord(
                    name: payload.name,
                    fullName: payload.fullName,
                    cloneURL: payload.cloneURL,
                    defaultBranch: payload.defaultBranch,
                    isPrivate: payload.private,
                    isArchived: payload.archived,
                    isFork: payload.fork
                )
            })

            if pagePayload.count < 100 {
                break
            }

            page += 1
        }

        return repositories.sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    private func makeRequest(path: String, token: String?) throws -> URLRequest {
        guard let url = URL(string: "https://api.github.com/\(path)") else {
            throw FindKeyError.invalidGitHubURL("Unable to construct GitHub API request.")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FindKey", forHTTPHeaderField: "User-Agent")

        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let response = response as? HTTPURLResponse else {
            throw FindKeyError.network("GitHub returned an invalid response.")
        }

        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw FindKeyError.network(message?.isEmpty == false ? message! : "GitHub API request failed with status \(response.statusCode).")
        }
    }
}

private struct OwnerPayload: Decodable {
    let type: String
}

private struct RepositoryPayload: Decodable {
    let name: String
    let fullName: String
    let cloneURL: URL
    let defaultBranch: String?
    let `private`: Bool
    let archived: Bool
    let fork: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case cloneURL = "clone_url"
        case defaultBranch = "default_branch"
        case `private`
        case archived
        case fork
    }
}
