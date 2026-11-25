import StoreKit
import SwiftData
import SwiftUI
import SkinalyzeKit

// Friends and weekly leagues (E15, E16) and invites (G8). Only a generated name, the routine streak and this week's
// quest points are shared — never photos or skin results.

/// The user's effort right now, for publishing.
@MainActor
enum SocialEffort {
    static func current(engagement: EngagementModel, quests: QuestModel, scans: [ScanSession],
                        calendar: Calendar = .current) -> SocialModel.Effort {
        let today = DayStamp(.now, calendar: calendar)
        let week = RecapEngine.week(containing: today, calendar: calendar)
        let points = RecapEngine.recap(week, history: RecapData.history(scans: scans, quests: quests), calendar: calendar).points
        return SocialModel.Effort(streak: engagement.routine.count, lastActive: EngagementStore().doneDays.max(),
                                  weekPoints: points, outfit: quests.ledger.worn)
    }
}

/// Row on the journey screen.
struct SocialEntryRow: View {
    @Environment(SocialModel.self) private var social
    @State private var showsSocial = false

    var body: some View {
        Button { showsSocial = true } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "person.2.fill").font(.title3.weight(.bold)).foregroundStyle(Color.ds.signal)
                    .frame(minWidth: EffortMetrics.mark)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Friends and league").font(.effortRow).foregroundStyle(Color.ds.ink)
                    Text(social.isSharing ? SocialCopy.tier(social.state.tier) : String(localized: "Off — only you see your progress"))
                        .font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.effortRow).foregroundStyle(Color.ds.ink)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.effortRow)
        .accessibilityIdentifier("socialEntry")
        .sheet(isPresented: $showsSocial) { SocialView() }
    }
}

/// Friends and league: Pimpi and your made-up name on the sky; the picker, friends and ranks on the hill.
struct SocialView: View {
    enum Page: Hashable { case friends, league }

    @Environment(SocialModel.self) private var social
    @Environment(EngagementModel.self) private var engagement
    @Environment(QuestModel.self) private var quests
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    @State private var page = Page.friends
    @State private var confirmingStop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let pimpi: CGFloat = 104
    }

    private var effort: SocialModel.Effort {
        SocialEffort.current(engagement: engagement, quests: quests,
                             scans: allScans.filter { !$0.isDeleted && $0.modelContext != nil })
    }

    var body: some View {
        NavigationStack {
            EffortScroll {
                if social.isSharing {
                    hero
                } else {
                    JoinHero()
                }
            } ground: {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if social.isSharing {
                        PillPicker([(Page.friends, String(localized: "Friends")), (Page.league, String(localized: "League"))],
                                   selection: $page)
                        statusLine
                        Group {
                            switch page {
                            case .friends: FriendsPage(effort: effort)
                            case .league: LeaguePage()
                            }
                        }
                        .id(page)
                        .transition(reduceMotion ? .opacity : .push(from: page == .league ? .trailing : .leading))
                        Button(role: .destructive) { confirmingStop = true } label: {
                            Text("Stop sharing").underline()
                        }
                        .buttonStyle(.plain)
                        .font(.effortNote)
                        .foregroundStyle(Color.ds.ink)
                        .frame(maxWidth: .infinity, minHeight: Chunk.iconButton)
                    } else {
                        JoinPage(effort: effort)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Friends and league")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .refreshable { await social.refresh(effort: effort) }
        }
        .task { await social.refresh(effort: effort) }
        .confirmationDialog("Stop sharing?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Stop sharing", role: .destructive) { Task { await social.stopSharing() } }
        } message: {
            Text("Your public profile is deleted. Friends can't see your streak until you join again.")
        }
    }

    /// Pimpi in its outfit, "You are Sunny Otter" and the friend code.
    private var hero: some View {
        PimpiRow(spacing: Spacing.sm) {
            PokablePimpi(mood: .excited, size: Metrics.pimpi, cheer: social.friends.count)
            if let code = social.state.code, let name = social.state.name {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("You are \(Text(SocialCopy.name(name)).font(.ds.title).foregroundStyle(Color.ds.ink))")
                        .font(.effortRow)
                        .foregroundStyle(Color.ds.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: code.value)
                        .font(.system(.headline, design: .monospaced).weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.ds.ink)
                        .textSelection(.enabled)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .dsSurface(radius: Radius.small)
                        .accessibilityLabel(Text("Your friend code: \(code.value.map(String.init).joined(separator: " "))"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var statusLine: some View {
        switch social.status {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .noAccount:
            Label("Sign in to iCloud in Settings to see friends and leagues.", systemImage: "icloud.slash")
                .font(.effortNote).foregroundStyle(Color.ds.ink)
        case .failed:
            Label("Couldn't reach iCloud. Pull down to try again.", systemImage: "exclamationmark.icloud")
                .font(.effortNote).foregroundStyle(Color.ds.ink)
        case .idle, .ready:
            EmptyView()
        }
    }
}

/// Before joining: Pimpi and what this is.
private struct JoinHero: View {
    private enum Metrics {
        static let pimpi: CGFloat = 110
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            PokablePimpi(mood: .excited, size: Metrics.pimpi)
            Text("Keep each other going")
                .font(.ds.display).foregroundStyle(Color.ds.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Add friends with a code, see each other's streaks, and climb a weekly league ranked only on quests and lessons.")
                .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Opt-in: says exactly what's shared before anything leaves the phone.
private struct JoinPage: View {
    let effort: SocialModel.Effort
    @Environment(SocialModel.self) private var social
    @State private var joining = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                point("Shared: a made-up name like \"Sunny Otter\", your routine streak, this week's quest points and Pimpi's outfit.",
                      symbol: "checkmark.circle.fill", tint: Color.ds.positive)
                point("Never shared: photos, scans, skin results or your real name.", symbol: "lock.fill", tint: Color.ds.signal)
                point("Stored in Apple's iCloud for this app. Turn it off any time and your profile is deleted.",
                      symbol: "icloud.fill", tint: Color.ds.signal)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()
            if social.status == .noAccount {
                Label("Sign in to iCloud in Settings to join.", systemImage: "icloud.slash")
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
            }
            Button {
                joining = true
                Task {
                    await social.join(effort: effort)
                    joining = false
                }
            } label: {
                if joining { ProgressView().tint(Color.ds.canvas) } else { Text("Join") }
            }
            .buttonStyle(.chunky)
            .disabled(joining)
            .accessibilityIdentifier("socialJoin")
        }
    }

    private func point(_ text: LocalizedStringKey, symbol: String, tint: Color) -> some View {
        Label {
            Text(text).foregroundStyle(Color.ds.ink).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .font(.ds.footnote.weight(.semibold))
    }
}

private struct FriendsPage: View {
    let effort: SocialModel.Effort
    @Environment(SocialModel.self) private var social
    @State private var codeText = ""
    @State private var addResult: LocalizedStringKey?
    /// Bumped with every answer to "Add", so the answer pops in afresh.
    @State private var answers = 0
    @State private var removing: SocialProfile?

    private enum Metrics {
        static let pimpi: CGFloat = 46
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if social.friends.isEmpty, social.status == .ready {
                Text("No friends yet. Share your code, or type a friend's.")
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
            }
            ForEach(social.friends, id: \.code) { friend in
                friendRow(friend).transition(.scale.combined(with: .opacity))
            }
            if social.invitedCount > 0 {
                Label("Friends you invited: \(social.invitedCount)", systemImage: "gift.fill")
                    .font(.effortRow).foregroundStyle(Color.ds.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dsCard()
                    .accessibilityIdentifier("invitedCount")
            }
            addFriend.padding(.top, Spacing.xs)
            if let code = social.state.code {
                ShareLink(item: SocialCopy.inviteLink(code), message: Text(SocialCopy.inviteMessage(code))) {
                    Label("Invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.chunky)
                .accessibilityIdentifier("socialInvite")
                Text("A friend who joins through your invite gets a free month of Pro.")
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .dsAnimation(.bouncy, value: social.friends.map(\.code.value))
        .sensoryFeedback(Haptic.success, trigger: social.friends.count) { old, new in new > old }
        .confirmationDialog("Remove this friend?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { friend in
            Button("Remove", role: .destructive) { social.removeFriend(friend.code) }
        }
    }

    private var addFriend: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                TextField("Friend's code", text: $codeText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.ds.ink)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: Chunk.controlHeight)
                    .dsSurface(radius: Chunk.controlHeight / 2)
                    .accessibilityIdentifier("friendCodeField")
                Button("Add") {
                    guard let code = FriendCode(codeText) else {
                        addResult = "That code doesn't look right — it's 6 letters and numbers."
                        answers += 1
                        return
                    }
                    Task {
                        addResult = switch await social.addFriend(code, effort: effort) {
                        case .added: "Friend added!"
                        case .notJoinedYet: "Added. They'll show up once they've joined."
                        case .alreadyFriend: "Already your friend."
                        case .yourOwnCode: "That's your own code."
                        case .full: "You've reached the most friends you can add."
                        }
                        codeText = ""
                        answers += 1
                    }
                }
                .buttonStyle(.chunky(.plain, fullWidth: false, minHeight: Chunk.controlHeight))
                .accessibilityIdentifier("addFriend")
            }
            if let addResult {
                Text(addResult).font(.effortNote).foregroundStyle(Color.ds.ink)
                    .id(answers)
                    .popIn()
            }
        }
    }

    private func friendRow(_ friend: SocialProfile) -> some View {
        let today = social.today
        let together = social.me.map { FriendEngine.togetherStreak($0, friend, today: today, calendar: social.calendar) } ?? 0
        let quest = social.me.map { FriendEngine.questProgress($0, friend, today: today, calendar: social.calendar) }
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Pimpi(mood: .happy).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                    .environment(\.pimpiOutfit, friend.outfit.flatMap(PimpiOutfit.init(rawValue:)))
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(SocialCopy.name(friend.name)).font(.effortRow).foregroundStyle(Color.ds.ink)
                    Label("\(friend.liveStreak(today: today, calendar: social.calendar))-day streak", systemImage: "flame.fill")
                        .font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                    if together > 0 {
                        Text("\(together) days in a row together").font(.effortNote).foregroundStyle(Color.ds.positive)
                    }
                }
                Spacer(minLength: 0)
                Button { removing = friend } label: {
                    Image(systemName: "ellipsis").font(.effortRow).foregroundStyle(Color.ds.ink)
                        .frame(width: Chunk.iconButton, height: Chunk.iconButton)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Remove \(SocialCopy.name(friend.name))"))
            }
            if let quest {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(quest.done ? "Friend quest done this week!" : "Friend quest: \(quest.points) of \(FriendEngine.weeklyGoal) points together")
                        .font(.effortNote).foregroundStyle(Color.ds.inkSecondary)
                    EffortBar(value: Double(quest.points) / Double(max(FriendEngine.weeklyGoal, 1)),
                              tint: quest.done ? Color.ds.positive : Color.ds.signal)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .dsSurface()
        .accessibilityElement(children: .contain)
    }
}

private struct LeaguePage: View {
    @Environment(SocialModel.self) private var social

    private enum Metrics {
        static let place: CGFloat = 34
        static let pimpi: CGFloat = 36
    }

    var body: some View {
        let tier = social.state.tier
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: SocialCopy.tierSymbol(tier)).font(.ds.display).foregroundStyle(Color.ds.signal)
                    .accessibilityHidden(true)
                Text(SocialCopy.tier(tier)).font(.ds.title).foregroundStyle(Color.ds.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            if social.lastMove == .up {
                Label("You moved up this week!", systemImage: "arrow.up.circle.fill")
                    .font(.effortRow).foregroundStyle(Color.ds.positive)
            }
            ForEach(Array(social.league.enumerated()), id: \.element.code) { rank, player in
                row(rank: rank, player: player, isMe: player.code == social.state.code)
                    .popIn(delay: MotionToken.stagger(rank))
            }
            VStack(spacing: Spacing.xxs) {
                Text("Ranked on quest points this week. The top \(LeagueEngine.promotions) move up on Monday.")
                Text("Skin results never count — only showing up.")
            }
            .font(.effortNote).foregroundStyle(Color.ds.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.xs)
        }
    }

    /// One place in the league. Your own row is the filled one.
    private func row(rank: Int, player: SocialProfile, isMe: Bool) -> some View {
        let ink = isMe ? Color.ds.canvas : Color.ds.ink
        return HStack(spacing: Spacing.sm) {
            Text(rank + 1, format: .number)
                .font(.effortRow.monospacedDigit())
                .foregroundStyle(Color.ds.ink)
                .frame(minWidth: Metrics.place, minHeight: Metrics.place)
                .background(Circle().fill(isMe ? Color.ds.sun : Color.ds.surfaceRaised))
            Pimpi(mood: isMe ? .excited : .happy).frame(width: Metrics.pimpi, height: Metrics.pimpi)
                .environment(\.pimpiOutfit, player.outfit.flatMap(PimpiOutfit.init(rawValue:)))
            Text(isMe ? String(localized: "You") : SocialCopy.name(player.name))
                .font(.effortRow).foregroundStyle(ink)
            Spacer(minLength: 0)
            Text("\(player.weekPoints) pts").font(.effortRow.monospacedDigit()).foregroundStyle(ink)
            if rank < LeagueEngine.promotions, player.weekPoints > 0 {
                Image(systemName: "arrow.up").font(.effortRow).foregroundStyle(isMe ? Color.ds.canvas : Color.ds.positive)
                    .accessibilityLabel(Text("Moving up"))
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: Chunk.iconButton)
        .dsSurface(radius: Radius.large, fill: isMe ? Color.ds.ink : Color.ds.surface)
        .accessibilityElement(children: .combine)
    }
}

/// Opened from an invite link: join (if needed), add the inviter, and offer the free month.
struct InviteView: View {
    let inviter: FriendCode
    @Environment(SocialModel.self) private var social
    @Environment(EngagementModel.self) private var engagement
    @Environment(QuestModel.self) private var quests
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    @State private var added = false
    @State private var redeeming = false

    private enum Metrics {
        static let pimpi: CGFloat = 120
    }

    var body: some View {
        let effort = SocialEffort.current(engagement: engagement, quests: quests,
                                          scans: allScans.filter { !$0.isDeleted && $0.modelContext != nil })
        EffortStage {
            VStack(spacing: Spacing.md) {
                Text("A friend invited you")
                    .font(.ds.display).foregroundStyle(Color.ds.ink).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Join to add them and keep each other going. Only a made-up name, your streak and quest points are shared.")
                    .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                PokablePimpi(mood: .excited, size: Metrics.pimpi, cheer: added ? 1 : 0)
            }
        } ground: {
            VStack(spacing: Spacing.md) {
                if added {
                    Label("Friend added!", systemImage: "checkmark.circle.fill")
                        .font(.effortRow).foregroundStyle(Color.ds.ink)
                        .symbolEffect(.bounce, value: added)
                        .frame(minHeight: Chunk.controlHeight)
                        .popIn()
                } else {
                    Button {
                        Task {
                            if !social.isSharing { await social.join(effort: effort, invitedBy: inviter) }
                            if social.isSharing {
                                await social.addFriend(inviter, effort: effort)
                                added = true
                            }
                        }
                    } label: {
                        Text("Join and add friend")
                    }
                    .buttonStyle(.chunky)
                }
                if social.status == .noAccount {
                    Text("Sign in to iCloud in Settings to join.").font(.effortNote).foregroundStyle(Color.ds.ink)
                }
                VStack(spacing: Spacing.xs) {
                    Text("Your gift: a free month of Pro. Enter the code \(Referral.offerCode).")
                        .font(.effortNote).foregroundStyle(Color.ds.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    Button("Redeem free month") { redeeming = true }
                        .buttonStyle(.chunkyPlain)
                }
                .frame(maxWidth: .infinity)
                .dsCard()
                Button { dismiss() } label: { Text("Not now").underline() }
                    .buttonStyle(.plain)
                    .font(.effortNote).foregroundStyle(Color.ds.ink)
                    .frame(minHeight: Chunk.iconButton)
            }
        }
        .sensoryFeedback(Haptic.success, trigger: added)
        .offerCodeRedemption(isPresented: $redeeming)
    }
}

extension FriendCode: @retroactive Identifiable {
    public var id: String { value }
}
