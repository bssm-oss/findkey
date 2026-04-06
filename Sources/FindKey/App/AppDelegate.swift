import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?
    private var editCommandMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        installEditCommandMonitor()

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
        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(self)
        windowController.window?.orderFrontRegardless()
        windowController.window?.makeKeyAndOrderFront(self)

        mainWindowController = windowController
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let editCommandMonitor {
            NSEvent.removeMonitor(editCommandMonitor)
        }
    }

    func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appName = "FindKey"

        let appMenuItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "FindKey")
        appMenu.addItem(withTitle: "\(appName) 정보", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "\(appName) 숨기기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")

        let hideOthersItem = NSMenuItem(title: "나머지 숨기기", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "모두 보기", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem(title: "편집", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")

        let redoItem = NSMenuItem(title: "다시 실행", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "모두 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    private func installEditCommandMonitor() {
        editCommandMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
                  let characters = event.charactersIgnoringModifiers?.lowercased()
            else {
                return event
            }

            let action: Selector? = switch characters {
            case "x": #selector(NSText.cut(_:))
            case "c": #selector(NSText.copy(_:))
            case "v": #selector(NSText.paste(_:))
            case "a": #selector(NSText.selectAll(_:))
            case "z" where event.modifierFlags.contains(.shift): Selector(("redo:"))
            case "z": Selector(("undo:"))
            default: nil
            }

            guard let action, NSApp.sendAction(action, to: nil, from: nil) else {
                return event
            }

            return nil
        }
    }
}
