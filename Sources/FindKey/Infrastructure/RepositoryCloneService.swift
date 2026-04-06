import Foundation

struct RepositoryCloneService: Sendable {
    private let commandRunner: CommandRunning

    init(commandRunner: CommandRunning) {
        self.commandRunner = commandRunner
    }

    func clone(repository: RepositoryRecord, token: String?, into workspaceRoot: URL) async throws -> URL {
        let destination = workspaceRoot.appendingPathComponent(safeDirectoryName(for: repository.fullName), isDirectory: true)

        var environment: [String: String] = [:]
        if let token, !token.isEmpty {
            let credential = Data("x-access-token:\(token)".utf8).base64EncodedString()
            environment["GIT_CONFIG_COUNT"] = "1"
            environment["GIT_CONFIG_KEY_0"] = "http.https://github.com/.extraheader"
            environment["GIT_CONFIG_VALUE_0"] = "AUTHORIZATION: basic \(credential)"
        }

        let arguments = ["clone", "--quiet", repository.cloneURL.absoluteString, destination.path]

        _ = try await commandRunner.run(
            executable: "/usr/bin/git",
            arguments: arguments,
            currentDirectory: workspaceRoot,
            environment: environment,
            acceptedExitCodes: [0]
        )

        return destination
    }

    private func safeDirectoryName(for repositoryName: String) -> String {
        repositoryName.replacingOccurrences(of: "/", with: "__")
    }
}
