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
        VStack(alignment: .leading, spacing: Spacing.md) {
            PatchTestCard(product: product)
            OpenedCard(product: product)
            DupesCard(product: product, hasFullAccess: hasFullAccess) { paywall = .dupes }
        }
        .paywallSheet($paywall)
    }
}

struct PatchTestCard: View {
    let product: CatalogProduct
    @Environment(ShelfToolsModel.self) private var tools

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Patch test", systemImage: "bandage").font(.ds.headline)
            if let test = tools.patchTest(for: product.productID) {
                content(test)
            } else {
                Text("Try a little behind your ear or on your inner arm for \(PatchTestEngine.days) days before using it on your face.")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                Button("Start a \(PatchTestEngine.days)-day patch test") { tools.startPatchTest(product.productID) }
                    .buttonStyle(.bordered).frame(minHeight: 44)
                    .accessibilityIdentifier("startPatchTest")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    @ViewBuilder private func content(_ test: PatchTest) -> some View {
        switch PatchTestEngine.status(test, today: tools.today, calendar: tools.calendar) {
        case let .running(day, checkedToday):
            Text("Day \(day) of \(PatchTestEngine.days)").font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.signal)
            if checkedToday {
                Label("Checked today", systemImage: "checkmark.circle.fill").font(.ds.footnote).foregroundStyle(Color.ds.positive)
            } else {
                PatchQuestion(test: test)
            }
        case let .changed(day):
            Text("Something changed on day \(day). Stop using it on that spot. If it doesn't settle, ask a pharmacist or doctor.")
                .font(.ds.footnote).fixedSize(horizontal: false, vertical: true)
            Button("Start again") { tools.startPatchTest(product.productID) }.frame(minHeight: 44)
        case .clear:
            Label("Nothing changed in \(PatchTestEngine.days) days.", systemImage: "checkmark.seal.fill")
                .font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.positive)
        }
    }
}

/// "Anything changed on the test spot today?"
struct PatchQuestion: View {
    let test: PatchTest
    @Environment(ShelfToolsModel.self) private var tools

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Anything changed on the test spot today? Redness, itching or bumps?").font(.ds.footnote)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("No change") { tools.answer(test, changed: false) }
                    .buttonStyle(.borderedProminent).tint(Color.ds.positive)
                    .accessibilityIdentifier("patchNoChange")
                Button("Something changed") { tools.answer(test, changed: true) }
                    .buttonStyle(.bordered)
            }
            .frame(minHeight: 44)
        }
    }
}

struct OpenedCard: View {
    let product: CatalogProduct
    @Environment(ShelfToolsModel.self) private var tools
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Opened", systemImage: "calendar").font(.ds.headline)
            if let opened = tools.opened[product.productID] {
                Text("Opened \(opened.openedOn.date(in: tools.calendar).formatted(date: .abbreviated, time: .omitted)) · keeps \(opened.monthsAfterOpening) months")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                if let status = tools.expiryStatus(product.productID) { ExpiryLabel(status: status) }
                HStack {
                    Button("Change") { editing = true }
                    Button("Clear", role: .destructive) { tools.clearOpened(product.productID) }
                }
                .frame(minHeight: 44)
            } else {
                Text("Note when you open it, and Skinalyze reminds you when it's past its best.")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                Button("I opened it") { editing = true }.buttonStyle(.bordered).frame(minHeight: 44)
                    .accessibilityIdentifier("markOpened")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .sheet(isPresented: $editing) { OpenedEditor(product: product) }
    }
}

struct ExpiryLabel: View {
    let status: ExpiryEngine.Status

    var body: some View {
        switch status {
        case let .fresh(daysLeft):
            Label("Good for \(daysLeft) more days", systemImage: "checkmark.circle").foregroundStyle(Color.ds.positive)
                .font(.ds.footnote.weight(.semibold))
        case let .soon(daysLeft):
            Label("Past its best in \(daysLeft) days", systemImage: "clock.badge.exclamationmark").foregroundStyle(Color.ds.caution)
                .font(.ds.footnote.weight(.semibold))
        case let .expired(daysAgo):
            Label("Past its best \(daysAgo) days ago", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Color.ds.signal)
                .font(.ds.footnote.weight(.semibold))
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
                Picker("Keeps for", selection: $months) {
                    ForEach(ExpiryEngine.monthChoices, id: \.self) { Text("\($0) months").tag($0) }
                }
                Section {
                    Text("Look for the open-jar symbol on the pack, like \"12M\". It shows how many months it keeps once opened.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                }
            }
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

struct DupesCard: View {
    let product: CatalogProduct
    let hasFullAccess: Bool
    let onLocked: () -> Void

    var body: some View {
        let dupes = DupeFinder.dupes(for: ProductCatalog.facts(for: product), in: ProductCatalog.shared.facts)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Similar formulas", systemImage: "square.on.square").font(.ds.headline)
            if dupes.isEmpty {
                Text("Nothing close in the catalog yet.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            } else if !hasFullAccess {
                Text("\(dupes.count) products share most of this formula.").font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                Button("See them with Pro", action: onLocked).buttonStyle(.bordered).frame(minHeight: 44)
                    .accessibilityIdentifier("dupesLocked")
            } else {
                ForEach(dupes, id: \.id) { dupe in
                    if let other = ProductCatalog.shared.product(id: dupe.id) {
                        NavigationLink(value: other) {
                            HStack(spacing: Spacing.sm) {
                                ProductThumbnail(product: other)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(other.brand).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                                    Text(other.name).font(.ds.callout).foregroundStyle(Color.ds.ink).lineLimit(2)
                                    Text("\(Int((dupe.similarity * 100).rounded()))% similar").font(.ds.caption.weight(.semibold))
                                        .foregroundStyle(Color.ds.signal)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Similar by ingredients, not by price — compare prices where you shop.")
                    .font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .accessibilityIdentifier("dupesCard")
    }
}

/// On the Shelf: today's patch-test question and products past (or nearly past) their best.
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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(running, id: \.id) { test in
                    if let product = ProductCatalog.shared.product(id: test.productID),
                       case let .running(day, checkedToday) = PatchTestEngine.status(test, today: tools.today, calendar: tools.calendar) {
                        Label("Patch test · \(product.name) · day \(day) of \(PatchTestEngine.days)", systemImage: "bandage")
                            .font(.ds.callout.weight(.semibold))
                        if !checkedToday { PatchQuestion(test: test) }
                    }
                }
                ForEach(ageing, id: \.0.productID) { product, status in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name).font(.ds.callout)
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
