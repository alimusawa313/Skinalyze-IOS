import SwiftUI
import SkinalyzeKit

// Phase 10 batch A on the product page and the Shelf: patch test (P6), opened date and expiry (P7), similar formulas
// (P9, Pro). Copy is general information — never a diagnosis.

/// On a product's page.
struct ProductToolsSection: View {
    let product: CatalogProduct
    @Environment(ShelfToolsModel.self) private var tools
    @Environment(ProAccess.self) private var access: ProAccess?
    @State private var paywall: PaywallReason?

    private var hasFullAccess: Bool { access?.policy.hasFullAccess ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            PatchTestCard(product: product)
            OpenedCard(product: product)
            DupesCard(product: product, hasFullAccess: hasFullAccess) { paywall = .dupes }
        }
        .paywallSheet($paywall)
    }
}

/// The patch test as one white panel on the hill: Pimpi with the heading, what to do, then three day pips that
/// tick off with a pop as you answer each day. Pimpi cheers when the three days are done.
struct PatchTestCard: View {
    let product: CatalogProduct
    @Environment(ShelfToolsModel.self) private var tools
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ScaledMetric(relativeTo: .caption) private var pipSize: CGFloat = 30

    private enum Metrics {
        static let pipTextScale: CGFloat = 0.6
        static let pop: CGFloat = 1.3
        static let popUp: Double = 0.12
        static let popSettle: Double = 0.4
    }

    var body: some View {
        let test = tools.patchTest(for: product.productID)
        let status = test.map { PatchTestEngine.status($0, today: tools.today, calendar: tools.calendar) }
        VStack(alignment: .leading, spacing: Spacing.md) {
            ShelfPimpiHeading(mood: mood(status), title: Text("Patch test"),
                              line: test == nil ? Text("Arm first. Face later.") : nil)
            if let test, let status {
                pips(test)
                content(status, test: test)
            } else {
                Text("Try a little behind your ear or on your inner arm for \(PatchTestEngine.days) days before using it on your face.")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Start a \(PatchTestEngine.days)-day patch test") {
                    withDSAnimation(.bouncy, reduceMotion: reduceMotion) { tools.startPatchTest(product.productID) }
                }
                .buttonStyle(.chunky)
                .accessibilityIdentifier("startPatchTest")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .sensoryFeedback(Haptic.success, trigger: status.map(isClear) ?? false) { _, clear in clear }
    }

    /// Effort only: curious before, happy while you keep checking, cheering once the three days are logged.
    private func mood(_ status: PatchTestEngine.Status?) -> MascotMood {
        guard let status else { return .curious }
        switch status {
        case .running: return .happy
        case .clear: return .excited
        case .changed: return .curious
        }
    }

    private func isClear(_ status: PatchTestEngine.Status) -> Bool {
        if case .clear = status { return true }
        return false
    }

    /// One pip per day, wrapping to the width; a day you checked fills in green with a tick that pops.
    private func pips(_ test: PatchTest) -> some View {
        let checked = test.checks.count
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: pipSize), spacing: Spacing.xs)], alignment: .leading,
                         spacing: Spacing.xs) {
            ForEach(1...PatchTestEngine.days, id: \.self) { day in
                let done = day <= checked
                ZStack {
                    Circle().fill(done ? Color.ds.positive : Color.ds.canvas)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.ds.canvas)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(day, format: .number)
                            .font(.system(.caption, design: .rounded).weight(.heavy).monospacedDigit())
                            .foregroundStyle(Color.ds.ink)
                            .minimumScaleFactor(Metrics.pipTextScale)
                    }
                }
                .frame(width: pipSize, height: pipSize)
                .keyframeAnimator(initialValue: 1.0, trigger: done) { content, scale in
                    content.scaleEffect(reduceMotion ? 1 : scale)
                } keyframes: { _ in
                    SpringKeyframe(Metrics.pop, duration: Metrics.popUp, spring: .snappy)
                    SpringKeyframe(1, duration: Metrics.popSettle, spring: .bouncy(extraBounce: 0.2))
                }
            }
        }
        .dsAnimation(.bouncy, value: checked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Day \(min(checked, PatchTestEngine.days)) of \(PatchTestEngine.days)"))
    }

    @ViewBuilder private func content(_ status: PatchTestEngine.Status, test: PatchTest) -> some View {
        switch status {
        case let .running(day, checkedToday):
            Text("Day \(day) of \(PatchTestEngine.days)")
                .font(.system(.title3, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Color.ds.signal)
                .contentTransition(.numericText(value: Double(day)))
            if checkedToday {
                Label("Checked today", systemImage: "checkmark.circle.fill")
                    .font(.system(.callout, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.positive)
                    .transition(.scale.combined(with: .opacity))
            } else {
                PatchQuestion(test: test)
            }
        case let .changed(day):
            Text("Something changed on day \(day). Stop using it on that spot. If it doesn't settle, ask a pharmacist or doctor.")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(Color.ds.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button("Start again") { tools.startPatchTest(product.productID) }.buttonStyle(.shelfOnCard)
        case .clear:
            Label("Nothing changed in \(PatchTestEngine.days) days.", systemImage: "checkmark.seal.fill")
                .font(.system(.callout, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.positive)
                .popIn()
        }
    }
}

/// A small heading for a shelf tool: an icon and a rounded title.
struct ShelfToolHeading: View {
    let title: Text
    let systemImage: String

    var body: some View {
        Label { title } icon: { Image(systemName: systemImage) }
            .font(.ds.titleSmall)
            .foregroundStyle(Color.ds.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// "Anything changed on the test spot today?" Asked inside a white panel.
struct PatchQuestion: View {
    let test: PatchTest
    @Environment(ShelfToolsModel.self) private var tools
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Anything changed on the test spot today? Redness, itching or bumps?")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(Color.ds.ink)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) { buttons }
                VStack(alignment: .leading, spacing: Spacing.xs) { buttons }
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        Button("No change") {
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { tools.answer(test, changed: false) }
        }
            .buttonStyle(.chunky(.filled, fullWidth: false))
            .accessibilityIdentifier("patchNoChange")
        Button("Something changed") {
            withDSAnimation(.bouncy, reduceMotion: reduceMotion) { tools.answer(test, changed: true) }
        }
            .buttonStyle(.shelfOnCard)
    }
}

/// When you opened it and how long it keeps, straight on the hill.
struct OpenedCard: View {
    let product: CatalogProduct
    @Environment(ShelfToolsModel.self) private var tools
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ShelfToolHeading(title: Text("Opened"), systemImage: "calendar")
            if let opened = tools.opened[product.productID] {
                Text("Opened \(opened.openedOn.date(in: tools.calendar).formatted(date: .abbreviated, time: .omitted)) · keeps \(opened.monthsAfterOpening) months")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                if let status = tools.expiryStatus(product.productID) { ExpiryLabel(status: status) }
                HStack(spacing: Spacing.sm) {
                    Button("Change") { editing = true }
                        .buttonStyle(.chunky(.plain, fullWidth: false))
                    Button("Clear", role: .destructive) { tools.clearOpened(product.productID) }
                        .buttonStyle(.chunky(.plain, fullWidth: false))
                }
            } else {
                Text("Note when you open it, and Skinalyze reminds you when it's past its best.")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button("I opened it") { editing = true }
                    .buttonStyle(.chunky(.plain, fullWidth: false))
                    .accessibilityIdentifier("markOpened")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $editing) { OpenedEditor(product: product) }
    }
}

struct ExpiryLabel: View {
    let status: ExpiryEngine.Status

    var body: some View {
        switch status {
        case let .fresh(daysLeft):
            Label("Good for \(daysLeft) more days", systemImage: "checkmark.circle").foregroundStyle(Color.ds.positive)
                .font(.system(.callout, design: .rounded).weight(.heavy))
        case let .soon(daysLeft):
            Label("Past its best in \(daysLeft) days", systemImage: "clock.badge.exclamationmark").foregroundStyle(Color.ds.caution)
                .font(.system(.callout, design: .rounded).weight(.heavy))
        case let .expired(daysAgo):
            Label("Past its best \(daysAgo) days ago", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Color.ds.signal)
                .font(.system(.callout, design: .rounded).weight(.heavy))
        }
    }
}

private struct OpenedEditor: View {
    let product: CatalogProduct
    @Environment(ShelfToolsModel.self) private var tools
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var months = ExpiryEngine.defaultMonths

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Opened on", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .listRowBackground(Color.ds.surface)
                Picker("Keeps for", selection: $months) {
                    ForEach(ExpiryEngine.monthChoices, id: \.self) { Text("\($0) months").tag($0) }
                }
                .listRowBackground(Color.ds.surface)
                Section {
                    Text("Look for the open-jar symbol on the pack, like \"12M\". It shows how many months it keeps once opened.")
                        .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                }
                .listRowBackground(Color.ds.surface)
            }
            .scrollContentBackground(.hidden)
            .dsCanvas()
            .tint(Color.ds.ink)
            .navigationTitle(product.name)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        tools.setOpened(product.productID, on: DayStamp(date, calendar: tools.calendar), months: months)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let opened = tools.opened[product.productID] {
                date = opened.openedOn.date(in: tools.calendar)
                months = opened.monthsAfterOpening
            }
        }
    }
}

/// Products with a similar formula, as white rows on the hill (Pro).
struct DupesCard: View {
    let product: CatalogProduct
    let hasFullAccess: Bool
    let onLocked: () -> Void

    private enum Metrics {
        static let percent: Double = 100
    }

    var body: some View {
        let dupes = DupeFinder.dupes(for: ProductCatalog.facts(for: product), in: ProductCatalog.shared.facts)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ShelfToolHeading(title: Text("Similar formulas"), systemImage: "square.on.square")
            if dupes.isEmpty {
                note(Text("Nothing close in the catalog yet."))
            } else if !hasFullAccess {
                note(Text("\(dupes.count) products share most of this formula."))
                Button("See them with Pro", action: onLocked)
                    .buttonStyle(.chunky(.plain, fullWidth: false))
                    .accessibilityIdentifier("dupesLocked")
            } else {
                ForEach(dupes, id: \.id) { dupe in
                    if let other = ProductCatalog.shared.product(id: dupe.id) {
                        NavigationLink(value: other) {
                            HStack(spacing: Spacing.sm) {
                                ProductThumbnail(product: other)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(other.brand).font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                                    Text(other.name)
                                        .font(.system(.callout, design: .rounded).weight(.heavy))
                                        .foregroundStyle(Color.ds.ink)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                    Text("\(Int((dupe.similarity * Metrics.percent).rounded()))% similar")
                                        .font(.system(.caption, design: .rounded).weight(.heavy))
                                        .foregroundStyle(Color.ds.signal)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.weight(.heavy)).accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.shelfRow)
                    }
                }
                Text("Similar by ingredients, not by price — compare prices where you shop.")
                    .font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("dupesCard")
    }

    private func note(_ text: Text) -> some View {
        text.font(.system(.callout, design: .rounded).weight(.bold)).foregroundStyle(Color.ds.ink)
    }
}

/// On the Shelf: today's patch-test question and products past (or nearly past) their best, in one white panel.
struct ShelfToolsCard: View {
    @Environment(ShelfToolsModel.self) private var tools

    var body: some View {
        let running = tools.runningTests
        let ageing = tools.opened.keys.sorted().compactMap { id -> (CatalogProduct, ExpiryEngine.Status)? in
            guard let status = tools.expiryStatus(id), let product = ProductCatalog.shared.product(id: id) else { return nil }
            if case .fresh = status { return nil }
            return (product, status)
        }
        if !running.isEmpty || !ageing.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(running, id: \.id) { test in
                    if let product = ProductCatalog.shared.product(id: test.productID),
                       case let .running(day, checkedToday) = PatchTestEngine.status(test, today: tools.today, calendar: tools.calendar) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Label("Patch test · \(product.name) · day \(day) of \(PatchTestEngine.days)", systemImage: "bandage.fill")
                                .font(.system(.headline, design: .rounded).weight(.heavy))
                                .foregroundStyle(Color.ds.ink)
                            if !checkedToday { PatchQuestion(test: test) }
                        }
                    }
                }
                ForEach(ageing, id: \.0.productID) { product, status in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(product.name)
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundStyle(Color.ds.ink)
                        ExpiryLabel(status: status)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()
            .accessibilityIdentifier("shelfToolsCard")
        }
    }
}

/// P10 on the Shelf: today's UV and a sunscreen nudge (off until turned on).
struct UVCard: View {
    @Environment(UVModel.self) private var uv
    @AppStorage("routineLog") private var logRaw = ""
    @Environment(\.colorScheme) private var scheme

    private enum Metrics {
        static let attribution: CGFloat = 12
    }

    var body: some View {
        switch uv.state {
        case .off:
            Button { Task { await uv.setEnabled(true) } } label: {
                Label("Show today's UV and a sunscreen nudge", systemImage: "sun.max.fill")
                    .font(.system(.callout, design: .rounded).weight(.heavy))
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.shelfRow)
            .accessibilityIdentifier("uvEnable")
        case .loading:
            ProgressView().tint(Color.ds.ink).frame(maxWidth: .infinity, minHeight: Chunk.controlHeight)
        case .failed:
            HStack(spacing: Spacing.sm) {
                Label("Couldn't get today's UV.", systemImage: "sun.max.trianglebadge.exclamationmark")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                Spacer(minLength: 0)
                Button("Turn off") { Task { await uv.setEnabled(false) } }
                    .buttonStyle(.chunky(.plain, fullWidth: false))
            }
        case let .ready(index):
            content(index)
        }
    }

    @ViewBuilder private func content(_ index: Int) -> some View {
        let sunscreenDone = RoutineLog(raw: logRaw).isDone(part: "morning", slot: ProductCatalog.Slot.sunscreen.rawValue)
        let nudge = UVAdvice.shouldNudge(index)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text("UV \(index) today · \(Self.levelName(UVAdvice.level(for: index)))").foregroundStyle(Color.ds.ink)
                } icon: {
                    Image(systemName: "sun.max.fill").foregroundStyle(nudge ? Color.ds.caution : Color.ds.positive)
                }
                .font(.ds.titleSmall)
                Spacer(minLength: 0)
                Menu {
                    Button("Turn off UV", role: .destructive) { Task { await uv.setEnabled(false) } }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.ds.ink)
                        .frame(width: Chunk.iconButton, height: Chunk.iconButton)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("UV options"))
            }
            if nudge {
                Text(sunscreenDone ? "Sunscreen's on. Top it up if you're outside for long."
                     : "Sunscreen time — it's the step that matters most today.")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
            } else {
                Text("Low UV today.")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            if let attribution = uv.attribution {
                Link(destination: attribution.legalPageURL) {
                    AsyncImage(url: scheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text(verbatim: " Weather").font(.ds.caption)
                    }
                    .frame(height: Metrics.attribution)
                    .frame(minHeight: Chunk.iconButton, alignment: .leading)
                }
                .accessibilityLabel(Text("Apple Weather data sources"))
            }
        }
        .dsCard()
        .accessibilityIdentifier("uvCard")
    }

    static func levelName(_ level: UVAdvice.Level) -> String {
        switch level {
        case .low: String(localized: "low")
        case .moderate: String(localized: "moderate")
        case .high: String(localized: "high")
        case .veryHigh: String(localized: "very high")
        case .extreme: String(localized: "extreme")
        }
    }
}
