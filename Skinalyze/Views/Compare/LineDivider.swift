import SwiftUI

// Moved unchanged from the deleted legacy CompareView.swift; still used by NewCompareView.
// Replaced by the redesigned Compare screen in Phase 3 (PLAN.md §10.6).

struct LineDivider: View {
    @Binding var xOffset: CGFloat
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.white)
                .frame(width: 5, height: UIScreen.main.bounds.height / 2.2)

            Image(systemName: "chevron.left.chevron.right").bold()
                .tint(.red)
                .padding()
                .background(
                    Circle()
                        .foregroundStyle(.white)
                )
        }
        .offset(x: xOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newOffset = xOffset + value.translation.width - dragOffset
                    xOffset = min(max(newOffset, -UIScreen.main.bounds.width / 2 + 12.5), UIScreen.main.bounds.width / 2 - 12.5)
                    dragOffset = value.translation.width
                }
                .onEnded { _ in
                    dragOffset = 0
                }
        )
    }
}

extension View {
    @inlinable
    public func reverseMask<Mask: View>(
        alignment: Alignment = .center,
        @ViewBuilder _ mask: () -> Mask
    ) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}
