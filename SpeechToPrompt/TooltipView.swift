import SwiftUI
import AppKit

private class PassthroughTooltipView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct TooltipView: NSViewRepresentable {
    let text: String
    @Environment(\.isEnabled) var isEnabled

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughTooltipView()
        view.toolTip = isEnabled ? text : nil
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.toolTip = isEnabled ? text : nil
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        overlay(TooltipView(text: text))
    }
}
