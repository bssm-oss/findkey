import Foundation

enum GitHubTarget: Equatable, Sendable {
    case organization(String)
    case user(String)
    case owner(String)

    var name: String {
        switch self {
        case let .organization(name), let .user(name), let .owner(name):
            return name
        }
    }
}
