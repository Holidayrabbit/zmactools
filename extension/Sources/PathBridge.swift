import Foundation

enum PathBridge {
    static func absolutePath(for url: URL) -> String? {
        guard url.isFileURL else {
            return nil
        }

        return url.absoluteString.withCString { fileURL in
            guard let pathPointer = zmt_path_from_file_url(fileURL) else {
                return nil
            }
            defer { zmt_string_free(pathPointer) }
            return String(validatingUTF8: pathPointer)
        }
    }
}

