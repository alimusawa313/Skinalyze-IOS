import SwiftUI
import SkinalyzeKit

/// P5: morning and evening steps beyond the four shelf slots, "worth checking" pairings, and reminder times.
struct RoutineBuilderView: View {
    @Environment(RoutineModel.self) private var routine
    @Environment(\.dismiss) private var dismiss
    @State private var part: RoutinePart = .evening
    @State private var adding = false
    @State private var reminders = RoutineModel.Reminders()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Routine", selection: $part) {
                        Text("Morning").tag(RoutinePart.morning)
                        Text("Evening").tag(RoutinePart.evening)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                let warnings = routine.warnings(for: part)
                if !warnings.isEmpty {
                    Section {
                        ForEach(warnings, id: \.self) { warning in
                            Label(RoutineCopy.warning(warning), systemImage: "exclamationmark.triangle.fill")
                                .font(.ds.footnote)
                                .foregroundStyle(Color.ds.ink)
                                .symbolRenderingMode(.multicolor)
                        }
                    } header: {
                        Text("Worth checking")
                    } footer: {
                        Text("General information about common pairings, not medical advice.")
                    }
                    .accessibilityIdentifier("routineWarnings")
                }
                Section {
                    // The shelf's products (extra steps are listed below).
                    ForEach(Array(routine.items(for: part).dropLast(routine.plan[part].count).enumerated()), id: \.offset) { _, item in
                        Text(item.label).font(.ds.callout)
                    }
                } header: {
                    Text("From your shelf")
                }
                Section {
                    ForEach(routine.plan[part]) { step in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(RoutineModel.title(of: step)).font(.ds.callout)
                            Text(RoutineCopy.kind(step.kind)).font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { routine.plan[part][$0] }.forEach { routine.remove($0, from: part) }
                    }
                    .onMove { routine.move(in: part, from: $0, to: $1) }
                    if routine.plan[part].count < RoutinePlan.maximumExtraSteps {
                        Button { adding = true } label: { Label("Add a step", systemImage: "plus.circle.fill") }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("addRoutineStep")
                    }
                } header: {
                    Text("Extra steps")
                } footer: {
                    Text("Your shelf's cleanser, toner, moisturizer and sunscreen are always part of the routine.")
                }
                Section("Reminders") {
                    Toggle("Morning", isOn: $reminders.morningOn)
                    if reminders.morningOn { DatePicker("Time", selection: time(\.morningAt), displayedComponents: .hourAndMinute) }
                    Toggle("Evening", isOn: $reminders.eveningOn)
                    if reminders.eveningOn { DatePicker("Time", selection: time(\.eveningAt), displayedComponents: .hourAndMinute) }
                }
            }
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
