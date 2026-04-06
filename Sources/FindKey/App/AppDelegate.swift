import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let repositoryService = GitHubRepositoryService(parser: GitHubURLParser())
        let processRunner = ProcessRunner()
        let toolLocator = ExternalToolLocator()
        let cloneService = RepositoryCloneService(commandRunner: processRunner)
        let gitleaksRunner = GitleaksRunner(toolLocator: toolLocator, commandRunner: processRunner)
        let truffleHogRunner = TruffleHogRunner(toolLocator: toolLocator, commandRunner: processRunner)
        let scanOrchestrator = ScanOrchestrator(
            cloneService: cloneService,
            gitleaksRunner: gitleaksRunner,
            truffleHogRunner: truffleHogRunner
        )

        let appController = AppController(
            repositoryService: repositoryService,
            scanOrchestrator: scanOrchestrator
        )

        let windowController = MainWindowController(appController: appController)
        windowController.showWindow(self)
        windowController.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)

        mainWindowController = windowController
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
