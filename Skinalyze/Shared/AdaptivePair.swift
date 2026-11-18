import SwiftUI
import SkinalyzeKit

/// Two related regions laid out for every iPhone shape (CLAUDE.md §1).
///
/// iOS 27.1+: `ArrangementView` — splits side-by-side when wide, stacks when tall, and keeps content out of the
/// iPhone Duo fold in book and tabletop poses (`.split`), or layers secondary over primary (`.overlay`).
/// iOS 26: falls back to a size-class driven stack.
struct AdaptivePair<Primary: View, Secondary: View>: View {
    enum Style {
        /// Main/detail: two peers side by side or stacked.
        case split
        /// Foreground/background: secondary floats over primary.
        case overlay
    }

    let style: Style
    let primary: Primary
    let secondary: Secondary

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(_ style: Style = .split, @ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.style = style
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        if #available(iOS 27.1, *) {
            arranged
        } else {
            fallback
        }
    }

    @available(iOS 27.1, *)
    @ViewBuilder private var arranged: some View {
        switch style {
        case .split:
            ArrangementView { primary } secondary: { secondary }
                .arrangementViewStyle(.split)
        case .overlay:
            ArrangementView { primary } secondary: { secondary }
                .arrangementViewStyle(.overlay)
        }
    }

    @ViewBuilder private var fallback: some View {
        switch style {
        case .split:
            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    primary.frame(maxWidth: .infinity)
                    secondary.frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: Spacing.lg) {
                    primary
                    secondary
                }
            }
        case .overlay:
            ZStack(alignment: .bottom) {
                primary
                secondary
            }
        }
    }
}

/// Scrolling two-pane screen. `ArrangementView` must not live inside a scroll view, so on regular widths each pane
/// gets its own scroll view inside the arrangement (iPhone Duo open: one pane per side of the fold); on compact
/// widths the panes stack in a single scroll view.
struct AdaptivePanes<Primary: View, Secondary: View>: View {
    let primary: Primary
    let secondary: Secondary
    var maxWidth: CGFloat = 1100

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(maxWidth: CGFloat = 1100, @ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.maxWidth = maxWidth
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            AdaptivePair(.split) {
                ScrollView { primary.padding(Spacing.md) }
            } secondary: {
                ScrollView { secondary.padding(Spacing.md) }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    primary
                    secondary
                }
                .padding(Spacing.md)
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// 0 = closed, 1 = fully open. For hinge-driven *effects only* — never layout (CLAUDE.md §1 rule 5).
@Observable
@MainActor
final class HingeProgress {
    var value: Double = 1
    var isPartiallyOpen = false
    private var maxSeen: Double = .pi

    @available(iOS 27.1, *)
    func update(_ hinge: DeviceHinge?) {
        guard let hinge else {
            value = 1
            isPartiallyOpen = false
            return
        }
        let radians = hinge.angle.radians
        switch hinge.status {
        case .closed:
            value = 0
            isPartiallyOpen = false
        case .fullyOpen:
            maxSeen = max(maxSeen, radians)
            value = 1
            isPartiallyOpen = false
        default:
            value = min(max(radians / maxSeen, 0), 1)
            isPartiallyOpen = true
        }
    }
}
