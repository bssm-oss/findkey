import Foundation

protocol CommandRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL?,
        environment: [String: String],
        acceptedExitCodes: Set<Int32>
    ) async throws -> ProcessResult
}

struct ProcessResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

final class ProcessRunner: CommandRunning, @unchecked Sendable {
    func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String] = [:],
        acceptedExitCodes: Set<Int32> = [0]
    ) async throws -> ProcessResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let accumulator = OutputAccumulator()
        let completionGate = CompletionGate()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let finish: @Sendable (Result<ProcessResult, Error>) -> Void = { result in
                    guard completionGate.tryOpen() else { return }
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(with: result)
                }

                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectory
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        handle.readabilityHandler = nil
                        return
                    }

                    accumulator.appendStdout(data)
                }

                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        handle.readabilityHandler = nil
                        return
                    }

                    accumulator.appendStderr(data)
                }

                process.terminationHandler = { process in
                    let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let result = accumulator.makeResult(
                        remainingStdout: remainingStdout,
                        remainingStderr: remainingStderr,
                        exitCode: process.terminationStatus
                    )

                    if acceptedExitCodes.contains(process.terminationStatus) {
                        finish(.success(result))
                    } else {
                        finish(.failure(FindKeyError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)))
                    }
                }

                do {
                    try process.run()
                } catch {
                    finish(.failure(error))
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

private final class OutputAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()

    func appendStdout(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        stdoutData.append(data)
    }

    func appendStderr(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        stderrData.append(data)
    }

    func makeResult(remainingStdout: Data, remainingStderr: Data, exitCode: Int32) -> ProcessResult {
        lock.lock()
        defer { lock.unlock() }
        stdoutData.append(remainingStdout)
        stderrData.append(remainingStderr)

        return ProcessResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            exitCode: exitCode
        )
    }
}

private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasCompleted = false

    func tryOpen() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !hasCompleted else { return false }
        hasCompleted = true
        return true
    }
}
