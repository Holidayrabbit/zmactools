import AppKit
import Foundation

struct CopyPathAction {
    func menuTitle(for urls: [URL]) -> String {
        if urls.count > 1 {
            return "复制 \(urls.count) 个项目路径"
        }

        guard let url = urls.first else {
            return "复制绝对路径"
        }
        return isDirectory(url) ? "复制文件夹路径" : "复制文件路径"
    }

    func perform(for urls: [URL]) {
        let paths = urls.compactMap(PathBridge.absolutePath)
        guard !paths.isEmpty else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    private func isDirectory(_ url: URL) -> Bool {
        url.hasDirectoryPath
    }
}

