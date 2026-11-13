import AppKit
import os

struct NewFileAction {
    private let logger = Logger(subsystem: "com.zmactools.app.finder", category: "new-file")

    func perform(in directory: URL, completion: @escaping (Bool) -> Void) {
        var components = URLComponents()
        components.scheme = "zmactools"
        components.host = "new-file"
        components.queryItems = [
            URLQueryItem(name: "directory", value: directory.path)
        ]

        guard let url = components.url else {
            logger.error("Unable to build new-file URL")
            completion(false)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(url, configuration: configuration) { app, error in
            if let error {
                self.logger.error(
                    "Unable to open host app: \(error.localizedDescription, privacy: .public)"
                )
                completion(false)
                return
            }
            if app == nil {
                self.logger.error("Host app did not accept new-file request")
            }
            completion(app != nil)
        }
    }
}
