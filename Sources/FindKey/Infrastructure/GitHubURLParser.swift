import Foundation

struct GitHubURLParser: Sendable {
    func parse(_ rawValue: String) throws -> GitHubTarget {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw FindKeyError.invalidGitHubURL("GitHub URL is empty.")
        }

        guard let components = URLComponents(string: trimmed),
              let host = components.host?.lowercased(),
              ["github.com", "www.github.com"].contains(host)
        else {
            throw FindKeyError.invalidGitHubURL("Use a GitHub organization or user repositories URL.")
        }

        let parts = components.path
            .split(separator: "/")
            .map(String.init)

        if parts.count >= 3, parts[0] == "orgs", parts[2] == "repositories" {
            return .organization(parts[1])
        }

        if parts.count == 1 {
            if components.queryItems?.contains(where: { $0.name == "tab" && $0.value == "repositories" }) == true {
                return .user(parts[0])
            }

            return .owner(parts[0])
        }

        throw FindKeyError.invalidGitHubURL("Supported examples: https://github.com/orgs/<org>/repositories or https://github.com/<user>?tab=repositories")
    }
}
