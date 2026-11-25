import SwiftUI

extension View {
    /// Reports whether an active fold runs across this view (iPhone Duo half folded with the hinge lying across:
    /// tabletop / laptop). Read from the system's `.division` reserved region, never from the hinge angle or the device
    /// model; always `false` on iPhones without a fold and before iOS 27.1.
    func onHorizontalFoldChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(HorizontalFoldWatcher(action: action))
    }
}

private struct HorizontalFoldWatcher: ViewModifier {
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: Bool.self) { proxy in
                proxy.reservedRegions(kind: .division).contains { $0.isActive && $0.frame.width > $0.frame.height }
            } action: { action($0) }
        } else {
            content
        }
    }
}
