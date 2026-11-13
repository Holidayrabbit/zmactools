import AppKit
import Foundation

enum NewFileError: LocalizedError {
    case directoryUnavailable
    case creationFailed

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "目标文件夹不存在或不可访问。"
        case .creationFailed:
            return "无法创建文件，请检查文件夹的写入权限。"
        }
    }
}

struct NewFileService {
    func create(in directoryURL: URL, name: String = "新建文件") throws -> URL {
        var isDirectory: ObjCBool = false
        let directory = directoryURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw NewFileError.directoryUnavailable
        }

        let url = availableURL(for: name, in: directory)
        guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
            throw NewFileError.creationFailed
        }
        return url
    }

    private func availableURL(for name: String, in directory: URL) -> URL {
        let initial = directory.appendingPathComponent(name, isDirectory: false)
        guard FileManager.default.fileExists(atPath: initial.path) else { return initial }

        for index in 2...9999 {
            let candidate = directory.appendingPathComponent(
                "\(name) \(index)",
                isDirectory: false
            )
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return initial
    }
}

@MainActor
final class NewFileController {
    static let shared = NewFileController()

    private let service = NewFileService()

    private init() {}

    func create(in directoryURL: URL) {
        do {
            let url = try service.create(in: directoryURL)
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func presentError(_ message: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "无法新建文件"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
