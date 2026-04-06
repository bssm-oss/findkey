import Foundation

struct RepositoryRecord: Codable, Hashable, Identifiable, Sendable {
    let name: String
    let fullName: String
    let cloneURL: URL
    let defaultBranch: String?
    let isPrivate: Bool
    let isArchived: Bool
    let isFork: Bool

    var id: String { fullName }
}
