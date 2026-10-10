import AppKit
import Foundation
import SwiftUI

/// Display policy only; the session deadline and second-by-second engine stay intact.
enum CompactCountdown {
    static func text(remaining: TimeInterval) -> String {
        let remaining = max(remaining, 0)
        if remaining < 60 { return "\(Int(remaining.rounded(.up)))s" }
        let totalMinutes = Int(remaining / 60)
        let hours = totalMinutes / 60
        return hours > 0 ? "\(hours)h\(totalMinutes % 60)m" : "\(totalMinutes)m"
    }

    /// Fixed for the session span, rather than recomputed from remaining time.
    /// An explicit extension can increase this capacity; ordinary ticks cannot.
    static func widthTemplate(duration: TimeInterval) -> String {
        let hours = Int(max(duration, 0) / 3600)
        if hours > 0 { return String(repeating: "8", count: String(hours).count) + "h88m" }
        return "88m"
    }
}

struct CompactCountdownLabel: View {
    let text: String
    let widthTemplate: String

    var body: some View {
        Text(widthTemplate)
            .hidden()
            .overlay(alignment: .trailing) { Text(text) }
            .font(.system(.body, design: .monospaced))
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}

/// MenuBarExtra can extract text/image labels rather than preserving arbitrary
/// Text layout modifiers. Give it one native template Image with an explicit
/// intrinsic size, rendered by SwiftUI, so that sizing reaches the status item.
@MainActor
struct CompactMenuBarLabel: View {
    let text: String?
    let widthTemplate: String?

    var renderedImage: NSImage {
        let renderer = ImageRenderer(content: HStack(spacing: 4) {
            Image(systemName: "eye")
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
            if let text, let widthTemplate {
                CompactCountdownLabel(text: text, widthTemplate: widthTemplate)
            }
        }.foregroundStyle(.black).fixedSize())
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "eye", accessibilityDescription: "Insomnia")!
        image.isTemplate = true
        return image
    }

    var body: some View {
        Image(nsImage: renderedImage)
            .renderingMode(.template)
            .accessibilityLabel(text.map { "Insomnia, \($0) remaining" } ?? "Insomnia")
    }
}
