import SwiftData
import SwiftUI
import SkinalyzeKit

/// V2 shell: no tab bar. Mirror is home; a floating Liquid Glass dock moves between Mirror · Deck · Shelf.
struct AppShell: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var capture = ScanCaptureModel()
    @State private var isKeyboardVisible = false

    var body: some View {
        @Bindable var appModel = appModel
        ZStack(alignment: .bottom) {
            page
                .id(appModel.selectedTab == .search ? AppModel.Tab.products : appModel.selectedTab)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
            if !appModel.isScanning, !isKeyboardVisible {
                MirrorDock(selection: $appModel.selectedTab)
                    .padding(.bottom, Spacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: appModel.selectedTab)
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: appModel.isScanning)
        .onChange(of: appModel.selectedTab) { _, tab in capture.setMirrorVisible(tab == .today) }
        // The dock steps aside while typing so it never covers search results.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .animation(MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation, value: isKeyboardVisible)
        .sheet(item: $appModel.presentedScan) { presented in
            NavigationStack {
                if let session = modelContext.model(for: presented.id) as? ScanSession {
                    ScanResultView(session: session, isFreshScan: true)
                }
            }
        }
        .sheet(isPresented: $appModel.isShowingProfile) { ProfileView() }
        .onOpenURL { appModel.open($0) }
        #if DEBUG
        .onAppear {
            if let tab = UserDefaults.standard.string(forKey: "startTab"), let url = URL(string: "skinalyze://\(tab)") {
                appModel.open(url)
            }
        }
        #endif
    }

    @ViewBuilder private var page: some View {
        switch appModel.selectedTab {
        case .today: MirrorView(model: capture)
        case .timeline: DeckView().accessibilityIdentifier("deckView")
        case .products, .search: ShelfView().accessibilityIdentifier("shelfView")
        }
    }
}

/// Three glyphs in one glass capsule; the selection is a white pill that slides between them.
struct MirrorDock: View {
    @Binding var selection: AppModel.Tab
    @Namespace private var pill

    private struct Item: Identifiable {
        let tab: AppModel.Tab
        let title: LocalizedStringKey
        let symbol: String
        let identifier: String
        var id: String { identifier }
    }

    private let items = [
        Item(tab: .today, title: "Mirror", symbol: "faceid", identifier: "dock.mirror"),
        Item(tab: .timeline, title: "Deck", symbol: "rectangle.stack.fill", identifier: "dock.deck"),
        Item(tab: .products, title: "Shelf", symbol: "drop.fill", identifier: "dock.shelf"),
    ]

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(items) { item in
                button(item)
            }
        }
        .padding(Spacing.xxs + 2)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func isSelected(_ item: Item) -> Bool {
        selection == item.tab || (item.tab == .products && selection == .search)
    }

    private func button(_ item: Item) -> some View {
        let selected = isSelected(item)
        return Button { selection = item.tab } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: item.symbol).font(.body.weight(.semibold))
                    .symbolEffect(.bounce.up, value: selected)
                if selected { Text(item.title).font(.subheadline.weight(.heavy)).fixedSize() }
            }
            .padding(.horizontal, selected ? 18 : 14)
            .frame(minHeight: 48)
            .foregroundStyle(selected ? Color.ds.canvas : Color.ds.ink)
            .background {
                if selected { Capsule().fill(Color.ds.ink).matchedGeometryEffect(id: "pill", in: pill) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
        .accessibilityIdentifier(item.identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
