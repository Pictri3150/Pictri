import SwiftUI
import UIKit
import Combine

// MARK: - HERO MEMORY & CIRCULAR CAROUSEL CLOSURE(v6, 2026-08-25)
//
// v5までは「Finite Carousel」で、投稿が2件しかない現状のProduction feedでは
// 先頭(最新)投稿から片方向にしか進めなかった(feedの端という設計上の制約で
// あり、Carousel実装自体に方向制限は無いことをv5で確認済み)。今回
// 「投稿が何件でも左右どちらへSwipeしても次のMemoryへ行ける」という
// 明確な要求を受け、Presentation層だけでCIRCULAR/WRAP-AROUNDを実現する。
//
// METHOD比較(実装前に検討):
// A) Virtual Index方式 — 同じposts配列を複数lap分だけ並べたvirtual配列を
//    ForEachに渡し、`post.id`とlap番号を合成した"virtual id"でSwiftUIの
//    Identity管理と実データ(post.id)を分離する。real scrollは常にネイティブ
//    のgesture-driven scrollのみで完結し、lap境界に近づいた時だけ
//    「見た目が完全に同一な位置」へ無アニメーションで飛ばす(同じpostの
//    別lap上のコピーへ移るだけなので、瞬間移動してもピクセル上は何も
//    変わらない)。
// B) Sentinel方式 — [末尾]+実データ+[先頭]という3ブロックだけを並べ、
//    sentinelへ到達したら実位置へ戻す。配列は小さく済むが、
//    「sentinel(末尾の複製)」→「本来の末尾」という**異なる見た目の
//    位置ではなく同じ内容**へのteleportが必須になる点はAと同じだが、
//    Aと違い「安全マージン」を確保できず、毎回の折返しで即座に
//    teleportを発生させる必要がある。
//
// 採用: A。理由は、v5で実機判明した「`scrollPosition`への直接id代入は、
// 対象がArray中間(interior index)かつ`.onAppear`等の事後代入だと中央から
// 数十pt手前で静止する」という不具合(後述のcenteringDiagnosisコメント参照)
// を踏まえ、Bのように「毎回のwrapで必ずteleportが必要」な設計は再発
// リスクが高いと判断したため。Aなら数十lap分のバッファを持たせることで
// 実質「一度のセッションでは絶対に到達しないくらい先」にteleport地点を
// 追いやれる(通常操作では一度もteleportが発生しない)。
//
// v6 CENTERING FIX: v5で発見した「`.onAppear`内の事後代入だと中央からズレる」
// 不具合は、`scrollPosition`をStateの**初期値**(`init`内の`State(initialValue:)`)
// として与えることで解消することを確認した(Appleのサンプルにもある
// 「起動時に特定idへ最初からスクロール済みにする」パターンに合わせた)。
// DEBUG `-pictriHomeScrollTo`もこの初期値経路に統合し、事後代入(旧
// `applyDebugInitialStateIfNeeded`)を廃止した。

// MARK: - Engagement Store(Home専用、local-only)
//
// 既存のlikedPostIds(HomeView@State)/comments(HomeFeedPostRow@State)は
// どちらもview再生成で消える設計だった。新しいHorizontal Carouselは
// LazyHStackでcardが画面外へ出ると再生成されうるため、投稿ID keyedの
// 安定したstoreへ引き上げる。ただしSource of TruthはあくまでQuestMemoryStore
// (投稿データ本体)のままで、これは「いいね/コメントという行為」だけを
// 保持するUI状態(Production backendが存在しないため、他ユーザーへの同期は
// 一切claimしない、local-onlyのUI状態)。
//
// v6注記: Circular化してもLike/Commentは常に`post.id`(実データのid)を
// keyにするため、同じ投稿が複数のvirtual位置に現れても状態は1つに
// 統一されたまま(分裂しない)。
final class PictriHomeEngagementStore: ObservableObject {
    @Published private(set) var likedPostIds: Set<String> = []
    @Published private(set) var commentsByPostId: [String: [PictriHomeComment]] = [:]

    func isLiked(_ postId: String) -> Bool {
        likedPostIds.contains(postId)
    }

    func toggleLike(_ postId: String) {
        if likedPostIds.contains(postId) {
            likedPostIds.remove(postId)
        } else {
            likedPostIds.insert(postId)
        }
    }

    func comments(for post: QuestFeedPost) -> [PictriHomeComment] {
        if let existing = commentsByPostId[post.id] {
            return existing
        }
        let seeded = Self.seedComment(for: post).map { [$0] } ?? []
        return seeded
    }

    func addComment(_ text: String, to post: QuestFeedPost) {
        var current = comments(for: post)
        current.append(PictriHomeComment(username: "you", text: text))
        commentsByPostId[post.id] = current
    }

    /// フィードが無言に見えないよう、投稿ごとに固定の最初のコメントを1件だけ入れておく
    /// (既存HomeFeedPostRowのロジックを踏襲、stableSeedで決定論的)。
    private static func seedComment(for post: QuestFeedPost) -> PictriHomeComment? {
        guard !post.isMine else { return nil }
        let samples: [(String, String)] = [
            ("haruka", "ここ気になってた、今度行ってみる"),
            ("sora", "写真だけで空気感が伝わってくる"),
            ("mio", "いいな、私も残しに行きたい"),
            ("kai", "この時間帯のここ、好き")
        ]
        let stableSeed = post.id.utf8.reduce(0) { $0 + Int($1) }
        let (name, text) = samples[stableSeed % samples.count]
        return PictriHomeComment(username: name, text: text)
    }

    private static func baseLikeCount(for post: QuestFeedPost) -> Int {
        let stableSeed = post.id.utf8.reduce(0) { $0 + Int($1) }
        return (stableSeed % 17) + 3
    }

    func likeCount(for post: QuestFeedPost) -> Int {
        Self.baseLikeCount(for: post) + (isLiked(post.id) ? 1 : 0)
    }
}

struct PictriHomeComment: Identifiable, Equatable {
    let id = UUID()
    let username: String
    let text: String
}

// MARK: - Circular virtual item

/// SwiftUIのForEach/scrollPosition用identityと実データ(`post.id`)を分離する
/// ためのラッパー。`virtualId`だけがView identityとして使われ、Like/Comment/
/// 画像解決は常に`post`(実データ)経由で行う。
private struct PictriCarouselVirtualItem: Identifiable {
    let virtualId: String
    let post: QuestFeedPost
    let virtualIndex: Int
    var id: String { virtualId }
}

// MARK: - Carousel

/// Horizontal 3D Memory Feed。中央Cardが最前面・最大、左右Cardが奥へ
/// 傾いてpeekする。Finger位置に連動したcontinuous transform
/// (突然のstate切り替えは行わない)、`.scrollTargetBehavior(.viewAligned)`
/// によるsnap。posts.count >= 2の場合はCircular(wrap-around)になる。
struct PictriHomeCarousel: View {
    let posts: [QuestFeedPost]
    let onProfileTap: (QuestFeedPost) -> Void
    @ObservedObject var engagement: PictriHomeEngagementStore
    @Binding var openCommentsPostId: String?
    /// v7 PAGINATION DOTS用。Carousel→HomeViewへの一方向syncのみ(HomeView側は
    /// 一切書き戻さない)。v5で判明した「scrollPositionへ双方向bindingすると
    /// center anchorが壊れる」という制約を踏まえ、常にこちらから`onChange`で
    /// 押し出すだけの設計にしている。
    @Binding var currentPostId: String?
    /// v8 HERO HEIGHT CAP: HomeViewが実測したscreen高さから導いた上限。
    /// `cardWidth / cardAspect`(幅由来の高さ)とこの値の小さい方を実際の
    /// cardHeightにすることで、width:height比が端末ごとに違っても
    /// side peek/dots/dockを押し出さないaspect-fitを成立させる。
    let heroMaxHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCarouselLocked = false
    @State private var scrollPosition: String?
    /// v6 GEOMETRY根本整理: `UIScreen.main.bounds`依存を廃し、実際に
    /// GeometryReaderが測定したcontainer幅をsingle source of truthにする。
    /// cardWidth/cardHeight/carouselの外側frame高さは、すべてこの1つの
    /// 値から導出する(複数箇所で別々にwidthを仮定してズレる、という
    /// v5までの潜在バグを構造的に無くす)。
    @State private var measuredContainerWidth: CGFloat = 0

    /// v6再監査: 実写真(renderPlaceholderPhoto)で0.84/0.86を比較。0.86は
    /// occlusion pull強化(18→22pt)のおかげでside peek自体はまだ視認できたが、
    /// SE実機で確認するとcard同士の間隔が窮屈に見え始めたため、安全な0.84を
    /// 維持した(「それ以上はside peek消失リスクが高いため原則不要」という
    /// 方針とも合致)。
    /// v8 REFERENCE FIDELITY: Reference実測(aspect≈0.64, width比67.9%)に対し、
    /// CURRENT(0.84/0.70)/REFERENCE MATCH(0.78/0.64)/RESTRAINED(0.81/0.66)の
    /// 3候補を17 Pro Darkで比較。REFERENCE MATCHが17 Proで破綻せず、side card
    /// の内容(username/count等)がRESTRAINEDより明確に読めるようになり、
    /// Referenceの「奥に本物のMemoryがいる」感触に最も近づいたため採用した
    /// (指示通り、Reference matchが破綻しない限りSE都合で弱めない)。
    private let cardWidthRatio: CGFloat = 0.78
    private let cardAspect: CGFloat = 0.64
    private let cardSpacing: CGFloat = 16
    /// v8: heroMaxHeight導入でSE等の高さ上限がaspect比由来の値と異なる値に
    /// なったことで、Like/Comment countのはみ出し分を隠すバッファがSEで
    /// 実機clippingするのを確認したため32→48へ拡大した。
    private let overflowBuffer: CGFloat = 72
    /// Circular用のlap数(奇数)。中央lapから出発し、両側に(laps-1)/2 lap分の
    /// バッファを持つ。通常の利用でここまで連続Swipeすることは実質無いため、
    /// 「実質無限」として振る舞う(1000件複製のような過大なbufferにはしない)。
    private let laps = 21

    init(
        posts: [QuestFeedPost],
        onProfileTap: @escaping (QuestFeedPost) -> Void,
        engagement: PictriHomeEngagementStore,
        openCommentsPostId: Binding<String?>,
        currentPostId: Binding<String?>,
        heroMaxHeight: CGFloat
    ) {
        self.posts = posts
        self.onProfileTap = onProfileTap
        self._engagement = ObservedObject(wrappedValue: engagement)
        self._openCommentsPostId = openCommentsPostId
        self._currentPostId = currentPostId
        self.heroMaxHeight = heroMaxHeight
        // v6 CENTERING FIX: scrollPositionを`.onAppear`内の事後代入ではなく
        // Stateの初期値として与える。v5で「事後代入だとinterior indexで
        // 中央からズレる」不具合を実機で確認したため、初期値経路に統一した。
        self._scrollPosition = State(initialValue: Self.computeInitialScrollId(posts: posts, laps: 21))
    }

    private var isCircular: Bool { posts.count >= 2 }

    private var cardWidth: CGFloat { measuredContainerWidth * cardWidthRatio }
    private var cardHeight: CGFloat { min(cardWidth / cardAspect, heroMaxHeight) }

    private var virtualItems: [PictriCarouselVirtualItem] {
        guard isCircular else {
            return posts.map { PictriCarouselVirtualItem(virtualId: $0.id, post: $0, virtualIndex: 0) }
        }
        let count = posts.count
        return (0..<(count * laps)).map { i in
            let post = posts[i % count]
            return PictriCarouselVirtualItem(virtualId: Self.virtualId(realId: post.id, virtualIndex: i), post: post, virtualIndex: i)
        }
    }

    private var middleLapStartIndex: Int { (laps / 2) * max(posts.count, 1) }

    private static func virtualId(realId: String, virtualIndex: Int) -> String {
        "\(realId)::\(virtualIndex)"
    }

    /// virtual idから元のvirtualIndexだけを取り出す(realIdに`::`が含まれない
    /// 前提。postIdはUUID文字列か`feed_`prefixの英数字なので安全)。
    private static func virtualIndex(from id: String) -> Int? {
        guard let range = id.range(of: "::", options: .backwards) else { return nil }
        return Int(id[range.upperBound...])
    }

    /// `-pictriHomeScrollTo <postId|mine>`をinit時点(初回描画より前)で解決し、
    /// 中央lap上の対応するvirtual idを返す。Circularでない(posts.count<2)場合は
    /// real idをそのまま返す。
    private static func computeInitialScrollId(posts: [QuestFeedPost], laps: Int) -> String? {
        guard !posts.isEmpty else { return nil }
        var debugTarget: String?
        #if DEBUG
        if let raw = PictriVisualReview.homeScrollToPostId {
            if raw == "mine" {
                debugTarget = posts.first(where: { $0.isMine })?.id
            } else if posts.contains(where: { $0.id == raw }) {
                debugTarget = raw
            }
        }
        #endif
        let targetRealId = debugTarget ?? posts[0].id
        guard posts.count >= 2, let realIndex = posts.firstIndex(where: { $0.id == targetRealId }) else {
            return targetRealId
        }
        let middleLapStart = (laps / 2) * posts.count
        let virtualIndex = middleLapStart + realIndex
        return virtualId(realId: targetRealId, virtualIndex: virtualIndex)
    }

    /// `-pictriHomeCommentsOpen <postId>` を、既存の並び替え(HomeView.visiblePosts)
    /// だけでなく実際のComment Note展開まで直接駆動する(DEBUG限定)。
    private var debugCommentsOpenPostId: String? {
        #if DEBUG
        return PictriVisualReview.homeCommentsOpenPostId
        #else
        return nil
        #endif
    }

    /// `-pictriHomeLikedPosts <id1,id2>` QAスクショ専用(DEBUG限定)。
    private var debugLikedPostIds: Set<String> {
        #if DEBUG
        return PictriVisualReview.homeLikedPostIds ?? []
        #else
        return []
        #endif
    }

    /// `-pictriHomeSimulateSwipe next|previous` QA専用(DEBUG限定)。実gestureが
    /// 行うのと同じ`scrollPosition`書き換え+wrap検知パイプラインを通す
    /// (production専用の別ロジックを新設しない、既存のstate machineをQAが
    /// そのまま踏む)。
    private var debugSimulateSwipeDirection: Int? {
        #if DEBUG
        switch PictriVisualReview.homeSimulateSwipe {
        case "next": return 1
        case "previous": return -1
        default: return nil
        }
        #else
        return nil
        #endif
    }

    var body: some View {
        GeometryReader { outer in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: cardSpacing) {
                    ForEach(virtualItems) { item in
                        cardSlot(item: item, containerWidth: outer.size.width)
                            .id(item.virtualId)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max((outer.size.width - cardWidth) / 2, 0))
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition, anchor: .center)
            // v8 REAL BUG FOUND & FIXED: `.defaultScrollAnchor(.center)`が
            // ここに残っていたことで、`scrollPosition`の初期値(haruka等)が
            // content配列全体の"幾何学的な中央"(virtual index的にほぼ真ん中)
            // に極めて近い場合、ScrollView自身の"defaultAnchor"側の初期位置
            // 決定ロジックと衝突し、明示的に指定したidより1つ隣(このケースでは
            // 次のreal post)へ実際にはcenterされてしまう実機bugを発見した。
            // (`-pictriHomeScrollTo feed_haruka_enoshima`を指定しても実際には
            // sotaが中央に表示される、という形で顕在化した)。
            // `scrollPosition(id:anchor:)`に既に明示的な初期値を渡している
            // 以上、`.defaultScrollAnchor`は本来不要な指定であり、削除することで
            // 解消した。v6で「State初期値経由にすれば直る」と判断していたのは
            // 半分だけ正しく、この`.defaultScrollAnchor`との衝突までは
            // 見つけられていなかった。
            .scrollDisabled(isCarouselLocked)
            .coordinateSpace(name: "pictriCarousel")
            .frame(height: cardHeight + overflowBuffer)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self, of: { _ in outer.size.width }) { newWidth in
                measuredContainerWidth = newWidth
            }
        }
        .frame(height: cardHeight + overflowBuffer)
        .onAppear {
            applyDebugSimulateSwipeIfNeeded()
            if openCommentsPostId == nil, let target = debugCommentsOpenPostId, posts.contains(where: { $0.id == target }) {
                openComments(for: target)
            }
            for postId in debugLikedPostIds where !engagement.isLiked(postId) {
                engagement.toggleLike(postId)
            }
            syncCurrentPostId(from: scrollPosition)
        }
        .onChange(of: openCommentsPostId) { _, newValue in
            isCarouselLocked = newValue != nil
        }
        // v7 PAGINATION DOTS用の一方向sync-out。scrollPositionが変わるたび、
        // 対応するREAL post idだけをHomeViewへ押し出す(HomeView側からの
        // 書き戻しは一切無い一方向binding)。
        .onChange(of: scrollPosition) { _, newValue in
            syncCurrentPostId(from: newValue)
        }
        // v6 WRAP RE-CENTERING: 実gestureでもDEBUG simulateでも、scrollPositionが
        // 変わるたびにここを通る(section 8「同じstate machineを通す」を満たす)。
        // 現在位置のlapが端から3lap以内に近づいたら、**同じ投稿の中央lap上の
        // コピー**へ無アニメーションで戻す。見た目のcontent(post)は完全に
        // 同一のため、この瞬間移動はピクセル上は何も変化せずuser knowledge上
        // 検知不能(jump/flash/duplicate flickerを起こさない設計)。
        .onChange(of: scrollPosition) { _, newValue in
            guard isCircular, let newValue, let vIndex = Self.virtualIndex(from: newValue) else { return }
            let count = posts.count
            let lapIndex = vIndex / count
            let safeMargin = 3
            guard lapIndex < safeMargin || lapIndex >= laps - safeMargin else { return }
            let realIndexInLap = vIndex % count
            let targetVirtualIndex = middleLapStartIndex + realIndexInLap
            let targetId = Self.virtualId(realId: posts[realIndexInLap].id, virtualIndex: targetVirtualIndex)
            guard targetId != newValue else { return }
            scrollPosition = targetId
        }
        // DEBUG seed(`-pictriSeedDualMemory`等)はContentView.onAppear側の非同期な
        // 副作用のため、Carousel自身のinit/onAppearより後にposts自体が増える
        // ことがある。この場合2つの経路で再解決が必要:
        // 1) `-pictriHomeScrollTo`のDEBUG指定先が、初回init時点ではまだ存在せず
        //    (例: "mine"がseed完了前)、posts変化後に初めて解決できるようになった
        //    場合 → その指定先へ強制的に飛ぶ(v5で確立済みの挙動を踏襲)。
        // 2) DEBUG指定が無い/既に解決済みだが、現在位置のvirtual indexが新しい
        //    posts.countに対して無効化された場合 → 中央lapの対応位置へ再解決。
        // 通常操作(DEBUG指定なし、posts.countも変わらない)ではscrollPositionを
        // 一切上書きしない。
        .onChange(of: posts.map(\.id)) { _, newIds in
            guard !newIds.isEmpty else { return }
            if let forcedTarget = debugForcedRetargetId(newIds: newIds) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollPosition = forcedTarget
                }
                return
            }
            guard !isScrollPositionStillValid(newIdsCount: newIds.count) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                scrollPosition = Self.computeInitialScrollId(posts: posts, laps: laps)
            }
        }
    }

    /// DEBUG `-pictriHomeScrollTo`の指定先が、posts変化後に初めて実在するように
    /// なった(かつ現在の中央がまだそこを指していない)場合だけ、その位置への
    /// virtual idを返す。DEBUG指定が無い/Releaseでは常にnil。
    private func debugForcedRetargetId(newIds: [String]) -> String? {
        #if DEBUG
        guard let raw = PictriVisualReview.homeScrollToPostId else { return nil }
        let resolvedRealId: String? = raw == "mine" ? posts.first(where: { $0.isMine })?.id : (newIds.contains(raw) ? raw : nil)
        guard let targetRealId = resolvedRealId, let realIndex = posts.firstIndex(where: { $0.id == targetRealId }) else { return nil }
        if let current = scrollPosition, let vIndex = Self.virtualIndex(from: current), posts[vIndex % max(posts.count, 1)].id == targetRealId {
            return nil
        }
        guard posts.count >= 2 else { return targetRealId }
        return Self.virtualId(realId: targetRealId, virtualIndex: middleLapStartIndex + realIndex)
        #else
        return nil
        #endif
    }

    private func syncCurrentPostId(from scrollId: String?) {
        guard let scrollId, !posts.isEmpty else { return }
        guard let vIndex = Self.virtualIndex(from: scrollId) else {
            if currentPostId != scrollId { currentPostId = scrollId }
            return
        }
        let realId = posts[vIndex % posts.count].id
        if currentPostId != realId { currentPostId = realId }
    }

    private func isScrollPositionStillValid(newIdsCount: Int) -> Bool {
        guard let current = scrollPosition, let vIndex = Self.virtualIndex(from: current) else { return false }
        guard isCircular, posts.count > 0 else { return false }
        let realIndex = vIndex % posts.count
        return realIndex < newIdsCount
    }

    #if DEBUG
    private func applyDebugSimulateSwipeIfNeeded() {
        guard let direction = debugSimulateSwipeDirection,
              let current = scrollPosition,
              let vIndex = Self.virtualIndex(from: current),
              !posts.isEmpty else { return }
        let newVIndex = vIndex + direction
        guard newVIndex >= 0 else { return }
        let realIndex = ((newVIndex % posts.count) + posts.count) % posts.count
        scrollPosition = Self.virtualId(realId: posts[realIndex].id, virtualIndex: newVIndex)
    }
    #else
    private func applyDebugSimulateSwipeIfNeeded() {}
    #endif

    @ViewBuilder
    private func cardSlot(item: PictriCarouselVirtualItem, containerWidth: CGFloat) -> some View {
        let post = item.post
        PictriHomeMemoryCard(
            post: post,
            isLiked: engagement.isLiked(post.id),
            likeCount: engagement.likeCount(for: post),
            commentCount: engagement.comments(for: post).count,
            isCommentNoteOpen: openCommentsPostId == post.id,
            onProfileTap: { onProfileTap(post) },
            onLike: { engagement.toggleLike(post.id) },
            onOpenComments: { openComments(for: post.id) }
        )
        .frame(width: cardWidth, height: cardHeight)
        .modifier(
            PictriHomeCarouselCardEffect(
                containerWidth: containerWidth,
                cardWidth: cardWidth,
                cardSpacing: cardSpacing,
                reduceMotion: reduceMotion
            )
        )
        // ViewModifier内部でGeometryReaderをcontentの外側に被せているため、
        // 明示的なframeを与えないとLazyHStack側へ提案するサイズが不定になり
        // (GeometryReaderは常に「親が提案したサイズ」を素直に埋めるだけで、
        // contentの本来のサイズを再現しない)、実機で中央cardが画面左端へ
        // 寄って表示される不具合が発生した。ここでcardWidth/cardHeightを
        // 再度明示することで、LazyHStack側から見た確定サイズを保証する。
        .frame(width: cardWidth, height: cardHeight)
    }

    private func openComments(for postId: String) {
        isCarouselLocked = true
        openCommentsPostId = postId
    }
}

/// 中央からの距離(カード単位)に応じてscale/opacity/rotation3Dを連続的に
/// 変化させる。GeometryReaderで各cardの`pictriCarousel`座標系上の位置を
/// 毎フレーム読み取り、突然のstate切り替えではなく指の位置に連動した
/// なめらかな変化にする(Cover Flowの模倣ではなく、写真が空間に浮いている
/// 程度のmoderate depthに留める)。
///
/// v8 REFERENCE FIDELITY SIDE DEPTH: 3候補を17 Pro Dark実写真で比較。
/// A) CURRENT(旧v7): rotation18°/pull30pt/scale-0.15/opacity-0.36。
///    遮蔽が強すぎ、side cardがavatarの端しか見えず「記憶の壁」ではなく
///    「気配」止まりだった。
/// B) REFERENCE MATCH(採用): rotation22°/pull20pt/scale-0.12/opacity-0.28。
///    pullを弱めて自然な視認幅を増やし、opacity/scaleの減衰も緩めることで
///    side cardのavatar・写真色が明確に見えるようになった。中央Heroは
///    bezel/サイズで既に十分主役なので、side側の情報量を増やしても
///    Hero dominanceは損なわれなかった。
/// C) REFERENCE -15%は、Bと数値が近すぎ実写真上の差がほぼ無かったため
///    個別実装はせず、Bをそのまま採用と判断した。
private struct PictriHomeCarouselCardEffect: ViewModifier {
    let containerWidth: CGFloat
    let cardWidth: CGFloat
    let cardSpacing: CGFloat
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("pictriCarousel"))
            let midX = frame.midX
            let containerMid = containerWidth / 2
            let step = max(cardWidth + cardSpacing, 1)
            let rawDistance = (midX - containerMid) / step
            let distance = min(max(rawDistance, -1.35), 1.35)
            let magnitude = min(abs(distance), 1.0)
            let occlusionPull: CGFloat = 20

            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(1.0 - magnitude * 0.12)
                .opacity(1.0 - magnitude * 0.28)
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : Double(distance) * 22),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    perspective: 0.46
                )
                .offset(x: -CGFloat(distance) * occlusionPull)
                .zIndex(1 - Double(magnitude))
        }
    }
}
