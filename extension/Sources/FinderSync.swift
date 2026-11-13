import AppKit
import FinderSync
import os

@objc(ZMacToolsFinderSync)
final class ZMacToolsFinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()
    private let copyPathAction = CopyPathAction()
    private let newFileAction = NewFileAction()
    private let logger = Logger(subsystem: "com.zmactools.app.finder", category: "menu")
    private var menuCopyTargets: [URL] = []
    private var menuNewFileDirectory: URL?

    override init() {
        super.init()
        controller.directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let targets = targetURLs(for: menuKind)
        guard !targets.isEmpty else {
            logger.debug("No file targets for menu kind \(menuKind.rawValue, privacy: .public)")
            return nil
        }
        menuCopyTargets = targets
        menuNewFileDirectory = nil

        let rootItem = NSMenuItem(title: "ZMacTools", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "ZMacTools")

        let copyItem = NSMenuItem(
            title: copyPathAction.menuTitle(for: targets),
            action: #selector(copyPath(_:)),
            keyEquivalent: ""
        )
        copyItem.target = self
        submenu.addItem(copyItem)

        if menuKind == .contextualMenuForContainer,
           let directory = controller.targetedURL(),
           directory.isFileURL {
            menuNewFileDirectory = directory
            submenu.addItem(.separator())

            let newFileItem = NSMenuItem(
                title: "新建文件",
                action: #selector(newFile(_:)),
                keyEquivalent: ""
            )
            newFileItem.target = self
            newFileItem.image = NSImage(
                systemSymbolName: "doc.badge.plus",
                accessibilityDescription: nil
            )
            submenu.addItem(newFileItem)
        }

        rootItem.submenu = submenu

        let menu = NSMenu(title: "ZMacTools")
        menu.addItem(rootItem)
        logger.debug("Offering copy action for \(targets.count, privacy: .public) target(s)")
        return menu
    }

    @objc
    private func copyPath(_ sender: NSMenuItem) {
        let urls = menuCopyTargets
        guard !urls.isEmpty else {
            logger.error("Copy action had no targets")
            NSSound.beep()
            return
        }
        copyPathAction.perform(for: urls)
        logger.debug("Copy action completed for \(urls.count, privacy: .public) target(s)")
    }

    @objc
    private func newFile(_ sender: NSMenuItem) {
        guard let directory = menuNewFileDirectory else {
            logger.error("New file action had no container directory")
            NSSound.beep()
            return
        }

        newFileAction.perform(in: directory) { success in
            guard !success else { return }
            DispatchQueue.main.async {
                NSSound.beep()
            }
        }
        logger.debug("Requested new file in \(directory.path, privacy: .public)")
    }

    private func targetURLs(for menuKind: FIMenuKind) -> [URL] {
        switch menuKind {
        case .contextualMenuForItems, .contextualMenuForSidebar:
            let selected = (controller.selectedItemURLs() ?? []).filter(\.isFileURL)
            if !selected.isEmpty {
                return selected
            }
        case .contextualMenuForContainer:
            if let target = controller.targetedURL(), target.isFileURL {
                return [target]
            }
        default:
            break
        }

        if let target = controller.targetedURL(), target.isFileURL {
            return [target]
        }
        return []
    }
}

