import Foundation

public func mimeType(for path: String) -> String {
    switch URL(fileURLWithPath: path).pathExtension.lowercased() {
    case "pdf": "application/pdf"
    case "png": "image/png"
    case "jpg", "jpeg": "image/jpeg"
    case "gif": "image/gif"
    case "txt": "text/plain"
    case "html": "text/html"
    case "zip": "application/zip"
    default: "application/octet-stream"
    }
}
