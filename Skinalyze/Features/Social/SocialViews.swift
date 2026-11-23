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
                Image(systemName: "person.2.fill").font(.title3).foregroundStyle(Color.ds.signal).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Friends and league").font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.ink)
                    Text(social.isSharing ? SocialCopy.tier(social.state.tier) : String(localized: "Off — only you see your progress"))
                        .font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Color.ds.inkTertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dsCard()
        .accessibilityIdentifier("socialEntry")
        .sheet(isPresented: $showsSocial) { SocialView() }
    }
}

struct SocialView: View {
    enum Page: Hashable { case friends, league }

    @Environment(SocialModel.self) private var social
    @Environment(EngagementModel.self) private var engagement
    @Environment(QuestModel.self) private var quests
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ScanSession.createdAt) private var allScans: [ScanSession]
    @State private var page = Page.friends
    @State private var confirmingStop = false

    private var effort: SocialModel.Effort {
        SocialEffort.current(engagement: engagement, quests: quests,
                             scans: allScans.filter { !$0.isDeleted && $0.modelContext != nil })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if social.isSharing {
                        Picker("Show", selection: $page) {
                            Text("Friends").tag(Page.friends)
                            Text("League").tag(Page.league)
                        }
                        .pickerStyle(.segmented)
                        statusLine
                        switch page {
                        case .friends: FriendsPage(effort: effort)
                        case .league: LeaguePage()
                        }
                        Button("Stop sharing", role: .destructive) { confirmingStop = true }
                            .font(.ds.footnote).frame(minHeight: 44)
                    } else {
                        JoinPage(effort: effort)
                    }
                }
                .padding(Spacing.lg)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .dsCanvas()
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

    @ViewBuilder private var statusLine: some View {
        switch social.status {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .noAccount:
            Label("Sign in to iCloud in Settings to see friends and leagues.", systemImage: "icloud.slash")
                .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
        case .failed:
            Label("Couldn't reach iCloud. Pull down to try again.", systemImage: "exclamationmark.icloud")
                .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
        case .idle, .ready:
            EmptyView()
        }
    }
}

/// Opt-in: says exactly what's shared before anything leaves the phone.
private struct JoinPage: View {
    let effort: SocialModel.Effort
    @Environment(SocialModel.self) private var social
    @State private var joining = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Pimpi(mood: .excited).frame(width: 110, height: 110).frame(maxWidth: .infinity)
            Text("Keep each other going").font(.ds.title)
            Text("Add friends with a code, see each other's streaks, and climb a weekly league ranked only on quests and lessons.")
                .font(.ds.callout).foregroundStyle(Color.ds.inkSecondary)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Shared: a made-up name like \"Sunny Otter\", your routine streak, this week's quest points and Pimpi's outfit.",
                      systemImage: "checkmark.circle.fill")
                Label("Never shared: photos, scans, skin results or your real name.", systemImage: "lock.fill")
                Label("Stored in Apple's iCloud for this app. Turn it off any time and your profile is deleted.",
                      systemImage: "icloud.fill")
            }
            .font(.ds.footnote)
            .dsCard()
            if social.status == .noAccount {
                Label("Sign in to iCloud in Settings to join.", systemImage: "icloud.slash")
                    .font(.ds.footnote).foregroundStyle(Color.ds.caution)
            }
            Button {
                joining = true
                Task {
                    await social.join(effort: effort)
                    joining = false
                }
            } label: {
                Group {
                    if joining { ProgressView() } else { Text("Join") }
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ds.signal)
            .disabled(joining)
            .accessibilityIdentifier("socialJoin")
        }
    }
}

private struct FriendsPage: View {
    let effort: SocialModel.Effort
    @Environment(SocialModel.self) private var social
    @State private var codeText = ""
    @State private var addResult: LocalizedStringKey?
    @State private var removing: SocialProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let code = social.state.code, let name = social.state.name {
                myCard(code: code, name: name)
            }
            addFriend
            if social.friends.isEmpty, social.status == .ready {
                Text("No friends yet. Share your code, or type a friend's.")
                    .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
            ForEach(social.friends, id: \.code) { friend in friendRow(friend) }
            if social.invitedCount > 0 {
                Label("Friends you invited: \(social.invitedCount)", systemImage: "gift.fill")
                    .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.positive)
                    .dsCard()
                    .accessibilityIdentifier("invitedCount")
            }
        }
        .confirmationDialog("Remove this friend?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { friend in
            Button("Remove", role: .destructive) { social.removeFriend(friend.code) }
        }
    }

    private func myCard(code: FriendCode, name: PublicName) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("You are \(SocialCopy.name(name))").font(.ds.headline)
            HStack {
                Text(verbatim: code.value)
                    .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                    .textSelection(.enabled)
                    .accessibilityLabel(Text("Your friend code: \(code.value.map(String.init).joined(separator: " "))"))
                Spacer(minLength: 0)
                ShareLink(item: SocialCopy.inviteLink(code), message: Text(SocialCopy.inviteMessage(code))) {
                    Label("Invite", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("socialInvite")
            }
            Text("A friend who joins through your invite gets a free month of Pro.")
                .font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
        }
        .dsCard()
    }

    private var addFriend: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                TextField("Friend's code", text: $codeText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(Spacing.sm)
                    .frame(minHeight: 44)
                    .background(Color.ds.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    .accessibilityIdentifier("friendCodeField")
                Button("Add") {
                    guard let code = FriendCode(codeText) else {
                        addResult = "That code doesn't look right — it's 6 letters and numbers."
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
                    }
                }
                .buttonStyle(.borderedProminent).tint(Color.ds.signal)
                .frame(minHeight: 44)
                .accessibilityIdentifier("addFriend")
            }
            if let addResult {
                Text(addResult).font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
            }
        }
    }

    private func friendRow(_ friend: SocialProfile) -> some View {
        let today = social.today
        let together = social.me.map { FriendEngine.togetherStreak($0, friend, today: today, calendar: social.calendar) } ?? 0
        let quest = social.me.map { FriendEngine.questProgress($0, friend, today: today, calendar: social.calendar) }
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Pimpi(mood: .happy).frame(width: 48, height: 48)
                    .environment(\.pimpiOutfit, friend.outfit.flatMap(PimpiOutfit.init(rawValue:)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(SocialCopy.name(friend.name)).font(.ds.headline)
                    Label("\(friend.liveStreak(today: today, calendar: social.calendar))-day streak", systemImage: "flame.fill")
                        .font(.ds.footnote).foregroundStyle(Color.ds.signal)
                }
                Spacer(minLength: 0)
                Button { removing = friend } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Remove \(SocialCopy.name(friend.name))"))
            }
            if together > 0 {
                Text("\(together) days in a row together").font(.ds.footnote.weight(.semibold)).foregroundStyle(Color.ds.positive)
            }
            if let quest {
                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.done ? "Friend quest done this week!" : "Friend quest: \(quest.points) of \(FriendEngine.weeklyGoal) points together")
                        .font(.ds.caption).foregroundStyle(Color.ds.inkSecondary)
                    ProgressView(value: min(Double(quest.points) / Double(FriendEngine.weeklyGoal), 1))
                        .tint(quest.done ? Color.ds.positive : Color.ds.signal)
                }
            }
        }
        .dsCard()
        .accessibilityElement(children: .contain)
    }
}

private struct LeaguePage: View {
    @Environment(SocialModel.self) private var social

    var body: some View {
        let tier = social.state.tier
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: SocialCopy.tierSymbol(tier)).font(.largeTitle).foregroundStyle(Color.ds.signal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SocialCopy.tier(tier)).font(.ds.title)
                    Text("Ranked on quest points this week. The top \(LeagueEngine.promotions) move up on Monday.")
                        .font(.ds.footnote).foregroundStyle(Color.ds.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if social.lastMove == .up {
                Label("You moved up this week!", systemImage: "arrow.up.circle.fill")
                    .font(.ds.callout.weight(.semibold)).foregroundStyle(Color.ds.positive)
            }
            ForEach(Array(social.league.enumerated()), id: \.element.code) { rank, player in
                row(rank: rank, player: player, isMe: player.code == social.state.code)
            }
            Text("Skin results never count — only showing up.").font(.ds.caption).foregroundStyle(Color.ds.inkTertiary)
        }
    }

    private func row(rank: Int, player: SocialProfile, isMe: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(rank + 1, format: .number).font(.ds.headline.monospacedDigit()).frame(minWidth: 28)
            Pimpi(mood: isMe ? .excited : .happy).frame(width: 36, height: 36)
                .environment(\.pimpiOutfit, player.outfit.flatMap(PimpiOutfit.init(rawValue:)))
            Text(isMe ? String(localized: "You") : SocialCopy.name(player.name))
                .font(.ds.callout.weight(isMe ? .bold : .regular))
            Spacer(minLength: 0)
            Text("\(player.weekPoints) pts").font(.ds.callout.monospacedDigit())
            if rank < LeagueEngine.promotions, player.weekPoints > 0 {
                Image(systemName: "arrow.up").foregroundStyle(Color.ds.positive).accessibilityLabel(Text("Moving up"))
            }
        }
        .padding(.vertical, Spacing.xxs)
        .padding(.horizontal, Spacing.sm)
        .frame(minHeight: 44)
        .background(isMe ? Color.ds.signal.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
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

    var body: some View {
        let effort = SocialEffort.current(engagement: engagement, quests: quests,
                                          scans: allScans.filter { !$0.isDeleted && $0.modelContext != nil })
        VStack(spacing: Spacing.lg) {
            Pimpi(mood: .excited).frame(width: 120, height: 120)
            Text("A friend invited you").font(.ds.title).multilineTextAlignment(.center)
            Text("Join to add them and keep each other going. Only a made-up name, your streak and quest points are shared.")
                .font(.ds.callout).foregroundStyle(Color.ds.inkSecondary).multilineTextAlignment(.center)
            if added {
                Label("Friend added!", systemImage: "checkmark.circle.fill").foregroundStyle(Color.ds.positive)
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
                    Text("Join and add friend").frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent).tint(Color.ds.signal)
            }
            if social.status == .noAccount {
                Text("Sign in to iCloud in Settings to join.").font(.ds.footnote).foregroundStyle(Color.ds.caution)
            }
            VStack(spacing: Spacing.xs) {
                Text("Your gift: a free month of Pro. Enter the code \(Referral.offerCode).")
                    .font(.ds.footnote).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Button("Redeem free month") { redeeming = true }
                    .frame(minHeight: 44)
            }
            .dsCard()
            Button("Not now") { dismiss() }.frame(minHeight: 44)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 520)
        .offerCodeRedemption(isPresented: $redeeming)
    }
}

extension FriendCode: @retroactive Identifiable {
    public var id: String { value }
}
