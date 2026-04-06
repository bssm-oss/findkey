import Foundation

enum FindKeyError: LocalizedError {
    case invalidGitHubURL(String)
    case network(String)
    case toolMissing(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidGitHubURL(message),
             let .network(message),
             let .toolMissing(message),
             let .commandFailed(message):
            return message
        }
    }
}
