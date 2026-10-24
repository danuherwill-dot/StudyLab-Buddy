import SwiftUI

// Liquid Glass buttons on watchOS 26; regular bordered buttons on older watchOS versions.
extension View {
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(watchOS 26, *) { buttonStyle(.glass) } else { buttonStyle(.bordered) }
    }

    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(watchOS 26, *) { buttonStyle(.glassProminent) } else { buttonStyle(.borderedProminent) }
    }
}
