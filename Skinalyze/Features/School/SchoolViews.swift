import SwiftUI
import SkinalyzeKit

// Skin School: a card on the Shelf, the lesson path, and the lesson player (cards → two questions → result).

/// On the Shelf: Pimpi, the XP so far and the next lesson.
struct SkinSchoolCard: View {
    @Environment(SchoolModel.self) private var school
    @State private var showsPath = false

    private static let pimpiSide: CGFloat = 64

    var body: some View {
        if !school.visibleLessons.isEmpty {
            Button { showsPath = true } label: {
                HStack(spacing: Spacing.md) {
                    Pimpi(mood: .curious).frame(width: Self.pimpiSide, height: Self.pimpiSide)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skin School").font(.ds.headline).foregroundStyle(Color.ds.ink)
                        Group {
                            if let next = school.nextLesson {
                                Text("Next: \(school.text(next.title))")
                            } else {
                                Text("Every lesson done!")
                            }
                        }
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        Text("\(school.progress.xp) XP").font(.ds.label).foregroundStyle(Color.ds.signal)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Color.ds.inkTertiary)
                }
                .dsCard()
            }
            .buttonStyle(.bouncy(0.96))
            .accessibilityIdentifier("skinSchoolCard")
            .fullScreenCover(isPresented: $showsPath) { LessonPathView() }
        }
    }
}

/// Units with their lessons as stepping stones; finished ones are ticked, the next one bounces.
struct LessonPathView: View {
    @Environment(SchoolModel.self) private var school
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playing: Lesson?
    @State private var paywall: PaywallReason?
    @State private var bounce = false

    private static let node: CGFloat = 76
    /// Sideways steps for the winding path, as shares of the node size.
    private static let swing: [CGFloat] = [0, 0.9, 1.2, 0.9, 0, -0.9, -1.2, -0.9]

    private var hasFullAccess: Bool { access?.policy.hasFullAccess ?? true }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    ForEach(school.course.units) { unit in
                        let lessons = unit.lessons.filter { lesson in school.visibleLessons.contains { $0.id == lesson.id } }
                        if !lessons.isEmpty {
                            Text(school.text(unit.title)).font(.ds.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                                stone(lesson)
                                    .offset(x: Self.swing[index % Self.swing.count] * Self.node * 0.8)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .dsCanvas()
            .navigationTitle("Skin School")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "graduationcap.fill")
                        Text("\(school.progress.xp) XP")
                    }
                    .font(.ds.headline).foregroundStyle(Color.ds.signal)
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .fullScreenCover(item: $playing) { LessonPlayerView(lesson: $0) }
        .paywallSheet($paywall)
        .onAppear { bounce = true }
    }

    private func stone(_ lesson: Lesson) -> some View {
        let state = school.state(of: lesson, hasFullAccess: hasFullAccess)
        return Button {
            switch state {
            case .open, .done: playing = lesson
            case .needsPro: paywall = .school
            case .locked, .hidden: break
            }
        } label: {
            VStack(spacing: Spacing.xxs) {
                ZStack {
                    Circle().fill(fill(state))
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
                    Image(systemName: symbol(state)).font(.title.weight(.bold)).foregroundStyle(.white)
                }
                .frame(width: Self.node, height: Self.node)
                .scaleEffect(state == .open && bounce && !reduceMotion ? 1.06 : 1)
                .animation(state == .open && !reduceMotion ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : nil,
                           value: bounce)
                Text(school.text(lesson.title)).font(.ds.footnote.weight(.semibold))
                    .foregroundStyle(state == .locked ? Color.ds.inkTertiary : Color.ds.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: Self.node * 2)
                if !lesson.reviewed {
                    Text(verbatim: "Draft").font(.ds.label).foregroundStyle(Color.ds.caution)
                }
                if state == .needsPro {
                    Text(verbatim: "Pro").font(.ds.label).foregroundStyle(Color.ds.signal)
                }
            }
        }
        .buttonStyle(.bouncy(0.92))
        .disabled(state == .locked)
        .accessibilityLabel(Text(school.text(lesson.title)))
        .accessibilityValue(stateLabel(state))
        .accessibilityIdentifier("lesson.\(lesson.id)")
    }

    private func fill(_ state: SkinSchoolEngine.LessonState) -> Color {
        switch state {
        case .done: .ds.positive
        case .open: .ds.signal
        case .needsPro: .ds.caution
        case .locked, .hidden: .ds.inkTertiary
        }
    }

    private func symbol(_ state: SkinSchoolEngine.LessonState) -> String {
        switch state {
        case .done: "checkmark"
        case .open: "star.fill"
        case .needsPro, .locked, .hidden: "lock.fill"
        }
    }

    private func stateLabel(_ state: SkinSchoolEngine.LessonState) -> Text {
        switch state {
        case .done: Text("Done")
        case .open: Text("Ready to start")
        case .needsPro: Text("Comes with Pro")
        case .locked, .hidden: Text("Finish the lesson before first")
        }
    }
}

/// One lesson: its cards, then two questions, then the result with XP and the sources.
struct LessonPlayerView: View {
    let lesson: Lesson

    @Environment(SchoolModel.self) private var school
    @Environment(QuestModel.self) private var quests: QuestModel?
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var answers: [Int] = []
    @State private var picked: Int?
    @State private var gainedXP = 0

    private var cardCount: Int { lesson.cards.count }
    private var totalSteps: Int { cardCount + lesson.quiz.count }
    private var isResult: Bool { step >= totalSteps }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                ProgressView(value: Double(min(step, totalSteps)), total: Double(totalSteps))
                    .tint(Color.ds.signal)
                ScrollView {
                    Group {
                        if isResult {
                            result
                        } else if step < cardCount {
                            card(lesson.cards[step])
                        } else {
                            question(lesson.quiz[step - cardCount])
                        }
                    }
                    .id(step)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                     removal: .move(edge: .leading).combined(with: .opacity)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                footer
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .dsCanvas()
            .navigationTitle(school.text(lesson.title))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .sensoryFeedback(Haptic.success, trigger: isResult)
    }

    private func card(_ text: LocalizedText) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Pimpi(mood: .curious).frame(width: 96, height: 96)
            Text(school.text(text)).font(.ds.title)
        }
        .accessibilityElement(children: .combine)
    }

    private func question(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(school.text(question.question)).font(.ds.title)
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                Button {
                    guard picked == nil else { return }
                    picked = index // only the border and tick animate; the text never moves
                } label: {
                    HStack {
                        Text(school.text(option)).font(.ds.callout).foregroundStyle(Color.ds.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: Spacing.xs)
                        if picked != nil, index == question.answer {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ds.positive)
                        } else if picked == index {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ds.signal)
                        }
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                            .strokeBorder(border(index, question), lineWidth: 2)
                            .animation(reduceMotion ? nil : .bouncy, value: picked)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quizOption.\(index)")
            }
            if picked != nil {
                Text(school.text(question.explain)).font(.ds.callout).foregroundStyle(Color.ds.inkSecondary)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(trigger: picked) { _, new in
            guard let new else { return nil }
            return new == question.answer ? Haptic.success : .warning
        }
    }

    private func border(_ index: Int, _ question: QuizQuestion) -> Color {
        guard let picked else { return Color.ds.hairline }
        if index == question.answer { return Color.ds.positive }
        return index == picked ? Color.ds.signal : Color.ds.hairline
    }

    private var result: some View {
        let correct = SkinSchoolEngine.correctAnswers(answers, quiz: lesson.quiz)
        return VStack(alignment: .leading, spacing: Spacing.md) {
            Pimpi(mood: .excited).frame(width: 120, height: 120).frame(maxWidth: .infinity)
            Text("Lesson done!").font(.ds.display).frame(maxWidth: .infinity)
            Text("\(correct) of \(lesson.quiz.count) right").font(.ds.headline).frame(maxWidth: .infinity)
            if gainedXP > 0 {
                Text("+\(gainedXP) XP").font(.ds.title).foregroundStyle(Color.ds.signal).frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Sources").font(.ds.headline)
                ForEach(lesson.sources, id: \.url) { source in
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            Label(source.title, systemImage: "link").font(.ds.footnote)
                        }
                    }
                }
                Text("General information, not medical advice.").font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
            }
            .dsCard()
        }
    }

    private var footer: some View {
        let inQuiz = step >= cardCount && !isResult
        return Button {
            advance()
        } label: {
            Text(isResult ? "Done" : "Continue").frame(maxWidth: .infinity)
        }
        .buttonStyle(.dsPrimary)
        .disabled(inQuiz && picked == nil)
        .accessibilityIdentifier("lessonContinue")
    }

    private func advance() {
        if isResult {
            dismiss()
            return
        }
        if step >= cardCount, let picked {
            answers.append(picked)
            self.picked = nil
        }
        withDSAnimation(.smooth, reduceMotion: reduceMotion) { step += 1 }
        if isResult { finish() }
    }

    private func finish() {
        let correct = SkinSchoolEngine.correctAnswers(answers, quiz: lesson.quiz)
        gainedXP = school.complete(lesson, correct: correct)
        quests?.did(.lesson, isPro: access?.policy.hasFullAccess ?? false)
    }
}
