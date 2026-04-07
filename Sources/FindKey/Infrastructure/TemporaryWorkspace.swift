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

    /// Deletes a specific item within the workspace, logging any errors instead of throwing.
    func cleanup(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            fputs("FindKey warning: failed to remove temporary item at \(url.path): \(error.localizedDescription)\n", stderr)
        }
    }

    /// Removes all leftover findkey-* directories from the system temporary directory.
    static func garbageCollect() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory

        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            let leftovers = contents.filter { $0.lastPathComponent.hasPrefix("findkey-") }

            for url in leftovers {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    fputs("FindKey warning: failed to garbage collect \(url.path): \(error.localizedDescription)\n", stderr)
                }
            }
        } catch {
            fputs("FindKey warning: failed to list temporary directory for garbage collection: \(error.localizedDescription)\n", stderr)
        }
    }
}
