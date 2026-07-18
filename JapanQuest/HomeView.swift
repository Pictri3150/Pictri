import SwiftUI

// MARK: - Home

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var friendStore: QuestFriendStore

    @State private var showAccountMenu = false
    @State private var likedPostIds: Set<String> = []
    @State private var profilePost: QuestFeedPost?

    private var visiblePosts: [QuestFeedPost] {
        memoryStore.visibleFeedPosts()
    }

    private var completedSpotCount: Int {
        Set(memoryStore.memoryPhotos.map { $0.spotId }).count
    }

    private var kanagawaTotalSpotCount: Int {
        mockQuestPrefectures.first { $0.id == "kanagawa" }?.totalSpotCount ?? 24
    }

    private var unvisitedKanagawaSpots: [QuestSpot] {
        let completedIds = Set(memoryStore.memoryPhotos.map { $0.spotId })
        return mockQuestSpots
            .filter { $0.prefectureId == "kanagawa" && !completedIds.contains($0.id) }
            .sorted { $0.gridIndex < $1.gridIndex }
            .prefix(2)
            .map { $0 }
    }

    /// フレンドの最新の旅の記録から、Heroカードの一言を作る。
    /// 正確な場所は出さず、displayPlace(表示用の地名テキスト)だけを使う。
    private var latestFriendActivityText: String? {
        guard let latest = visiblePosts.first(where: { !$0.isMine }) else {
            return nil
        }
        return "\(latest.username)が\(latest.displayPlace)で新しい記録を残したよ"
    }

    /// 直近7日で旅を残した友達(自分は除く)。Heroに「友達が生きている」感を出すための最小情報。
    private var recentFriendUsernames: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for post in visiblePosts where !post.isMine {
            guard !seen.contains(post.username) else { continue }
            seen.insert(post.username)
            result.append(post.username)
            if result.count == 3 { break }
        }
        return result
    }

    private var heroHeadline: String {
        if completedSpotCount == 0 {
            return "最初の一枚を、現地で残そう"
        }
        if let nextSpot = unvisitedKanagawaSpots.first {
            return "次は\(nextSpot.name)へ行ってみる?"
        }
        return "次のスポットを地図で探す"
    }

    private var heroSubcopy: String {
        if completedSpotCount == 0 {
            if let latestFriendActivityText {
                return latestFriendActivityText
            }
            return "まず1箇所、現地で写真を残してみよう。"
        }
        return "神奈川 \(completedSpotCount) / \(kanagawaTotalSpotCount) スポット"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        topBar
                        questHeroCard
                        if !unvisitedKanagawaSpots.isEmpty {
                            nextSpotSection
                        }
                        recentShareSection

                        Spacer(minLength: 90)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                }
            }
            .sheet(isPresented: $showAccountMenu) {
                JQAccountSheetView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $profilePost) { post in
                FriendProfileSheet(post: post)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func toggleLike(postId: String) {
        if likedPostIds.contains(postId) {
            likedPostIds.remove(postId)
        } else {
            likedPostIds.insert(postId)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ピクトリ")
                    .font(.system(size: 30, weight: .bold))

                Text("場所で見つけて、現地で残す")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            Button {
                showAccountMenu = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(.white.opacity(0.10))
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        }

                    if !friendStore.incomingRequests.isEmpty {
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Text("\(friendStore.incomingRequests.count)")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(.black)
                            }
                            .offset(x: 1, y: 1)
                    }
                }
            }
            .accessibilityLabel("アカウント")
            .accessibilityValue(friendStore.incomingRequests.isEmpty ? "" : "フレンド申請\(friendStore.incomingRequests.count)件")
        }
    }

    private var questHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: PictriTheme.cornerLarge)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .white.opacity(0.045),
                            .white.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 250)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        if !recentFriendUsernames.isEmpty {
                            friendActivityRow
                        }

                        Text(heroHeadline)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text(heroSubcopy)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.52))
                            .lineSpacing(3)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "map.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(color: PictriTheme.accent.opacity(0.35), radius: 10)
                }

                Button {
                    selectedTab = .map
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("地図でスポットを探す")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PictriTheme.cornerLarge)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    /// 「友達の旅が生きている」ことを、文章より先に色とイニシャルで一目で伝える小さな列。
    private var friendActivityRow: some View {
        HStack(spacing: -8) {
            ForEach(Array(recentFriendUsernames.enumerated()), id: \.offset) { index, username in
                Circle()
                    .fill(HomeFriendColor.accent(for: username).opacity(0.85))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .overlay {
                        Circle().stroke(PictriTheme.backgroundTop, lineWidth: 2)
                    }
                    .zIndex(Double(3 - index))
            }

            Text("友達の旅が動いてる")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("友達の旅が動いています")
    }

    private var nextSpotSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PictriSectionHeader("気になるスポット") {
                Button {
                    selectedTab = .map
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("地図で見る")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.10))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }

            ForEach(unvisitedKanagawaSpots) { spot in
                Button {
                    selectedTab = .map
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MemoryVisualStyle.gradient(for: spot))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.92))
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(spot.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            Text("次はここに行ってみる? ・ \(spot.areaName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.52))
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(14)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(spot.name)、\(spot.areaName)。地図で見る")
            }
        }
    }

    private var recentShareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PictriSectionHeader("フレンドの旅の記録") {
                Text("7日間")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.10))
                    .foregroundStyle(.white.opacity(0.72))
                    .clipShape(Capsule())
            }

            if visiblePosts.isEmpty {
                PictriEmptyState(
                    systemImage: "mappin.and.ellipse",
                    title: "まだフレンドの記録がありません",
                    message: "フレンドが旅先で記録を残すと、ここに表示されます。\nまずはあなたが最初の一枚を残してみよう。",
                    actionTitle: "地図でスポットを探す"
                ) {
                    selectedTab = .map
                }
            } else {
                ForEach(visiblePosts.prefix(4)) { post in
                    HomeLargePostCard(
                        post: post,
                        isLiked: likedPostIds.contains(post.id),
                        onLike: { toggleLike(postId: post.id) },
                        onProfileTap: { profilePost = post }
                    )
                }
            }
        }
    }
}

// MARK: - Friend Color

/// 友達ごとに一定の色味を持たせるための共有ヘルパー。
/// Swiftの String.hashValue はプロセスごとにランダム化されるため使わず、
/// UTF8バイトの単純な合計で、再起動しても同じユーザーには同じ色が付くようにする。
enum HomeFriendColor {
    static func accent(for username: String) -> Color {
        let palette: [Color] = [PictriTheme.accent, PictriTheme.warm, .white.opacity(0.7)]
        let stableSeed = username.utf8.reduce(0) { $0 + Int($1) }
        return palette[stableSeed % palette.count]
    }
}

// MARK: - Feed Cards

private struct HomeComment: Identifiable {
    let id = UUID()
    let username: String
    let text: String
}

struct HomeLargePostCard: View {
    let post: QuestFeedPost
    var isLiked: Bool
    var onLike: () -> Void
    var onProfileTap: () -> Void

    @EnvironmentObject var memoryStore: QuestMemoryStore

    @State private var isCommentVisible = false
    @State private var commentDraft = ""
    @State private var comments: [HomeComment]

    init(post: QuestFeedPost, isLiked: Bool, onLike: @escaping () -> Void, onProfileTap: @escaping () -> Void) {
        self.post = post
        self.isLiked = isLiked
        self.onLike = onLike
        self.onProfileTap = onProfileTap
        _comments = State(initialValue: HomeLargePostCard.seedComment(for: post).map { [$0] } ?? [])
    }

    /// フィードが無言に見えないよう、投稿ごとに固定の最初のコメントを1件だけ入れておく。
    /// stableSeedで決定論的に選ぶため、再起動しても同じ投稿には同じコメントが付く。
    private static func seedComment(for post: QuestFeedPost) -> HomeComment? {
        guard !post.isMine else { return nil }
        let samples: [(String, String)] = [
            ("haruka", "ここ気になってた、今度行ってみる"),
            ("sora", "写真だけで空気感が伝わってくる"),
            ("mio", "いいな、私も残しに行きたい"),
            ("kai", "この時間帯のここ、好き")
        ]
        let stableSeed = post.id.utf8.reduce(0) { $0 + Int($1) }
        let (name, text) = samples[stableSeed % samples.count]
        return HomeComment(username: name, text: text)
    }

    private var spot: QuestSpot? {
        mockQuestSpots.first { $0.id == post.spotId }
    }

    /// 投稿一覧っぽさを減らすための、短い旅の空気感コピー。
    /// 投稿ごとに固定(再起動しても同じ投稿には同じ文が付く)。スポットのエリア名を
    /// 織り込むことで、使い回しの定型文ではなく投稿固有の一言に見せる。
    private var travelMoodCaption: String {
        let place = spot?.areaName ?? post.displayPlace
        let phrases = [
            "\(place)の景色を、そのまま残した",
            "\(place)の空気ごと持ち帰った1枚",
            "\(place)でしか撮れない瞬間",
            "旅の途中、\(place)で見つけた景色",
            "少し歩いて、\(place)にたどり着いた"
        ]
        let stableSeed = post.id.utf8.reduce(0) { $0 + Int($1) }
        return phrases[stableSeed % phrases.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            postHeader

            Text(travelMoodCaption)
                .font(.system(size: 12, weight: .medium))
                .italic()
                .foregroundStyle(.white.opacity(0.42))

            ZStack(alignment: .bottomLeading) {
                postVisual

                PictriGlassPill(text: "\(post.displayPlace) ・ \(post.displayDate)")
                    .padding(16)

                if post.isMine {
                    PictriGlassPill(text: "you", tone: .strong)
                        .padding(14)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topTrailing
                        )
                }
            }

            postFooter
        }
        .padding(12)
        .background(PictriTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private var avatarAccent: Color {
        HomeFriendColor.accent(for: post.username)
    }

    private var postHeader: some View {
        Button {
            onProfileTap()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(avatarAccent.opacity(0.20))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Text(String(post.username.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle()
                            .stroke(avatarAccent.opacity(0.55), lineWidth: 1.5)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.username)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9, weight: .bold))
                        Text(post.displayPlace)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(post.username)のプロフィールを見る")
    }

    private var postFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !comments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(comments.prefix(3)) { comment in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(HomeFriendColor.accent(for: comment.username))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)

                            (
                                Text(comment.username)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.88))
                                + Text("  \(comment.text)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.70))
                            )
                            .lineLimit(2)
                        }
                    }
                }
            }

            HStack(spacing: 18) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) {
                        onLike()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .semibold))
                            .scaleEffect(isLiked ? 1.08 : 1.0)
                        Text("\(displayLikeCount)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(isLiked ? PictriTheme.warm : .white.opacity(0.45))
                }
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityLabel(isLiked ? "いいねを取り消す" : "いいねする")
                .accessibilityValue("\(displayLikeCount)件")

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isCommentVisible.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text(comments.isEmpty ? "コメント" : "\(comments.count)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.45))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("コメント欄を開く")
                .accessibilityValue(comments.isEmpty ? "コメントなし" : "\(comments.count)件のコメント")

                Spacer()
            }

            if isCommentVisible {
                HStack(spacing: 8) {
                    TextField("コメントを入力…", text: $commentDraft)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("コメントを入力")
                        .onSubmit(submitComment)

                    Button(action: submitComment) {
                        Text("送信")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("コメントを送信")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func submitComment() {
        let trimmed = commentDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            comments.append(HomeComment(username: "you", text: trimmed))
            commentDraft = ""
            isCommentVisible = false
        }
    }

    @ViewBuilder
    private var postVisual: some View {
        if let image = memoryStore.image(for: post) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 255)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            RoundedRectangle(cornerRadius: 22)
                .fill(placeholderGradient)
                .frame(height: 255)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.black.opacity(0.12))
                }
        }
    }

    private var placeholderGradient: LinearGradient {
        if let spot {
            return MemoryVisualStyle.gradient(for: spot)
        }

        return LinearGradient(
            colors: [.gray.opacity(0.4), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Swiftの String.hashValue はプロセスごとにランダム化されるため、
    /// 以前はアプリを起動するたびにいいね数が変わってしまっていた。
    /// HomeFriendColor.accent と同じUTF8バイト和方式に揃え、常に同じ投稿には同じ数を表示する。
    private var baseLikeCount: Int {
        let stableSeed = post.id.utf8.reduce(0) { $0 + Int($1) }
        return (stableSeed % 17) + 3
    }

    private var displayLikeCount: Int {
        isLiked ? baseLikeCount + 1 : baseLikeCount
    }
}

// MARK: - Friend Profile Sheet

struct FriendProfileSheet: View {
    let post: QuestFeedPost

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.dismiss) private var dismiss

    private var avatarAccent: Color {
        HomeFriendColor.accent(for: post.username)
    }

    /// このフレンドの直近投稿(自分を含む全フィードから絞り込む)。
    /// ランキング的な比較を避けるため、件数はあくまで「本人の記録数」としてのみ使う。
    private var friendPosts: [QuestFeedPost] {
        memoryStore.visibleFeedPosts().filter { $0.username == post.username }
    }

    private var recentPlaces: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for place in friendPosts.map(\.displayPlace) {
            guard !seen.contains(place) else { continue }
            seen.insert(place)
            result.append(place)
            if result.count == 4 { break }
        }
        return result
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }

                    Circle()
                        .fill(avatarAccent.opacity(0.20))
                        .frame(width: 84, height: 84)
                        .overlay {
                            Text(String(post.username.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay {
                            Circle().stroke(avatarAccent.opacity(0.6), lineWidth: 2)
                        }

                    VStack(spacing: 6) {
                        Text(post.username)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)

                        Text("最近の記録: \(post.displayPlace)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.46))
                    }

                    HStack(spacing: 22) {
                        PictriCompactMetric(label: "記録", value: "\(friendPosts.count)件")
                        PictriCompactMetric(label: "最近", value: post.displayPlace)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .pictriSurface(cornerRadius: PictriTheme.cornerMedium)

                    if !recentPlaces.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("最近の旅先")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentPlaces, id: \.self) { place in
                                        Text(place)
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(avatarAccent.opacity(0.16))
                                            .foregroundStyle(avatarAccent)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 12)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Account

struct JQAccountSheetView: View {
    @EnvironmentObject var friendStore: QuestFriendStore
    @EnvironmentObject var memoryStore: QuestMemoryStore

    @State private var selectedSection: JQAccountSection = .profile
    @State private var addFriendText = ""

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    stats
                    sectionTabs
                    sectionContent

                    Spacer(minLength: 40)
                }
                .padding(18)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 82, height: 82)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

            VStack(spacing: 5) {
                Text("keita_travel")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("場所で残す、旅の記録")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            JQAccountStat(title: "フォロー中", value: "\(friendStore.friends.count)")
            JQAccountStat(title: "フォロワー", value: "12")
            JQAccountStat(title: "スポット", value: "\(memoryStore.memoryPhotos.count)")
        }
    }

    private var sectionTabs: some View {
        HStack(spacing: 8) {
            JQAccountSectionButton(title: "概要", section: .profile, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "フォロー", section: .following, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "追加", section: .add, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "申請", section: .requests, selectedSection: $selectedSection)
        }
        .padding(5)
        .background(PictriTheme.surface)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .profile:
            VStack(spacing: 12) {
                JQAccountMenuRow(icon: "person.crop.circle", title: "プロフィール編集")
                JQAccountMenuRow(icon: "lock.fill", title: "公開範囲")
                JQAccountMenuRow(icon: "bell.fill", title: "通知")
                JQAccountMenuRow(icon: "gearshape.fill", title: "設定")
            }

        case .following:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(friendStore.friends) { friend in
                    JQFriendMiniRow(friend: friend)
                }
            }

        case .add:
            VStack(alignment: .leading, spacing: 14) {
                Text("ユーザー名で追加")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                TextField("@username", text: $addFriendText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .semibold))
                    .padding(15)
                    .background(.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    friendStore.addFriend(username: addFriendText)
                    addFriendText = ""
                    selectedSection = .following
                } label: {
                    Text("フォローする")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(15)
            .background(PictriTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22))

        case .requests:
            VStack(alignment: .leading, spacing: 12) {
                if friendStore.incomingRequests.isEmpty {
                    Text("新しい申請はありません")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    ForEach(friendStore.incomingRequests) { request in
                        JQRequestMiniRow(request: request)
                    }
                }
            }
        }
    }
}

enum JQAccountSection {
    case profile
    case following
    case add
    case requests
}

struct JQAccountSectionButton: View {
    let title: String
    let section: JQAccountSection
    @Binding var selectedSection: JQAccountSection

    var body: some View {
        Button {
            selectedSection = section
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selectedSection == section ? .white : .clear)
                .foregroundStyle(selectedSection == section ? .black : .white.opacity(0.68))
                .clipShape(Capsule())
        }
    }
}

struct JQAccountStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(PictriTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct JQAccountMenuRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 16, weight: .semibold))

            Spacer()
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(PictriTheme.surfaceStrong)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct JQFriendMiniRow: View {
    let friend: QuestFriend

    var body: some View {
        HStack(spacing: 13) {
            Circle()
                .fill(.white.opacity(0.13))
                .frame(width: 46, height: 46)
                .overlay {
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("@\(friend.username)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Text("フォロー中")
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08))
                .foregroundStyle(.white.opacity(0.75))
                .clipShape(Capsule())
        }
        .padding(13)
        .background(PictriTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct JQRequestMiniRow: View {
    @EnvironmentObject var friendStore: QuestFriendStore
    let request: QuestFriendRequest

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 13) {
                Circle()
                    .fill(.white.opacity(0.13))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(String(request.displayName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text("@\(request.username)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    friendStore.decline(request)
                } label: {
                    Text("削除")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.08))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    friendStore.accept(request)
                } label: {
                    Text("承認")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(13)
        .background(PictriTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
