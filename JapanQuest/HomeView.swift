import SwiftUI
import UIKit

// MARK: - Home

// MARK: - Home (Claude Design Final Handoff — Home Vertical Slice)
//
// Visual Source of Truth: PictriDesignHandoffFinal/handoff/PICTRI_FINAL_DESIGN_SPEC.md
// セクションA(HOME)。Behavior/Data Source of Truthは引き続きProduction
// (QuestMemoryStore / QuestFriendStore / 既存のNavigationStack・sheet導線)。
//
// Final Design Homeのhierarchyは「1) friends' photographs 2) さいきん色づいた場所
// 3) inline like/comment 4) header」の4つのみで、Production側に以前あった
// 大きなhero CTAカード(「地図でスポットを探す」)・「気になるスポット」utility一覧は
// Final Design Homeに対応する要素が存在しない
// (Design Spec Must NOT change: 「no 「地図でみる」button on posts」「no map on Home」)。
// これらのCTAが担っていた実際の機能(Mapタブへの遷移)は、下部タブバーのMapタブが
// そのまま提供し続けるため、機能の欠落はない。今回のPhaseでHomeから削除した
// (Production側のみに存在していた旧UI、詳細は最終報告に記載)。
struct HomeView: View {
    @Binding var selectedTab: AppTab
    /// Comment Note展開中はBottom Navigation(ContentView側の常駐要素)を隠す。
    /// キーボードとBottom Navが挟まって見える見た目の窮屈さを解消するための
    /// 最小限の共通配線(実体はContentView側のJQFloatingTabBar表示条件)。
    @Binding var isBottomBarHidden: Bool
    /// v7: Top AreaのAccountアイコンから、旧Bottom Nav 5番目タブと同じ
    /// `JQAccountSheetView`を開くための導線(ContentView側のstate/sheetをそのまま
    /// 再利用し、新しいAccount画面やstateは作らない)。
    let onAccountTap: () -> Void
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var friendStore: QuestFriendStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var profilePost: QuestFeedPost?
    @StateObject private var engagement = PictriHomeEngagementStore()
    @State private var openCommentsPostId: String?
    /// v7 PAGINATION DOTS用。Carousel側から現在中央のREAL post id(virtual idではない)
    /// だけを一方向で受け取る(HomeViewからCarouselのscrollPositionへ書き戻すことは
    /// 一切しない — v5で「双方向bindingにするとcenter anchorが壊れる」ことが判明済み
    /// のため、常にCarousel→HomeViewの一方向syncに限定する)。
    @State private var currentPostId: String?
    #if DEBUG
    @State private var didOpenDebugAccountSheet = false
    #endif

    private var visiblePosts: [QuestFeedPost] {
        let posts = memoryStore.visibleFeedPosts()
        #if DEBUG
        // `-pictriHomeCommentsOpen <postId>` でコメント欄を開いた投稿カードを
        // ScrollViewの自動スクロールなしで確認できるよう、対象投稿を先頭へ並べ替える。
        // 通常操作(likedPostIds/onLike等)には一切影響しない。
        var result = posts
        if let targetId = PictriVisualReview.homeCommentsOpenPostId,
           let index = result.firstIndex(where: { $0.id == targetId }) {
            let target = result.remove(at: index)
            result.insert(target, at: 0)
        }
        // `-pictriHomeFeedCount 0|1|2` でempty/1件/2件状態をQuestSampleData自体を
        // 変更せずにスクショ確認できるようにする。
        if let count = PictriVisualReview.homeFeedCountOverride {
            result = Array(result.prefix(count))
        }
        return result
        #else
        return posts
        #endif
    }

    /// HORIZONTAL MEMORY SOCIAL FINALIZATION: Homeの目的を「自分と友達の
    /// 最近のMemoryを1枚ずつ丁寧に見る場所」に絞り、Vertical Feedを廃止して
    /// Horizontal 3D Carouselへ全面置き換えた。「さいきん色づいた場所」
    /// バナーは新しいHomeの目的(このファイル冒頭コメント参照)に含まれず、
    /// 情報量を減らす方針とも反するため削除した(該当機能はMap/Memories
    /// タブが引き続き提供するため、機能の欠落はない)。
    var body: some View {
        NavigationStack {
            GeometryReader { screen in
            ZStack {
                homeBackground

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, PictriFinalTheme.screenPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                    // v6 VERTICAL COMPOSITION候補比較(A: header-card間を広く
                    // 保ちCardをNavへ寄せる / B: header-card間を狭くしCard-Nav間を
                    // 広げる)。Bは実機でCard下に大きな空白が残り、視線が
                    // 「何もない場所」へ流れて重心が定まらなかった。Aは
                    // Cardが親指の届く快適ゾーン(画面中央〜やや下)に来て、
                    // header直下の余白がブランドの「間」として機能したため採用。
                    Spacer(minLength: 0)

                    // v8 DEVICE-ADAPTIVE HERO HEIGHT CAP: 単一比率を17 Pro/SE
                    // 両方に共有すると、画面のwidth:height比が違う端末では
                    // どちらかが妥協になる(section9で明示的に禁止された)。
                    // 17 Pro(874pt級の高さ)はReference aspect(0.64)へ限界まで
                    // 寄せた0.62、SE(667pt級)はside peek/dots/dockを潰さない
                    // 0.50を使う、実測screen高さによる分岐にした(同じ定数で
                    // 両端末を妥協させない)。
                    feedSection(heroMaxHeight: screen.size.height * (screen.size.height > 800 ? 0.62 : 0.50))

                    // v7 PAGINATION DOTS: Referenceの「小さなdots列」を、
                    // Circular Carouselと矛盾しない形(候補B: center dot+
                    // subtle neighbor dots)で採用。件数が多くても際限なく
                    // 増えないよう、表示するdotそのものをwindow(最大5個)する。
                    paginationDots
                        .padding(.top, 14)

                    Spacer(minLength: 0).frame(maxHeight: 10)

                    // v7 3-CONTROL DOCK: 旧5-tab bar(ContentView側のoverlay)とは
                    // 異なり、HomeのVStack自身の一部として配置する(Homeだけ
                    // 旧barを非表示にし、その代わりをこのDockが担うため、
                    // 二重にbottom paddingを予約する必要が無い)。
                    PictriHomeControlDock(
                        onMapTap: { selectedTab = .map },
                        onCameraTap: { selectedTab = .camera },
                        onAlbumTap: { selectedTab = .memories }
                    )
                    .padding(.bottom, 4)
                }

                // Comment Note Scrim/Sheetは画面全体ZStackのこの階層に置く
                // (Carousel自身の`.overlay`に置くと、scrimがCarouselの高さ分
                // しか暗くならず、header/Action Rowが明るいまま透けて見える
                // 不具合があったため、HomeView全体を覆える位置へ引き上げた)。
                // SIGNATURE PHYSICAL WORLD CLOSURE: Noteを画面の絶対下端からでは
                // なく、Cardのすぐ下あたりから現れるように見せるため、bottom
                // paddingを画面高さの比率(GeometryReader)で計算する
                // (固定pxだと17 Pro/SEで位置がズレるため)。
                if let openPostId = openCommentsPostId,
                   let post = visiblePosts.first(where: { $0.id == openPostId }) {
                    PictriCommentNoteScrim {
                        openCommentsPostId = nil
                    }
                    GeometryReader { proxy in
                        PictriCommentNoteSheet(
                            post: post,
                            comments: engagement.comments(for: post),
                            onSubmit: { text in engagement.addComment(text, to: post) },
                            onClose: { openCommentsPostId = nil },
                            autoFocusComposer: debugCommentsAutoFocus
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, proxy.size.height * 0.22)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(
                reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.86),
                value: openCommentsPostId
            )
            .sheet(item: $profilePost) { post in
                FriendProfileSheet(post: post)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                openDebugProfileIfRequested()
                openDebugAccountSheetIfRequested()
            }
            .onChange(of: openCommentsPostId) { _, newValue in
                isBottomBarHidden = newValue != nil
            }
            }
        }
    }

    /// v8 EDITORIAL TOP PLATE: v7では「PicTri + 右上Account丸」という最小限の
    /// 構成だったが、Referenceを見ると単なるnav barではなく
    /// 「ロゴ+短いサブテキスト」「通知+Accountを1枚のpillへ収めた右側」の
    /// 2ブロックで構成された、雑誌の表紙のような編集的なplateだった。
    /// 今回はPicTriを暖色グラデーションのwordmarkにし、その下へ短い
    /// サブテキストを追加(過去ラウンドでは「文字で埋めない」方針だったが、
    /// 今回のuser指示でReferenceのこの要素を明示的に採用対象とした)。
    /// 右側は通知(既存`friendStore.incomingRequests`のみを使い、実体の無い
    /// 汎用通知画面は作らない)とAccount avatarを1つのdark pillへ統合した。
    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PicTri")
                    .font(PictriTypography.display(21))
                    .tracking(2.2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PictriFinalTheme.ink, PictriDarkTheme.accent.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("あなたの旅の記録")
                    .font(PictriTypography.body(11, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkFaint)
            }

            Spacer(minLength: 0)

            Button(action: onAccountTap) {
                PictriHomeTopPill(badgeCount: friendStore.incomingRequests.count)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("アカウント")
            .accessibilityValue(friendStore.incomingRequests.count == 0 ? "" : "フレンド申請\(friendStore.incomingRequests.count)件")
        }
    }

    /// v5候補BG-A GRAPHITE DEPTH: 単色paperのままだと「ただの黒」に見えるという
    /// 指摘への対応。Card中央付近だけごく弱くluminanceを持ち上げ、周辺は静かに
    /// 落ちる(効果として名指しできる強さにはしない、purple/blue glow等は禁止)。
    /// v5背景候補比較(A: GRAPHITE DEPTH採用 / B: MATTE DARKROOM / C: PHOTOGRAPHIC VOID)。
    /// Bは上下端がわずかに沈むだけでCard自体の物体感には寄与しなかった。Cは
    /// 四隅vignetteを足したが縦長画面では画角外に近く効果がほぼ体感できず、
    /// Aと視覚的に差がつかないままcode量だけ増える不利があったため不採用。
    /// Aは「単色paper」だったCard背後だけをごく弱く持ち上げ、Cardが暗闇に
    /// 沈んでいた問題を、名指しできる強さのglowにせず解消する。
    /// v8: Referenceの背景には、Card周辺の光だけでなく画面上部に極めて微弱な
    /// 「塵」のような光点が散らばっており、それが「暗闇に空気がある」感触の
    /// 一部を担っていた。派手なsparkle/particleにならないよう、静止した・
    /// 極小・極薄(opacity 0.03〜0.07)のdotsを固定座標で数個だけ置く
    /// (動かない・光らない・目立たない ― 「効果」として名指しできない密度)。
    private static let atmosphereFlecks: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (0.12, 0.10, 1.6, 0.06), (0.82, 0.07, 1.2, 0.05), (0.64, 0.16, 1.8, 0.04),
        (0.28, 0.20, 1.3, 0.05), (0.90, 0.22, 1.5, 0.04), (0.06, 0.26, 1.2, 0.05),
        (0.50, 0.06, 1.4, 0.04), (0.72, 0.28, 1.1, 0.05)
    ]

    private var homeBackground: some View {
        ZStack {
            PictriFinalTheme.paper
            RadialGradient(
                colors: [
                    PictriDarkTheme.surfaceRaised.opacity(0.9),
                    PictriDarkTheme.surfaceRaised.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 20,
                endRadius: 460
            )
            GeometryReader { proxy in
                ForEach(Array(Self.atmosphereFlecks.enumerated()), id: \.offset) { _, fleck in
                    Circle()
                        .fill(Color.white.opacity(fleck.opacity))
                        .frame(width: fleck.size, height: fleck.size)
                        .position(x: proxy.size.width * fleck.x, y: proxy.size.height * fleck.y)
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func feedSection(heroMaxHeight: CGFloat) -> some View {
        if visiblePosts.isEmpty {
            homeEmptyState
        } else {
            // v4 CARD-INTEGRATED ACTIONS: Like/CommentはCard自身のoverlayへ
            // 統合したため、Home側の独立Action Rowは廃止した(「Cardから
            // 独立したtileに見える」という指摘への対応)。feedSectionは
            // Carousel単体になった。Comment Note展開時、Card自体がNoteに
            // 押し出されるようにごくわずか(8pt)持ち上がることで、「Noteが
            // 背後から引き出された」物理的な連動を作る。
            PictriHomeCarousel(
                posts: visiblePosts,
                onProfileTap: { profilePost = $0 },
                engagement: engagement,
                openCommentsPostId: $openCommentsPostId,
                currentPostId: $currentPostId,
                heroMaxHeight: heroMaxHeight
            )
            .offset(y: openCommentsPostId != nil ? -8 : 0)
        }
    }

    /// v7 PAGINATION DOTS(候補B採用: center dot + subtle neighbor dots)。
    /// 件数が多くても際限なく増えないよう、表示するdot自体を最大5個へwindowする
    /// (Circular Carouselなので「全ページ数」という概念そのものが無く、
    /// windowなしのdotsはpostsが増えるほど無限に伸びてしまうため)。
    @ViewBuilder
    private var paginationDots: some View {
        if visiblePosts.count > 1 {
            let currentIndex = max(visiblePosts.firstIndex(where: { $0.id == currentPostId }) ?? 0, 0)
            HStack(spacing: 6) {
                ForEach(Self.windowedDotIndices(total: visiblePosts.count, current: currentIndex), id: \.self) { index in
                    // v8 BUGFIX: dotsはLike/Commentと違い「常に暗い写真の上」に
                    // 乗るわけではなく、Card/Dock間の背景(Dark/Lightで色が反転する
                    // homeBackground)の上に直接乗る。固定`Color.white.opacity`だと
                    // Light modeの明るい背景へ溶けて見えなくなる実機バグを確認した
                    // ため、mode-awareな`PictriDarkTheme.textFaint`へ変更した。
                    Circle()
                        .fill(index == currentIndex ? PictriDarkTheme.accent : PictriDarkTheme.textFaint.opacity(0.7))
                        .frame(width: index == currentIndex ? 6 : 5, height: index == currentIndex ? 6 : 5)
                }
            }
            .animation(.easeOut(duration: 0.2), value: currentIndex)
        }
    }

    private static func windowedDotIndices(total: Int, current: Int) -> [Int] {
        let maxDots = 5
        guard total > maxDots else { return Array(0..<total) }
        let half = maxDots / 2
        var start = current - half
        var end = current + half
        if start < 0 {
            end -= start
            start = 0
        }
        if end >= total {
            start -= (end - total + 1)
            end = total - 1
        }
        start = max(start, 0)
        return Array(start...end)
    }

    /// Design Spec Empty state: 「まだ、ともだちの旅はとどいていない」+ invite affordance +
    /// the user's own last memory。灰色イラストやスピナーだけの画面にはしない。
    private var homeEmptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            PictriHairline()
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 8) {
                Text("まだ、ともだちの旅はとどいていない")
                    .font(PictriTypography.body(15, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text("友達コードを共有すると、ここに旅の記録が届くようになります。")
                    .font(PictriTypography.body(12, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)

                Button(action: onAccountTap) {
                    HStack(spacing: 6) {
                        Text("友達コードを共有する")
                        Image(systemName: "arrow.right")
                    }
                    .font(PictriTypography.body(13, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.accent)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)

            PictriHairline()
        }
    }

    /// `-pictriAccountSection <section>` でJQAccountSheetViewを直接開く。
    /// 実際にどのタブが最初に開くかはJQAccountSheetView.resolveInitialSection()が
    /// 同じ起動引数を見て自分で決める(ContentView.resolveInitialTabと同じパターン)。
    /// DEBUG限定。v7: Account sheetの状態自体はContentView側が持つため、ここでは
    /// `onAccountTap`を呼ぶだけ(二重に開かないよう1回だけに制限する)。
    private func openDebugAccountSheetIfRequested() {
        #if DEBUG
        guard !didOpenDebugAccountSheet, PictriVisualReview.homeAccountSection != nil else {
            return
        }
        didOpenDebugAccountSheet = true
        onAccountTap()
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

    /// `-pictriHomeCommentsAutoFocus true` QAスクショ専用(DEBUG限定)。
    private var debugCommentsAutoFocus: Bool {
        #if DEBUG
        return PictriVisualReview.homeCommentsAutoFocus
        #else
        return false
        #endif
    }
}

/// v8: Referenceの「+ / bell / avatar」を1つのdark pillへ収めた右上controlを、
/// PicTriの実データに合わせて再構成した(実機能の無い"+"は追加せず、
/// bellは既存`friendStore.incomingRequests`のバッジのみを表示する)。
private struct PictriHomeTopPill: View {
    let badgeCount: Int

    private var avatarAccent: Color {
        HomeFriendColor.accent(for: "keita_travel")
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: badgeCount > 0 ? "bell.fill" : "bell")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PictriDarkTheme.textFaint)
                    .frame(width: 22, height: 22)

                if badgeCount > 0 {
                    Circle()
                        .fill(PictriDarkTheme.accent)
                        .frame(width: 7, height: 7)
                        .offset(x: 3, y: -1)
                }
            }

            Circle()
                .fill(avatarAccent.opacity(0.94))
                .frame(width: 28, height: 28)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                }
                .overlay {
                    Text("K")
                        .font(PictriTypography.body(11.5, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.72))
                }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.85))
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .contentShape(Capsule())
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
                                .pictriGlass(cornerRadius: 16, shadow: false)
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

                    // 「記録N件」というKPIカードではなく、地名だけを静かに並べる
                    // (旅の記録という数字自体は下の写真グリッドが実質的に語るため、
                    // ここでは独立したstat cardのchromeを持たせない)。
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

                    if !recentFriendPosts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("残してきた記憶")
                                .font(PictriTypography.mono(11, weight: .bold))
                                .tracking(1.0)
                                .foregroundStyle(PictriLightTheme.textFaint)
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
        .overlay {
            RoundedRectangle(cornerRadius: PictriTheme.cornerSmall, style: .continuous)
                .stroke(PictriFinalTheme.line, lineWidth: 1)
        }
    }
}

// MARK: - Account

struct JQAccountSheetView: View {
    @EnvironmentObject var friendStore: QuestFriendStore
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var appearanceStore: PictriAppearanceStore

    @State private var selectedSection: JQAccountSection = JQAccountSheetView.resolveInitialSection()
    @State private var addFriendText = ""
    @State private var didCopyFriendCode = false

    /// `-pictriAccountSection friends|add|requests|settings` で直接開くタブを指定できる。
    /// DEBUG限定。ContentView.resolveInitialTab / MemoriesView.resolveInitialModeと同じパターン。
    /// 既定は「友達」(Profileの主役はheader直下のrecentMemoriesStripであり、
    /// tab自体は友達/共有/設定という副次的な導線のみを担う)。
    private static func resolveInitialSection() -> JQAccountSection {
        #if DEBUG
        return PictriVisualReview.homeAccountSection ?? .friends
        #else
        return .friends
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

    /// 最近のMemory写真(最大6件)。QuestMemoryStore.memoryPhotosから直接導出し、
    /// 新しいSource of Truthは持たない。「自分の旅の表紙」の主役として、
    /// header直下に置く(以前はここに写真が1枚も出てこなかった)。
    private var recentMemoryPhotos: [QuestMemoryPhoto] {
        Array(memoryStore.memoryPhotos.prefix(6))
    }

    var body: some View {
        ZStack {
            PictriLightTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    recentMemoriesStrip
                    sectionTabs
                    sectionContent

                    Spacer(minLength: 40)
                }
                .padding(18)
            }
        }
    }

    /// 「自分の旅の表紙」。Settings dashboardにもSNS follower pageにもしないため、
    /// フォロワー数的な統計カードは持たない。
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
        .frame(maxWidth: .infinity)
    }

    /// 「47県達成率」のような%やchartではなく、実際に残してきた写真を横並びで見せる。
    /// 空の場合も大きなプレースホルダー箱は出さず、1行のテキストのみに留める。
    @ViewBuilder
    private var recentMemoriesStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近の記憶")
                .font(PictriTypography.mono(11, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(PictriLightTheme.textFaint)

            if recentMemoryPhotos.isEmpty {
                Text("まだ記憶がありません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentMemoryPhotos) { photo in
                            recentMemoryTile(for: photo)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recentMemoryTile(for photo: QuestMemoryPhoto) -> some View {
        ZStack {
            if let image = memoryStore.image(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let spot = mockQuestSpots.first(where: { $0.id == photo.spotId }) {
                Rectangle().fill(MemoryVisualStyle.gradient(for: spot))
            } else {
                Rectangle().fill(PictriLightTheme.unvisitedFill)
            }
        }
        .frame(width: 84, height: 105)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerSmall, style: .continuous))
    }

    private var sectionTabs: some View {
        HStack(spacing: 8) {
            JQAccountSectionButton(title: "友達", section: .friends, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "追加", section: .add, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "申請", section: .requests, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "設定", section: .settings, selectedSection: $selectedSection)
        }
        .padding(5)
        .background(PictriLightTheme.unvisitedFill)
        .clipShape(Capsule())
    }

    /// 設定 → 外観。Dark Matte / Light Matteをその場で切り替えられる、既存の
    /// 「設定」行を実体化したもの(旧: 装飾だけで未実装だった行を置き換えた)。
    /// 巨大なtheme picker画面は作らず、1行のsegmented controlに留める。
    private var appearanceRow: some View {
        HStack {
            Image(systemName: "circle.lefthalf.filled")
                .frame(width: 28)
                .foregroundStyle(PictriLightTheme.textSecondary)

            Text("外観")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PictriLightTheme.textPrimary)

            Spacer()

            HStack(spacing: 2) {
                appearanceOptionButton(.dark, label: "ダーク")
                appearanceOptionButton(.light, label: "ライト")
            }
            .padding(3)
            .background(PictriLightTheme.unvisitedFill)
            .clipShape(Capsule())
        }
        .padding(16)
        .pictriLightCard(cornerRadius: PictriLightTheme.rowCornerRadius, shadowRadius: 0)
    }

    private func appearanceOptionButton(_ target: PictriAppearanceMode, label: String) -> some View {
        let isSelected = appearanceStore.mode == target
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                appearanceStore.mode = target
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? PictriLightTheme.textPrimary : PictriLightTheme.textFaint)
                .background(isSelected ? PictriLightTheme.surface : Color.clear)
                .clipShape(Capsule())
        }
        .accessibilityLabel("外観を\(label)にする")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .settings:
            VStack(spacing: 12) {
                JQAccountMenuRow(icon: "person.crop.circle", title: "プロフィール編集")
                JQAccountMenuRow(icon: "lock.fill", title: "友達の見え方")
                JQAccountMenuRow(icon: "bell.fill", title: "通知")
                appearanceRow
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
                // Homeの「地図でスポットを探す」と同じPictriLightCTAButtonStyle経由にすることで、
                // 色は違っても高さ・角丸・文字サイズは同じPicTriのボタンに見えるようにする。
                Button {
                    friendStore.addFriend(username: addFriendText)
                    addFriendText = ""
                    selectedSection = .friends
                } label: {
                    Text("友達に追加")
                }
                .buttonStyle(.pictriLightCTA(tint: PictriLightTheme.coral))
            }
            .padding(15)
            .pictriLightCard(cornerRadius: PictriLightTheme.cardCornerRadius, shadowRadius: 10)

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
    case friends
    case add
    case requests
    case settings
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
        .pictriLightCard(cornerRadius: PictriLightTheme.rowCornerRadius, shadowRadius: 0)
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
        .pictriLightCard(cornerRadius: PictriLightTheme.rowCornerRadius, shadowRadius: 0)
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

            // 「削除」「承認」も、Home/Accountの他CTAと同じ角丸・高さに揃える。
            // 承認だけPictriLightCTAButtonStyle(coral)にして、追加/承認が
            // 同じ形のボタンだと分かるようにする。
            HStack(spacing: 10) {
                Button {
                    friendStore.decline(request)
                } label: {
                    Text("削除")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(PictriLightTheme.unvisitedFill)
                        .foregroundStyle(PictriLightTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: PictriLightTheme.rowCornerRadius, style: .continuous))
                }

                Button {
                    friendStore.accept(request)
                } label: {
                    Text("承認")
                }
                .buttonStyle(.pictriLightCTA(tint: PictriLightTheme.coral))
            }
        }
        .padding(13)
        .pictriLightCard(cornerRadius: PictriLightTheme.rowCornerRadius, shadowRadius: 0)
    }
}
