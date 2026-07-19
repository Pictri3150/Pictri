import SwiftUI
import UIKit

// MARK: - Home

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var friendStore: QuestFriendStore

    @State private var showAccountMenu = false
    @State private var likedPostIds: Set<String> = []
    @State private var profilePost: QuestFeedPost?

    private var visiblePosts: [QuestFeedPost] {
        let posts = memoryStore.visibleFeedPosts()
        #if DEBUG
        // `-pictriHomeCommentsOpen <postId>` でコメント欄を開いた投稿カードを
        // ScrollViewの自動スクロールなしで確認できるよう、対象投稿を先頭へ並べ替える。
        // 通常操作(likedPostIds/onLike等)には一切影響しない。
        if let targetId = PictriVisualReview.homeCommentsOpenPostId,
           let index = posts.firstIndex(where: { $0.id == targetId }) {
            var reordered = posts
            let target = reordered.remove(at: index)
            reordered.insert(target, at: 0)
            return reordered
        }
        #endif
        return posts
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
                PictriLightTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        topBar
                        if !isDebugCommentsPreviewActive {
                            questHeroCard
                            if !unvisitedKanagawaSpots.isEmpty {
                                nextSpotSection
                            }
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
            .onAppear {
                openDebugProfileIfRequested()
                openDebugAccountSheetIfRequested()
            }
        }
    }

    /// `-pictriAccountSection <section>` でJQAccountSheetViewを直接開く。
    /// 実際にどのタブが最初に開くかはJQAccountSheetView.resolveInitialSection()が
    /// 同じ起動引数を見て自分で決める(ContentView.resolveInitialTabと同じパターン)。
    /// DEBUG限定。既存のアカウントアイコンタップ導線(showAccountMenu = true)と同じ経路。
    private func openDebugAccountSheetIfRequested() {
        #if DEBUG
        guard !showAccountMenu, PictriVisualReview.homeAccountSection != nil else {
            return
        }
        showAccountMenu = true
        #endif
    }

    /// `-pictriHomeProfile <username>` でFriendProfileSheetを直接開けるようにする。
    /// DEBUG限定。該当ユーザーの投稿が無ければ何もしない(通常のHome表示のまま)。
    /// 既存のアバター/ユーザー名タップ(onProfileTap → profilePost代入)と同じ経路を使う。
    private func openDebugProfileIfRequested() {
        #if DEBUG
        guard profilePost == nil,
              let username = PictriVisualReview.homeProfileUsername,
              let match = visiblePosts.first(where: { $0.username == username }) else {
            return
        }
        profilePost = match
        #endif
    }

    private func toggleLike(postId: String) {
        if likedPostIds.contains(postId) {
            likedPostIds.remove(postId)
        } else {
            likedPostIds.insert(postId)
        }
    }

    /// `-pictriHomeCommentsOpen <postId>` の対象投稿かどうか。DEBUG限定。
    private func isDebugCommentsOpenTarget(_ post: QuestFeedPost) -> Bool {
        #if DEBUG
        return PictriVisualReview.homeCommentsOpenPostId == post.id
        #else
        return false
        #endif
    }

    /// `-pictriHomeCommentsOpen` 指定時はHero/気になるスポットを省略し、
    /// スクロールなしで対象の投稿カード(コメント欄含む)をスクショ確認できるようにする。
    /// DEBUG限定・通常起動には一切影響しない。
    private var isDebugCommentsPreviewActive: Bool {
        #if DEBUG
        return PictriVisualReview.homeCommentsOpenPostId != nil
        #else
        return false
        #endif
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PicTri")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("場所で見つけて、現地で残す")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            Spacer()

            Button {
                showAccountMenu = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(PictriLightTheme.surface)
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PictriLightTheme.sand)
                        }
                        .shadow(color: PictriLightTheme.shadow, radius: 8, x: 0, y: 3)

                    if !friendStore.incomingRequests.isEmpty {
                        Circle()
                            .fill(PictriLightTheme.friendWarm)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Text("\(friendStore.incomingRequests.count)")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(.white)
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
                            PictriLightTheme.mint.opacity(0.22),
                            PictriLightTheme.sand.opacity(0.12),
                            PictriLightTheme.surface
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
                            .foregroundStyle(PictriLightTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text(heroSubcopy)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PictriLightTheme.textSecondary)
                            .lineSpacing(3)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "map.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(PictriLightTheme.mint)
                        .clipShape(Circle())
                        .shadow(color: PictriLightTheme.mint.opacity(0.30), radius: 10)
                }

                // 「Mapで探す」文脈のCTAはmint(訪問・場所の色)にする。
                // 青ボタンをHeroの主役にすると、他のSaaS/AIアプリと見分けがつかなくなるため。
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
                    .background(PictriLightTheme.mint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PictriTheme.cornerLarge)
                .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
        }
        .shadow(color: PictriLightTheme.shadow, radius: 16, x: 0, y: 6)
    }

    /// 「友達の旅が生きている」ことを、文章より先に色とイニシャルで一目で伝える小さな列。
    private var friendActivityRow: some View {
        HStack(spacing: -8) {
            ForEach(Array(recentFriendUsernames.enumerated()), id: \.offset) { index, username in
                Circle()
                    .fill(HomeFriendColor.accent(for: username))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Text(String(username.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle().stroke(PictriLightTheme.surface, lineWidth: 2)
                    }
                    .zIndex(Double(3 - index))
            }

            Text("友達の旅が動いてる")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PictriLightTheme.textSecondary)
                .padding(.leading, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("友達の旅が動いています")
    }

    private var nextSpotSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PictriSectionHeader("気になるスポット", textColor: PictriLightTheme.textPrimary) {
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
                    .background(PictriLightTheme.sandSoft)
                    .foregroundStyle(PictriLightTheme.amber)
                    .clipShape(Capsule())
                }
            }

            // 「気になるスポット」=「次に行きたい場所」なので、余白トーンではなく
            // warm sand/amberで「未訪問だけど魅力的」という温度感を出す。
            ForEach(unvisitedKanagawaSpots) { spot in
                Button {
                    selectedTab = .map
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PictriLightTheme.sandSoft)
                            .frame(width: 42, height: 42)
                            .overlay {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(PictriLightTheme.amber)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(spot.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(PictriLightTheme.textPrimary)

                            Text("次はここに行ってみる? ・ \(spot.areaName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PictriLightTheme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PictriLightTheme.textFaint)
                    }
                    .padding(14)
                    .background(PictriLightTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: PictriLightTheme.shadow, radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(spot.name)、\(spot.areaName)。地図で見る")
            }
        }
    }

    private var recentShareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PictriSectionHeader("フレンドの旅の記録", textColor: PictriLightTheme.textPrimary) {
                Text("7日間")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(PictriLightTheme.unvisitedFill)
                    .foregroundStyle(PictriLightTheme.textSecondary)
                    .clipShape(Capsule())
            }

            if visiblePosts.isEmpty {
                PictriEmptyState(
                    systemImage: "mappin.and.ellipse",
                    title: "まだフレンドの記録がありません",
                    message: "フレンドが旅先で記録を残すと、ここに表示されます。\nまずはあなたが最初の一枚を残してみよう。",
                    actionTitle: "地図でスポットを探す",
                    action: { selectedTab = .map },
                    isLight: true
                )
            } else {
                ForEach(visiblePosts.prefix(4)) { post in
                    HomeLargePostCard(
                        post: post,
                        isLiked: likedPostIds.contains(post.id),
                        onLike: { toggleLike(postId: post.id) },
                        onProfileTap: { profilePost = post },
                        initiallyCommentsOpen: isDebugCommentsOpenTarget(post)
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
    /// 友達アバターの配色は青を使わず、coral/amber/mint/lavenderの4トーンで回す。
    /// 「みんな同じ青いアバター」にならないようにすることで、フィード全体の単調さを減らす。
    static func accent(for username: String) -> Color {
        let palette: [Color] = [
            PictriLightTheme.coral,
            PictriLightTheme.amber,
            PictriLightTheme.mint,
            PictriLightTheme.lavender
        ]
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

    @State private var isCommentVisible: Bool
    @State private var commentDraft = ""
    @State private var comments: [HomeComment]

    init(
        post: QuestFeedPost,
        isLiked: Bool,
        onLike: @escaping () -> Void,
        onProfileTap: @escaping () -> Void,
        initiallyCommentsOpen: Bool = false
    ) {
        self.post = post
        self.isLiked = isLiked
        self.onLike = onLike
        self.onProfileTap = onProfileTap
        _isCommentVisible = State(initialValue: initiallyCommentsOpen)
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
                .foregroundStyle(PictriLightTheme.textSecondary)

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
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: PictriLightTheme.shadow, radius: 12, x: 0, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
        }
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
                    .fill(avatarAccent)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Text(String(post.username.prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.username)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PictriLightTheme.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9, weight: .bold))
                        Text(post.displayPlace)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(post.username)のプロフィールを見る")
    }

    private var postFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                                    .foregroundStyle(PictriLightTheme.textPrimary)
                                + Text(" \(comment.text)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(PictriLightTheme.textSecondary)
                            )
                            .lineLimit(3)
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
                    .foregroundStyle(isLiked ? PictriLightTheme.friendWarm : PictriLightTheme.textFaint)
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
                    .foregroundStyle(PictriLightTheme.textFaint)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("コメント欄を開く")
                .accessibilityValue(comments.isEmpty ? "コメントなし" : "\(comments.count)件のコメント")

                Spacer()
            }

            if isCommentVisible {
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle()
                        .fill(PictriLightTheme.surfaceBorder)
                        .frame(height: 1)

                    HStack(spacing: 8) {
                        TextField("コメントを入力…", text: $commentDraft)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PictriLightTheme.textPrimary)
                            .tint(PictriLightTheme.coral)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(PictriLightTheme.unvisitedFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("コメントを入力")
                            .onSubmit(submitComment)

                        Button(action: submitComment) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 36, height: 36)
                                .background(isCommentDraftEmpty ? PictriLightTheme.unvisitedFill : PictriLightTheme.coral)
                                .foregroundStyle(isCommentDraftEmpty ? PictriLightTheme.textFaint : .white)
                                .clipShape(Circle())
                        }
                        .disabled(isCommentDraftEmpty)
                        .accessibilityLabel("コメントを送信")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var isCommentDraftEmpty: Bool {
        commentDraft.trimmingCharacters(in: .whitespaces).isEmpty
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
            colors: [PictriLightTheme.lavender.opacity(0.55), Color(red: 0.14, green: 0.12, blue: 0.20)],
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

    /// 「N件」という集計だけでなく、「この人はいまも旅している」という時間の気配を
    /// 1行だけ添える。数字の競い合いではなく、直近の記憶をそのまま短く伝える。
    private var recentMomentText: String? {
        guard let latest = friendPosts.first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: latest.createdAt, relativeTo: Date())
        return "\(relative)、\(latest.displayPlace)で記憶をひとつ"
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

    private var recentFriendPosts: [QuestFeedPost] {
        Array(friendPosts.prefix(4))
    }

    var body: some View {
        ZStack {
            PictriLightTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack {
                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(PictriLightTheme.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(PictriLightTheme.surface)
                                .clipShape(Circle())
                                .shadow(color: PictriLightTheme.shadow, radius: 6, x: 0, y: 2)
                        }
                    }

                    Circle()
                        .fill(avatarAccent)
                        .frame(width: 84, height: 84)
                        .overlay {
                            Text(String(post.username.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    Text(post.username)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PictriLightTheme.textPrimary)

                    // フォロワー数ではなく、「友達追加済みで、ここだけに共有されている」という
                    // 身内の安心感を短く伝える。公開SNS感を出さないための最小限の一言。
                    HStack(spacing: 5) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("友達・ここだけで共有")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(PictriLightTheme.textSecondary)

                    if let recentMomentText {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .semibold))
                            Text(recentMomentText)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(PictriLightTheme.friendWarm)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        PictriCompactMetric(label: "旅の記録", value: "\(friendPosts.count)件", isLight: true)

                        if !recentPlaces.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentPlaces, id: \.self) { place in
                                        Text(place)
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(avatarAccent.opacity(0.14))
                                            .foregroundStyle(avatarAccent)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PictriLightTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous)
                            .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
                    }
                    .shadow(color: PictriLightTheme.shadow, radius: 10, x: 0, y: 4)

                    if !recentFriendPosts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("残してきた記憶")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(PictriLightTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                                spacing: 10
                            ) {
                                ForEach(recentFriendPosts) { friendPost in
                                    recentMemoryTile(for: friendPost)
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

    /// 「記録12件」という数字だけで終わらせず、実際に残してきた記憶を小さく見せることで
    /// ランキング的な数値表示ではなく旅の記録として読ませる。
    @ViewBuilder
    private func recentMemoryTile(for friendPost: QuestFeedPost) -> some View {
        ZStack {
            if let image = memoryStore.image(for: friendPost) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let spot = mockQuestSpots.first(where: { $0.id == friendPost.spotId }) {
                Rectangle().fill(MemoryVisualStyle.gradient(for: spot))
            } else {
                Rectangle().fill(PictriLightTheme.unvisitedFill)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerSmall, style: .continuous))
    }
}

// MARK: - Account

struct JQAccountSheetView: View {
    @EnvironmentObject var friendStore: QuestFriendStore
    @EnvironmentObject var memoryStore: QuestMemoryStore

    @State private var selectedSection: JQAccountSection = JQAccountSheetView.resolveInitialSection()
    @State private var addFriendText = ""
    @State private var didCopyFriendCode = false

    /// `-pictriAccountSection profile|friends|add|requests` で直接開くタブを指定できる。
    /// DEBUG限定。ContentView.resolveInitialTab / MemoriesView.resolveInitialModeと同じパターン。
    private static func resolveInitialSection() -> JQAccountSection {
        #if DEBUG
        return PictriVisualReview.homeAccountSection ?? .profile
        #else
        return .profile
        #endif
    }

    /// 「友達コード」カード。QRコード生成等は不要で、身内共有の雰囲気をUIだけで示す。
    /// soft tealを控えめに使い、コピー完了時だけ強調する(コピー前は静かなカード)。
    private var friendCodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("あなたの友達コード")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PictriLightTheme.textSecondary)

            HStack {
                Text("@keita_travel")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Spacer()

                Button {
                    UIPasteboard.general.string = "@keita_travel"
                    withAnimation(.easeOut(duration: 0.2)) {
                        didCopyFriendCode = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            didCopyFriendCode = false
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: didCopyFriendCode ? "checkmark" : "doc.on.doc")
                        Text(didCopyFriendCode ? "コピー済み" : "コピー")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(didCopyFriendCode ? PictriLightTheme.teal.opacity(0.16) : PictriLightTheme.sandSoft)
                    .foregroundStyle(didCopyFriendCode ? PictriLightTheme.teal : PictriLightTheme.sand)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("友達コードをコピー")
            }

            Text("このコードを知っている人だけが、あなたの旅を見られます")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PictriLightTheme.textFaint)
        }
        .padding(15)
        .background(
            LinearGradient(
                colors: [PictriLightTheme.sandSoft, PictriLightTheme.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(PictriLightTheme.warmBorder, lineWidth: 1)
        }
    }

    /// 「フォロワー数」のような公開SNS的な数字ではなく、
    /// 自分の旅がどれだけ色づいたかを示す指標として使う。
    private var visitedPrefectureCount: Int {
        mockQuestPrefectures.filter { memoryStore.completedCount(prefectureId: $0.id) > 0 }.count
    }

    var body: some View {
        ZStack {
            PictriLightTheme.background.ignoresSafeArea()

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
                .fill(PictriLightTheme.sandSoft)
                .frame(width: 82, height: 82)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(PictriLightTheme.sand)
                }

            VStack(spacing: 5) {
                Text("keita_travel")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("場所で残す、旅の記録")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            JQAccountStat(title: "友達", value: "\(friendStore.friends.count)")
            JQAccountStat(title: "訪れた県", value: "\(visitedPrefectureCount)")
            JQAccountStat(title: "スポット", value: "\(memoryStore.memoryPhotos.count)")
        }
    }

    private var sectionTabs: some View {
        HStack(spacing: 8) {
            JQAccountSectionButton(title: "概要", section: .profile, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "友達", section: .friends, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "追加", section: .add, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "申請", section: .requests, selectedSection: $selectedSection)
        }
        .padding(5)
        .background(PictriLightTheme.unvisitedFill)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .profile:
            VStack(spacing: 12) {
                JQAccountMenuRow(icon: "person.crop.circle", title: "プロフィール編集")
                JQAccountMenuRow(icon: "lock.fill", title: "友達の見え方")
                JQAccountMenuRow(icon: "bell.fill", title: "通知")
                JQAccountMenuRow(icon: "gearshape.fill", title: "設定")
            }

        case .friends:
            VStack(alignment: .leading, spacing: 12) {
                if friendStore.friends.isEmpty {
                    PictriEmptyState(
                        systemImage: "person.2",
                        title: "まだ友達がいません",
                        message: "友達コードで身内を追加すると、ここに並びます。",
                        isLight: true
                    )
                } else {
                    ForEach(friendStore.friends) { friend in
                        JQFriendMiniRow(friend: friend)
                    }
                }
            }

        case .add:
            VStack(alignment: .leading, spacing: 14) {
                friendCodeCard

                Text("ユーザー名で友達に追加")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                TextField("@username", text: $addFriendText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .semibold))
                    .padding(15)
                    .background(PictriLightTheme.unvisitedFill)
                    .foregroundStyle(PictriLightTheme.textPrimary)
                    .tint(PictriLightTheme.coral)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // 「友達に追加」はcoral(人の温度感)にする。Accountの主要CTAが
                // 全部青だと、追加・承認・コピーの区別がつかず機械的に見えるため。
                Button {
                    friendStore.addFriend(username: addFriendText)
                    addFriendText = ""
                    selectedSection = .friends
                } label: {
                    Text("友達に追加")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(PictriLightTheme.coral)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(15)
            .background(PictriLightTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
            }
            .shadow(color: PictriLightTheme.shadow, radius: 10, x: 0, y: 4)

        case .requests:
            VStack(alignment: .leading, spacing: 12) {
                if friendStore.incomingRequests.isEmpty {
                    Text("新しい申請はありません")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PictriLightTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(PictriLightTheme.unvisitedFill)
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
    case friends
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
                .background(selectedSection == section ? PictriLightTheme.surface : .clear)
                .foregroundStyle(selectedSection == section ? PictriLightTheme.textPrimary : PictriLightTheme.textFaint)
                .clipShape(Capsule())
                .shadow(color: selectedSection == section ? PictriLightTheme.shadow : .clear, radius: 6, x: 0, y: 2)
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
                .foregroundStyle(PictriLightTheme.textPrimary)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PictriLightTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
        }
        .shadow(color: PictriLightTheme.shadow, radius: 8, x: 0, y: 3)
    }
}

struct JQAccountMenuRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            // 設定メニューの並びなので、機能ごとに色分けせず落ち着いたneutralトーンに統一する。
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(PictriLightTheme.textSecondary)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PictriLightTheme.textPrimary)

            Spacer()
        }
        .padding(16)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
        }
    }
}

struct JQFriendMiniRow: View {
    let friend: QuestFriend

    private var avatarAccent: Color {
        HomeFriendColor.accent(for: friend.username)
    }

    var body: some View {
        HStack(spacing: 13) {
            Circle()
                .fill(avatarAccent)
                .frame(width: 46, height: 46)
                .overlay {
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("@\(friend.username)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            Spacer()

            Text("友達")
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(PictriLightTheme.teal.opacity(0.14))
                .foregroundStyle(PictriLightTheme.teal)
                .clipShape(Capsule())
        }
        .padding(13)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
        }
    }
}

struct JQRequestMiniRow: View {
    @EnvironmentObject var friendStore: QuestFriendStore
    let request: QuestFriendRequest

    private var avatarAccent: Color {
        HomeFriendColor.accent(for: request.username)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 13) {
                Circle()
                    .fill(avatarAccent)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(String(request.displayName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PictriLightTheme.textPrimary)

                    Text("@\(request.username)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PictriLightTheme.textSecondary)
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
                        .background(PictriLightTheme.unvisitedFill)
                        .foregroundStyle(PictriLightTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    friendStore.accept(request)
                } label: {
                    Text("承認")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(PictriLightTheme.coral)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(13)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
        }
    }
}
