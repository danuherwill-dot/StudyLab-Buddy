import SwiftUI

// Small shims so the same SwiftUI views run natively on iPhone, iPad and Mac.

extension ToolbarItemPlacement {
    static var leadingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    static var trailingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }
}

extension Color {
    /// The system's base background (UIKit / AppKit).
    static var appBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

extension View {
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func decimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    func dismissKeyboardOnScroll() -> some View {
        #if os(iOS)
        scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }

    /// Sheets get a sensible form-sized window on Mac and iPad.
    func formSheet() -> some View {
        presentationSizing(.form)
    }
}

// MARK: Page look shared by every screen

/// Soft accent gradient behind every page; fills the whole window on Mac.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.appBackground
            LinearGradient(colors: [Color.accentColor.opacity(0.22), Color.purple.opacity(0.10), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func pageBackground() -> some View {
        background(AppBackground())
    }

    /// On Mac, keeps long lists and cards at a comfortable reading width, centred in the window.
    func readableWidth(_ maxWidth: CGFloat = 820) -> some View {
        #if os(macOS)
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
        #else
        self
        #endif
    }
}
