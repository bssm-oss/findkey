import Foundation

struct ExternalToolLocator: Sendable {
    func findExecutable(named name: String) throws -> String {
        let fileManager = FileManager.default
        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let searchPaths = environmentPath
            .split(separator: ":")
            .map(String.init)
            + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]

        for path in Set(searchPaths) {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name).path
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw FindKeyError.toolMissing("\(name) is not installed. Install it with Homebrew before scanning.")
    }
}
