import Foundation

struct TemporaryWorkspace: Sendable {
    let root: URL
    let clonesDirectory: URL
    let reportsDirectory: URL

    static func create() throws -> TemporaryWorkspace {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent("findkey-\(UUID().uuidString)", isDirectory: true)
        let clonesDirectory = root.appendingPathComponent("clones", isDirectory: true)
        let reportsDirectory = root.appendingPathComponent("reports", isDirectory: true)

        try fileManager.createDirectory(at: clonesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)

        return TemporaryWorkspace(root: root, clonesDirectory: clonesDirectory, reportsDirectory: reportsDirectory)
    }

    func cleanup() throws {
        try FileManager.default.removeItem(at: root)
    }
}
