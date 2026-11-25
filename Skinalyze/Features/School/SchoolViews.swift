import SwiftUI
import SkinalyzeKit

// Skin School: a card on the Shelf, the lesson list, and the lesson player (cards → two questions → result).

/// On the Shelf: Pimpi, the XP so far and the next lesson.
struct SkinSchoolCard: View {
    @Environment(SchoolModel.self) private var school
    @State private var showsPath = false

    private enum Metrics {
        static let pimpi: CGFloat = 56
    }

    var body: some View {
        if !school.visibleLessons.isEmpty {
            Button { showsPath = true } label: {
                PimpiRow(spacing: Spacing.sm) {
                    Pimpi(mood: .curious).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Skin School").font(.effortRow).foregroundStyle(Color.ds.ink)
                        Group {
                            if let next = school.nextLesson {
                                Text("Next: \(school.text(next.title))")
                            } else {
                                Text("Every lesson done!")
                            }
                        }
                        .font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                        EffortTag(text: Text("\(school.progress.xp) XP"), quiet: true)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.effortRow).foregroundStyle(Color.ds.ink)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.effortRow)
            .accessibilityIdentifier("skinSchoolCard")
            .fullScreenCover(isPresented: $showsPath) { LessonPathView() }
        }
    }
}

/// Units with their lessons as rows: finished ones are ticked, the next one is the filled row with a bouncing star,
/// the ones after it (and the Pro ones) are locked. The first unit sits on the sky, later ones on the hill.
struct LessonPathView: View {
    @Environment(SchoolModel.self) private var school
    @Environment(ProAccess.self) private var access: ProAccess?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playing: Lesson?
    @State private var paywall: PaywallReason?

    private enum Metrics {
        static let pimpi: CGFloat = 104
        static let openMark: CGFloat = 44
        /// The open lesson's star bounces, then rests this long.
        static let starRest: Double = 0.6
    }

    private var hasFullAccess: Bool { access?.policy.hasFullAccess ?? true }

    /// The units that have something to show, with only their visible lessons.
    private var units: [(id: String, title: String, lessons: [Lesson])] {
        school.course.units.compactMap { unit in
            let lessons = unit.lessons.filter { lesson in school.visibleLessons.contains { $0.id == lesson.id } }
            return lessons.isEmpty ? nil : (school.text(unit.title), school.text(unit.title), lessons)
        }
    }

    var body: some View {
        let units = units
        NavigationStack {
            EffortScroll {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    ForEach(units.prefix(1), id: \.id) { unitView($0.title, lessons: $0.lessons) }
                }
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    ForEach(units.dropFirst(), id: \.id) { unitView($0.title, lessons: $0.lessons) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Skin School")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "graduationcap.fill").foregroundStyle(Color.ds.signal)
                        Text("\(school.progress.xp) XP").foregroundStyle(Color.ds.ink)
                    }
                    .font(.effortRow)
                    .accessibilityElement(children: .combine)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .fullScreenCover(item: $playing) { LessonPlayerView(lesson: $0) }
        .paywallSheet($paywall)
    }

    // MARK: Header

    private var header: some View {
        PimpiRow(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Skin School")
                    .font(.ds.display).foregroundStyle(Color.ds.ink)
                    .accessibilityAddTraits(.isHeader)
                Group {
                    if let next = school.nextLesson {
                        Text("Next: \(school.text(next.title))")
                    } else {
                        Text("Every lesson done!")
                    }
                }
                .font(.effortRow).foregroundStyle(Color.ds.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PokablePimpi(mood: .curious, size: Metrics.pimpi, cheer: school.progress.xp)
        }
    }

    // MARK: Units

    private func unitView(_ title: String, lessons: [Lesson]) -> some View {
        let needsPro = lessons.contains { school.state(of: $0, hasFullAccess: hasFullAccess) == .needsPro }
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Text(title).font(.ds.titleSmall).foregroundStyle(Color.ds.ink)
                    .accessibilityAddTraits(.isHeader)
                if needsPro { EffortTag(text: Text(verbatim: "Pro")) }
            }
            .padding(.horizontal, Spacing.xxs)
            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                row(lesson, number: index + 1)
            }
        }
    }

    private func row(_ lesson: Lesson, number: Int) -> some View {
        let state = school.state(of: lesson, hasFullAccess: hasFullAccess)
        let isOpen = state == .open
        return Button {
            switch state {
            case .open, .done: playing = lesson
            case .needsPro: paywall = .school
            case .locked, .hidden: break
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                mark(state, number: number)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(school.text(lesson.title))
                        .font(.effortRow)
                        .foregroundStyle(isOpen ? Color.ds.canvas : Color.ds.ink)
                        .multilineTextAlignment(.leading)
                    if !lesson.reviewed || state == .needsPro {
                        HStack(spacing: Spacing.xs) {
                            if state == .needsPro { EffortTag(text: Text(verbatim: "Pro")) }
                            if !lesson.reviewed {
                                Text(verbatim: "Draft").font(.ds.label).foregroundStyle(isOpen ? Color.ds.sun : Color.ds.caution)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isOpen {
                    Image(systemName: "chevron.right").font(.effortRow).foregroundStyle(Color.ds.canvas)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(EffortRowButtonStyle(filled: isOpen, dimsWhenDisabled: false))
        .disabled(state == .locked)
        .accessibilityLabel(Text(school.text(lesson.title)))
        .accessibilityValue(stateLabel(state))
        .accessibilityIdentifier("lesson.\(lesson.id)")
    }

    /// Done: a green check. Open: a star that bounces. Locked: the lesson's number in a ring. Pro: a lock.
    @ViewBuilder private func mark(_ state: SkinSchoolEngine.LessonState, number: Int) -> some View {
        switch state {
        case .done:
            EffortMark(done: true) { EmptyView() }
        case .open:
            ZStack {
                Circle().fill(Color.ds.sun)
                Image(systemName: "star.fill")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.ds.pimpiEye)
                    .symbolEffect(.bounce.up, options: .repeat(.periodic(delay: Metrics.starRest)), isActive: !reduceMotion)
            }
            .frame(width: Metrics.openMark, height: Metrics.openMark)
            .accessibilityHidden(true)
        case .needsPro:
            Image(systemName: "lock.fill")
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.ds.inkSecondary)
                .frame(width: EffortMetrics.mark, height: EffortMetrics.mark)
                .background(Circle().fill(Color.ds.surfaceRaised))
                .accessibilityHidden(true)
        case .locked, .hidden:
            EffortMark(done: false) { Text(number, format: .number) }
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

/// One lesson: its cards, then two questions, then the result with XP and the sources. Pimpi reacts to each answer.
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

    private enum Metrics {
        static let pimpi: CGFloat = 130
        static let segment: CGFloat = 8
        static let segmentGap: CGFloat = 6
        static let markHidden: CGFloat = 0.4
        /// The result arrives in beats: title, then the score and XP, then the sources.
        static let pillsBeat = 4
        static let sourcesBeat = 8
    }

    private var cardCount: Int { lesson.cards.count }
    private var totalSteps: Int { cardCount + lesson.quiz.count }
    private var isResult: Bool { step >= totalSteps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        // Hops on a right answer and at the finish; a wrong one only makes it curious.
                        PokablePimpi(mood: mood, size: Metrics.pimpi, cheer: cheer)
                            .dsAnimation(.bouncy, value: mood)
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
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                    .frame(maxWidth: EffortMetrics.readable)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Color.ds.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xs)
                    .frame(maxWidth: EffortMetrics.readable)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) { EffortHill() }
                    .onHill()
            }
            .navigationTitle(school.text(lesson.title))
            .toolbar(.hidden, for: .navigationBar)
        }
        .sensoryFeedback(Haptic.success, trigger: isResult)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.chunkyIcon)
            HStack(spacing: Metrics.segmentGap) {
                ForEach(0..<max(totalSteps, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < step ? Color.ds.positive : Color.ds.surface)
                        .frame(height: Metrics.segment)
                }
            }
            .dsAnimation(.smooth, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Step \(min(step + 1, totalSteps)) of \(totalSteps)"))
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .frame(maxWidth: EffortMetrics.readable)
        .frame(maxWidth: .infinity)
    }

    /// Changes on a right answer and when the lesson is done.
    private var cheer: Int {
        if isResult { return -1 }
        return mood == .excited ? step : 0
    }

    /// Curious while reading, cheering a right answer and the finish; a wrong answer only makes it curious again.
    private var mood: MascotMood {
        if isResult { return .excited }
        guard step >= cardCount, let picked else { return .curious }
        return picked == lesson.quiz[step - cardCount].answer ? .excited : .curious
    }

    // MARK: Steps

    private func card(_ text: LocalizedText) -> some View {
        VStack(spacing: Spacing.md) {
            Text(school.text(lesson.title))
                .font(.ds.display)
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(school.text(text))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Color.ds.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dsCard(padding: Spacing.lg)
        }
        .accessibilityElement(children: .combine)
    }

    private func question(_ question: QuizQuestion) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(school.text(question.question))
                .font(.ds.title)
                .foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Spacing.xxs)
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                let outcome = outcome(index, question)
                Button {
                    guard picked == nil else { return }
                    picked = index // only the colour and the mark change; the text never moves
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Text(school.text(option))
                            .font(.effortRow)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // Always there, hidden until answered, so the answer's text never reflows.
                        Image(systemName: outcome.symbol ?? "checkmark")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .opacity(outcome.symbol == nil ? 0 : 1)
                            .scaleEffect(outcome.symbol == nil && !reduceMotion ? Metrics.markHidden : 1)
                            .symbolEffect(.bounce, value: picked)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(outcome.fill == nil ? Color.ds.ink : Color.ds.canvas)
                }
                .buttonStyle(EffortRowButtonStyle(fill: outcome.fill, dimsWhenDisabled: false))
                .dsAnimation(.bouncy, value: picked)
                .accessibilityValue(outcome.label)
                .accessibilityIdentifier("quizOption.\(index)")
            }
            if picked != nil {
                Text(school.text(question.explain))
                    .font(.ds.callout.weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xxs)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(trigger: picked) { _, new in
            guard let new else { return nil }
            return new == question.answer ? Haptic.success : .warning
        }
    }

    /// After answering: the right answer turns green with a ✓, a wrong pick turns red with a ✕.
    private func outcome(_ index: Int, _ question: QuizQuestion) -> (fill: Color?, symbol: String?, label: Text) {
        guard let picked else { return (nil, nil, Text(verbatim: "")) }
        if index == question.answer { return (Color.ds.positive, "checkmark", Text("Right")) }
        if index == picked { return (Color.ds.signal, "xmark", Text("Not quite")) }
        return (nil, nil, Text(verbatim: ""))
    }

    private var result: some View {
        let correct = SkinSchoolEngine.correctAnswers(answers, quiz: lesson.quiz)
        return VStack(spacing: Spacing.md) {
            Text("Lesson done!").font(.ds.display).foregroundStyle(Color.ds.ink).multilineTextAlignment(.center)
                .popIn()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) { resultPills(correct: correct) }
                VStack(spacing: Spacing.sm) { resultPills(correct: correct) }
            }
            .popIn(delay: MotionToken.stagger(Metrics.pillsBeat))
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Sources").font(.effortRow).foregroundStyle(Color.ds.ink).accessibilityAddTraits(.isHeader)
                ForEach(lesson.sources, id: \.url) { source in
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            Label(source.title, systemImage: "link")
                                .font(.effortNote)
                                .foregroundStyle(Color.ds.ink)
                                .underline()
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: Chunk.iconButton, alignment: .leading)
                        }
                    }
                }
                Text("General information, not medical advice.").font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()
            .popIn(delay: MotionToken.stagger(Metrics.sourcesBeat))
        }
    }

    @ViewBuilder private func resultPills(correct: Int) -> some View {
        Text("\(correct) of \(lesson.quiz.count) right")
            .font(.effortRow).foregroundStyle(Color.ds.ink)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: Chunk.iconButton)
            .dsSurface(radius: Chunk.iconButton / 2)
        if gainedXP > 0 {
            Text("+\(gainedXP) XP")
                .font(.effortRow).foregroundStyle(Color.ds.canvas)
                .contentTransition(.numericText(value: Double(gainedXP)))
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: Chunk.iconButton)
                .dsSurface(radius: Chunk.iconButton / 2, fill: Color.ds.ink)
        }
    }

    private var footer: some View {
        let inQuiz = step >= cardCount && !isResult
        return Button {
            advance()
        } label: {
            Text(isResult ? "Done" : "Continue")
        }
        .buttonStyle(.chunky)
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
