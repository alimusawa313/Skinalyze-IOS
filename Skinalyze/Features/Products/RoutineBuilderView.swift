import SwiftUI
import SkinalyzeKit

/// P5: morning and evening steps beyond the four shelf slots, "worth checking" pairings, and reminder times.
struct RoutineBuilderView: View {
    @Environment(RoutineModel.self) private var routine
    @Environment(\.dismiss) private var dismiss
    @State private var part: RoutinePart = .evening
    @State private var adding = false
    @State private var reminders = RoutineModel.Reminders()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let number: CGFloat = 36
        static let pimpi: CGFloat = 64
        static let dash: CGFloat = 2.5
        static let dashPattern: [CGFloat] = [7, 6]
    }

    var body: some View {
        NavigationStack {
            // A list (not a scroll view) so extra steps keep swipe-to-delete and Edit's reordering.
            List {
                PillPicker([(value: RoutinePart.morning, title: String(localized: "Morning")),
                            (value: RoutinePart.evening, title: String(localized: "Evening"))], selection: $part)
                    .builderRow()
                let warnings = routine.warnings(for: part)
                if !warnings.isEmpty {
                    worthChecking(warnings).builderRow()
                }
                heading(Text("From your shelf"))
                // The shelf's products (extra steps are listed below).
                ForEach(Array(routine.items(for: part).dropLast(routine.plan[part].count).enumerated()), id: \.offset) { index, item in
                    stepRow(number: index + 1, title: Text(item.label), subtitle: nil).builderRow()
                }
                heading(Text("Extra steps"))
                let shelfCount = routine.items(for: part).count - routine.plan[part].count
                ForEach(Array(routine.plan[part].enumerated()), id: \.element.id) { index, step in
                    stepRow(number: shelfCount + index + 1, title: Text(RoutineModel.title(of: step)),
                            subtitle: Text(RoutineCopy.kind(step.kind)), highlighted: true)
                        .builderRow()
                }
                .onDelete { offsets in
                    offsets.map { routine.plan[part][$0] }.forEach { routine.remove($0, from: part) }
                }
                .onMove { routine.move(in: part, from: $0, to: $1) }
                if routine.plan[part].count < RoutinePlan.maximumExtraSteps {
                    addStep.builderRow()
                }
                Text("Your shelf's cleanser, toner, moisturizer and sunscreen are always part of the routine.")
                    .font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
                    .builderRow()
                heading(Text("Reminders"))
                reminderPanel.builderRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .dsCanvas()
            .navigationTitle("Your routine")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
            .sheet(isPresented: $adding) { AddStepView(part: part) }
        }
        .onAppear { reminders = routine.reminders }
        .onChange(of: reminders) { _, updated in Task { await routine.setReminders(updated) } }
    }

    private func heading(_ title: Text) -> some View {
        title
            .font(.ds.titleSmall)
            .foregroundStyle(Color.ds.ink)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Spacing.sm)
            .builderRow()
    }

    /// Pimpi next to the pairings worth a second look, in one white panel.
    private func worthChecking(_ warnings: [RoutineWarning]) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            PokablePimpi(mood: .curious, size: Metrics.pimpi)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Worth checking")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                    .accessibilityAddTraits(.isHeader)
                ForEach(warnings, id: \.self) { warning in
                    Label(RoutineCopy.warning(warning), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .labelStyle(TintedIconLabelStyle(tint: Color.ds.caution))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("General information about common pairings, not medical advice.")
                    .font(.ds.caption.weight(.semibold))
                    .foregroundStyle(Color.ds.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .dsCard()
        .popIn()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("routineWarnings")
    }

    /// One step as a white row: its place in the order, its name and what kind of step it is.
    private func stepRow(number: Int, title: Text, subtitle: Text?, highlighted: Bool = false) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(number, format: .number)
                .font(.system(.callout, design: .rounded).weight(.heavy).monospacedDigit())
                .foregroundStyle(Color.ds.ink)
                .frame(width: Metrics.number, height: Metrics.number)
                .background(Circle().fill(highlighted ? Color.ds.hill : Color.ds.canvas))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                title
                    .font(.system(.callout, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.ink)
                if let subtitle {
                    subtitle.font(.ds.caption.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Chunk.controlHeight)
        .dsSurface(radius: Radius.medium)
        .accessibilityElement(children: .combine)
    }

    /// A dashed outline: there is room for another step.
    private var addStep: some View {
        Button { adding = true } label: {
            Label("Add a step", systemImage: "plus")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.ink)
                .frame(maxWidth: .infinity, minHeight: Chunk.controlHeight)
                .background {
                    Capsule().strokeBorder(Color.ds.ink, style: StrokeStyle(lineWidth: Metrics.dash, lineCap: .round,
                                                                            dash: Metrics.dashPattern))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.bouncy)
        .accessibilityIdentifier("addRoutineStep")
    }

    private var spring: Animation { MotionToken.bouncy.resolved(reduceMotion: reduceMotion).animation }

    private var reminderPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Toggle("Morning", isOn: $reminders.morningOn.animation(spring))
            if reminders.morningOn {
                DatePicker("Time", selection: time(\.morningAt), displayedComponents: .hourAndMinute)
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
            Toggle("Evening", isOn: $reminders.eveningOn.animation(spring))
            if reminders.eveningOn {
                DatePicker("Time", selection: time(\.eveningAt), displayedComponents: .hourAndMinute)
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(Haptic.toggle, trigger: reminders.morningOn)
        .sensoryFeedback(Haptic.toggle, trigger: reminders.eveningOn)
        .font(.system(.callout, design: .rounded).weight(.heavy))
        .foregroundStyle(Color.ds.ink)
        .tint(Color.ds.positive)
        .dsCard()
    }

    private func time(_ keyPath: WritableKeyPath<RoutineModel.Reminders, Int>) -> Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: reminders[keyPath: keyPath] / 60,
                                                       minute: reminders[keyPath: keyPath] % 60)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminders[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }
}

/// A new step: what kind, which product (from the catalog or typed), and what actives it has.
private struct AddStepView: View {
    let part: RoutinePart
    @Environment(RoutineModel.self) private var routine
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ExtraStepKind = .serum
    @State private var query = ""
    @State private var product: CatalogProduct?
    @State private var actives: Set<IngredientCategory> = []

    private static let nameLimit = 60

    var body: some View {
        NavigationStack {
            Form {
                Picker("Step", selection: $kind) {
                    ForEach(ExtraStepKind.allCases, id: \.self) { Text(RoutineCopy.kind($0)).tag($0) }
                }
                Section {
                    TextField("Product name", text: $query)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, text in
                            if text.count > Self.nameLimit { query = String(text.prefix(Self.nameLimit)) }
                            if product.map({ $0.name != text }) ?? false { product = nil }
                        }
                        .accessibilityIdentifier("stepName")
                    if product == nil, query.count >= 3 {
                        ForEach(ProductCatalog.shared.search(query).prefix(5)) { match in
                            Button {
                                product = match
                                query = match.name
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(match.name).font(.ds.callout)
                                    Text(match.brand).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Product")
                } footer: {
                    Text(product == nil ? "Not in the list? Type its name and tick what's in it below." : "Ingredients come from the catalog.")
                }
                if product == nil {
                    Section("What's in it") {
                        ForEach(RoutineCopy.pickableActives, id: \.self) { category in
                            Toggle(RoutineCopy.active(category) ?? "", isOn: Binding {
                                actives.contains(category)
                            } set: { on in
                                if on { actives.insert(category) } else { actives.remove(category) }
                            })
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .dsCanvas()
            .tint(Color.ds.ink)
            .navigationTitle("Add a step")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
                        routine.add(RoutineStep(kind: kind, productID: product?.productID,
                                                customName: product == nil && !name.isEmpty ? name : nil,
                                                actives: product == nil ? actives : []), to: part)
                        dismiss()
                    }
                    .accessibilityIdentifier("confirmAddStep")
                }
            }
        }
    }
}

private extension View {
    /// A list row that is just its content on the page: no row background, no separator, the page's side margins.
    func builderRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Spacing.xxs, leading: Spacing.lg, bottom: Spacing.xxs, trailing: Spacing.lg))
    }
}
