import SwiftUI
import AppKit

struct PastedItem {
    let data: Data
    let filename: String
    let kind: AttachmentKind
}

struct PasteContext {
    let items: [PastedItem]
    let cursorPosition: Int
}

struct PastableTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool = true
    var onPasteAttachments: ((PasteContext) -> Void)?
    var onPasteTextFile: ((PastedItem, Int, @escaping (Bool) -> Void) -> Void)?

    static let supportedTextExtensions: Set<String> = [
        "json", "md", "yml", "yaml", "xml", "txt",
        "swift", "py", "js", "ts", "tsx", "jsx",
        "rs", "go", "java", "kt", "c", "cpp", "h",
        "rb", "sh", "toml", "csv", "html", "css", "scss"
    ]

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "svg", "tiff", "bmp", "heic"
    ]

    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    private static let referencePattern = try! NSRegularExpression(pattern: #"!\[[^\]]*\]\(attachments/[^)]+\)"#)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = PasteInterceptingTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        textView.font = Self.monoFont

        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator

        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        textView.string = text
        Self.applyReferenceHighlighting(to: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PasteInterceptingTextView else { return }
        context.coordinator.parent = self
        textView.isEditable = isEditable
        if context.coordinator.isUpdating { return }
        if textView.string != text {
            context.coordinator.isUpdating = true
            let selectedRange = textView.selectedRange()
            textView.string = text
            let clampedRange = NSRange(
                location: min(selectedRange.location, textView.string.count),
                length: 0
            )
            textView.setSelectedRange(clampedRange)
            Self.applyReferenceHighlighting(to: textView)
            context.coordinator.isUpdating = false
        }
    }

    static func applyReferenceHighlighting(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.addAttribute(.font, value: monoFont, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        let matches = referencePattern.matches(in: textStorage.string, range: fullRange)
        for match in matches {
            textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PastableTextView
        var isUpdating = false
        weak var textView: PasteInterceptingTextView?

        init(_ parent: PastableTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if isUpdating { return }
            isUpdating = true
            parent.text = textView.string
            PastableTextView.applyReferenceHighlighting(to: textView)
            isUpdating = false
        }

        func handlePasteAttachments(_ context: PasteContext) {
            parent.onPasteAttachments?(context)
        }

        func handlePasteTextFile(_ item: PastedItem, cursorPosition: Int, decision: @escaping (Bool) -> Void) {
            parent.onPasteTextFile?(item, cursorPosition, decision)
        }
    }
}

class PasteInterceptingTextView: NSTextView {
    weak var coordinator: PastableTextView.Coordinator?

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        var types = super.readablePasteboardTypes
        types.append(contentsOf: [.png, .tiff, .fileURL])
        return types
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        let cursor = selectedRange().location

        if let fileItems = extractFileURLItems(from: pb), !fileItems.isEmpty {
            let imageItems = fileItems.filter { $0.kind == .image }
            let textFileItems = fileItems.filter { $0.kind == .file }

            if !imageItems.isEmpty {
                coordinator?.handlePasteAttachments(PasteContext(items: imageItems, cursorPosition: cursor))
            }

            for item in textFileItems {
                coordinator?.handlePasteTextFile(item, cursorPosition: cursor) { [weak self] shouldAttach in
                    if shouldAttach {
                        self?.coordinator?.handlePasteAttachments(PasteContext(items: [item], cursorPosition: cursor))
                    } else {
                        if let content = String(data: item.data, encoding: .utf8) {
                            self?.insertText(content, replacementRange: self?.selectedRange() ?? NSRange(location: cursor, length: 0))
                        }
                    }
                }
            }
            return
        }

        if let imageItem = extractRawImageData(from: pb) {
            coordinator?.handlePasteAttachments(PasteContext(items: [imageItem], cursorPosition: cursor))
            return
        }

        super.paste(sender)
    }

    private func extractFileURLItems(from pb: NSPasteboard) -> [PastedItem]? {
        guard let items = pb.pasteboardItems else { return nil }
        var result: [PastedItem] = []

        for item in items {
            guard let urlString = item.string(forType: .fileURL),
                  let url = URL(string: urlString) else { continue }

            let ext = url.pathExtension.lowercased()
            guard !ext.isEmpty else { continue }

            guard let data = try? Data(contentsOf: url) else { continue }
            let filename = url.lastPathComponent

            if PastableTextView.imageExtensions.contains(ext) {
                result.append(PastedItem(data: data, filename: filename, kind: .image))
            } else if PastableTextView.supportedTextExtensions.contains(ext) {
                result.append(PastedItem(data: data, filename: filename, kind: .file))
            }
        }
        return result.isEmpty ? nil : result
    }

    private func extractRawImageData(from pb: NSPasteboard) -> PastedItem? {
        guard let image = NSImage(pasteboard: pb) else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return PastedItem(data: pngData, filename: "pasted.png", kind: .image)
    }
}
