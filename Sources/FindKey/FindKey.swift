import AppKit
import Foundation

@main
enum FindKey {
    static func main() async {
        if CommandLine.arguments.contains("--self-test") {
            do {
                try await ContractTestRunner().run()
                Foundation.exit(EXIT_SUCCESS)
            } catch {
                fputs("Self-test failed: \(error.localizedDescription)\n", stderr)
                Foundation.exit(EXIT_FAILURE)
            }
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.setActivationPolicy(.regular)
        application.delegate = delegate
        application.run()
    }
}
