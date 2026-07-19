import SwiftUI

struct AttachmentChipsView: View {
    let attachments: [Attachment]
    let onDelete: (UUID) -> Void
    let onTap: (Attachment) -> Void

    var body: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(attachments) { attachment in
                        AttachmentChip(
                            attachment: attachment,
                            label: chipLabel(for: attachment),
                            onDelete: { onDelete(attachment.id) },
                            onTap: { onTap(attachment) }
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .frame(height: 28)
        }
    }

    private func chipLabel(for attachment: Attachment) -> String {
        switch attachment.kind {
        case .image:
            let imageAttachments = attachments.filter { $0.kind == .image }
            let idx = (imageAttachments.firstIndex(where: { $0.id == attachment.id }) ?? 0) + 1
            return "image #\(idx)"
        case .file:
            return attachment.filename
        }
    }
}

struct AttachmentChip: View {
    let attachment: Attachment
    let label: String
    let onDelete: () -> Void
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: attachment.kind == .image ? "photo" : "doc.text")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .foregroundColor(.primary)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(isHovered ? 1.0 : 0.6))
            }
            .buttonStyle(.plain)
            .pointerOnHover()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
    }
}
