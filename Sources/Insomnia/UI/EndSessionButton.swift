import SwiftUI

struct EndSessionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 17))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("End session")
        .accessibilityLabel("End session")
    }
}
