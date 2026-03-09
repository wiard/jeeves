import SwiftUI

#if os(macOS)
/// macOS no-op shim for the iOS-only `navigationBarTitleDisplayMode(_:)` modifier.
/// Keeps all existing call sites compiling without `#if os(iOS)` guards.
enum NavigationBarTitleDisplayMode {
    case inline, large, automatic
}

enum TextInputAutocapitalization {
    case never, words, sentences, characters
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        self
    }

    func textInputAutocapitalization(_ mode: TextInputAutocapitalization?) -> some View {
        self
    }
}
#endif
