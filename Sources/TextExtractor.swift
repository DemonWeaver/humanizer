import Foundation
import AppKit
import PDFKit

enum TextExtractor {
    enum ExtractError: LocalizedError {
        case unsupported(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .unsupported(let ext):
                return "Unsupported file type: .\(ext). Use txt, md, docx, rtf, or pdf."
            case .empty:
                return "No text found in the file."
            }
        }
    }

    static let supportedExtensions: Set<String> = ["txt", "md", "markdown", "text", "docx", "doc", "rtf", "pdf"]

    static func extractText(from url: URL) throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        let text: String
        switch ext {
        case "txt", "md", "markdown", "text", "":
            text = try String(contentsOf: url, encoding: .utf8)
        case "docx", "doc":
            let attributed = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.officeOpenXML],
                documentAttributes: nil
            )
            text = attributed.string
        case "rtf":
            let attributed = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            text = attributed.string
        case "pdf":
            guard let doc = PDFDocument(url: url), let content = doc.string else {
                throw ExtractError.empty
            }
            text = content
        default:
            throw ExtractError.unsupported(ext)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExtractError.empty }
        return trimmed
    }
}
