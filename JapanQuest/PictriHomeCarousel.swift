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
// v16 STRUCTURAL REPLACEMENT: v15までは`ScrollView` + `LazyHStack` +
// `.scrollTargetBehavior(.viewAligned)` + `.scrollPosition(id:anchor:)`で
// Circular Carouselを実現していたが、実機/Simulator計測により
// 「`onScrollGeometryChange`のvisibleRect.midXが、ScrollViewが実際に
// 中央表示しているvirtualIndexと一致しない」という、contentOffset/
// contentInsets起因の構造的な不一致が判明した(詳細は
// `PictriCarouselRenderState.swift`冒頭コメント、および完了報告参照)。
// 今回`ScrollView`を完全に廃止し、`centerVirtualIndex`(Int)と
// `dragTranslation`(CGFloat、`DragGesture`由来)だけを状態源とする
// 決定論的な`ZStack` + `.position(x:y:)`方式へ置き換えた
// (`PictriCircularCarouselEngine`/`PictriHomeCarouselLayoutMetrics.
// renderState`参照)。

// MARK: - Engagement Store(Home専用、local-only)
//
// 既存のlikedPostIds(HomeView@State)/comments(HomeFeedPostRow@State)は
// どちらもview再生成で消える設計だった。新しいHorizontal Carouselは
// 表示中のcardが画面外へ出ると再生成されうるため、投稿ID keyedの
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

/// SwiftUIのForEach用identityと実データ(`post.id`)を分離するためのラッパー。
/// `virtualId`だけがView identityとして使われ、Like/Comment/画像解決は
/// 常に`post`(実データ)経由で行う。
private struct PictriCarouselVirtualItem: Identifiable {
    let virtualId: String
    let post: QuestFeedPost
    let virtualIndex: Int
    var id: String { virtualId }
}

// MARK: - Carousel

/// Horizontal 3D Memory Feed。中央Cardが最前面・最大、左右Cardが奥へ
/// 傾いてpeekする。`ZStack` + `DragGesture`による決定論的配置
/// (`centerVirtualIndex`と`dragTranslation`だけがx位置・scale・rotation・
/// zIndexの唯一の入力 — `PictriCircularCarouselEngine`参照)。
/// posts.count >= 2の場合はCircular(wrap-around)になる。
struct PictriHomeCarousel: View {
    let posts: [QuestFeedPost]
    let onProfileTap: (QuestFeedPost) -> Void
    @ObservedObject var engagement: PictriHomeEngagementStore
    @Binding var openCommentsPostId: String?
    /// v7 PAGINATION DOTS用。Carousel→HomeViewへの一方向syncのみ(HomeView側は
    /// 一切書き戻さない)。
    @Binding var currentPostId: String?
    /// v8 HERO HEIGHT CAP: HomeViewが実測したscreen高さから導いた上限。
    let heroMaxHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// `-pictriReduceMotionOverride true` QAスクショ専用(DEBUG限定)。実機の
    /// Reduce Motion設定を変更せずに、この値だけを差し替えて両状態を
    /// 検証できるようにする(本番挙動には一切影響しない)。
    private var reduceMotion: Bool {
        #if DEBUG
        if PictriVisualReview.reduceMotionDebugOverride == true { return true }
        if PictriVisualReview.reduceMotionDebugOverride == false { return false }
        #endif
        return systemReduceMotion
    }
    @State private var isCarouselLocked = false
    /// v16: 唯一の位置状態。「今どのvirtual itemが中央として確定しているか」。
    /// dragが完了(snap)した瞬間だけ変化する。
    @State private var centerVirtualIndex: Int = 0
    /// v16: `DragGesture.translation.width`由来の値。指を離した後は
    /// snapアニメーションがこの値をitemStepの整数倍へ動かし、完了後
    /// `centerVirtualIndex`を進めて0へ戻す(4-step seamless update、
    /// `finalizeSnap(delta:)`参照)。
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    /// 外側のframe高さ計算専用(GeometryReaderの初回測定を1フレーム待つ
    /// 必要があるための鏡)。カードの位置・scale・rotation・zIndexは
    /// この値を経由せず、常にGeometryReaderの`outer.size.width`を直接
    /// 使う(ここが1フレーム遅れても前後関係バグには繋がらない、
    /// 純粋にレイアウトサイズの話に限定されている)。
    @State private var measuredContainerWidth: CGFloat = 0

    /// v8: heroMaxHeight導入でSE等の高さ上限がaspect比由来の値と異なる値に
    /// なったことで、Like/Comment countのはみ出し分を隠すバッファがSEで
    /// 実機clippingするのを確認したため32→48へ拡大した。
    private let overflowBuffer: CGFloat = 72
    /// Circular用のlap数(奇数)。中央lapから出発し、両側に(laps-1)/2 lap分の
    /// バッファを持つ。通常の利用でここまで連続Swipeすることは実質無いため、
    /// 「実質無限」として振る舞う。
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
        let initialRealIndex = Self.resolveInitialRealIndex(posts: posts)
        self._centerVirtualIndex = State(
            initialValue: Self.resolvedCenterVirtualIndex(sourceCount: posts.count, laps: 21, realIndex: initialRealIndex)
        )
    }

    private var isCircular: Bool { posts.count >= 2 }

    /// v1.5 1-POST BUG FIX: `renderedItems()`はCircularでない場合(`posts.count < 2`)、
    /// laps由来の仮想indexではなく`posts.enumerated()`(常に0始まりの実index)を
    /// そのまま使う。centerVirtualIndexだけが常にCircular前提のlaps公式
    /// (`(laps/2)*sourceCount + realIndex`)で計算されていたため、
    /// 投稿が1件のとき(`sourceCount == 1`)centerVirtualIndexが10、実際に
    /// 描画されるvirtualIndexが0のまま一致せず、CardのrelativePositionが
    /// -10相当になり画面外へ飛んで「Recentが空白に見える」原因になっていた
    /// (posts.count == 0の場合はHomeView側でCarousel自体を生成しないため、
    /// ここには到達しない)。Circular(`sourceCount >= 2`)の場合は既存の
    /// laps公式を維持し、挙動を一切変えない。
    private static func resolvedCenterVirtualIndex(sourceCount: Int, laps: Int, realIndex: Int) -> Int {
        guard sourceCount >= 2 else { return realIndex }
        return PictriCircularCarouselEngine.initialCenterVirtualIndex(sourceCount: sourceCount, laps: laps, targetRealIndex: realIndex)
    }

    private var metrics: PictriHomeCarouselLayoutMetrics {
        PictriHomeCarouselLayoutMetrics(viewportWidth: measuredContainerWidth, heroMaxHeight: heroMaxHeight)
    }

    private static func virtualId(realId: String, virtualIndex: Int) -> String {
        "\(realId)::\(virtualIndex)"
    }

    /// `-pictriHomeScrollTo <postId|mine>`をinit時点で解決し、対応する
    /// 実データindexを返す(Circularでない場合も含め、常にposts配列上のindex)。
    private static func resolveInitialRealIndex(posts: [QuestFeedPost]) -> Int {
        guard !posts.isEmpty else { return 0 }
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
        return posts.firstIndex(where: { $0.id == targetRealId }) ?? 0
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
    /// 通るのと全く同じ`endDrag`→`finalizeSnap`の経路を、翻訳済みのtranslation
    /// 値で駆動する(production専用の別ロジックを新設しない)。
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
            let liveMetrics = PictriHomeCarouselLayoutMetrics(viewportWidth: outer.size.width, heroMaxHeight: heroMaxHeight)
            let containerHeight = liveMetrics.cardHeight + overflowBuffer

            ZStack {
                ForEach(renderedItems(metrics: liveMetrics)) { item in
                    let renderState = liveMetrics.renderState(
                        virtualIndex: item.virtualIndex,
                        centerVirtualIndex: centerVirtualIndex,
                        dragTranslation: dragTranslation,
                        reduceMotion: reduceMotion
                    )
                    cardView(item: item, renderState: renderState, metrics: liveMetrics)
                        .position(x: renderState.cardCenterX, y: containerHeight / 2)
                        .zIndex(renderState.zIndex)
                        .animation(nil, value: renderState.zIndex)
                }
            }
            .frame(width: outer.size.width, height: containerHeight)
            .contentShape(Rectangle())
            .gesture(dragGesture(metrics: liveMetrics))
            .onGeometryChange(for: CGFloat.self, of: { _ in outer.size.width }) { newWidth in
                measuredContainerWidth = newWidth
            }
        }
        .frame(height: metrics.cardHeight + overflowBuffer)
        .onAppear {
            applyDebugFreezeDragFractionIfNeeded()
            applyDebugSimulateSwipeIfNeeded()
            if openCommentsPostId == nil, let target = debugCommentsOpenPostId, posts.contains(where: { $0.id == target }) {
                openComments(for: target)
            }
            for postId in debugLikedPostIds where !engagement.isLiked(postId) {
                engagement.toggleLike(postId)
            }
            syncCurrentPostId()
        }
        .onChange(of: openCommentsPostId) { _, newValue in
            isCarouselLocked = newValue != nil
        }
        // DEBUG seed(`-pictriSeedDualMemory`等)はContentView.onAppear側の非同期な
        // 副作用のため、Carousel自身のinit/onAppearより後にposts自体が増える
        // ことがある。
        .onChange(of: posts.map(\.id)) { _, newIds in
            guard !newIds.isEmpty else { return }
            if let forcedTarget = debugForcedRetargetIndex(newIds: newIds) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    var txn = Transaction()
                    txn.disablesAnimations = true
                    withTransaction(txn) {
                        centerVirtualIndex = forcedTarget
                        dragTranslation = 0
                    }
                    syncCurrentPostId()
                }
                return
            }
            guard !isCenterStillValid(newIdsCount: newIds.count) else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let realIndex = Self.resolveInitialRealIndex(posts: posts)
                var txn = Transaction()
                txn.disablesAnimations = true
                withTransaction(txn) {
                    centerVirtualIndex = Self.resolvedCenterVirtualIndex(sourceCount: posts.count, laps: laps, realIndex: realIndex)
                    dragTranslation = 0
                }
                syncCurrentPostId()
            }
        }
    }

    // MARK: - Rendered window

    private func renderedItems(metrics: PictriHomeCarouselLayoutMetrics) -> [PictriCarouselVirtualItem] {
        guard !posts.isEmpty else { return [] }
        if isCircular {
            let range = PictriCircularCarouselEngine.visibleVirtualIndexRange(centerVirtualIndex: centerVirtualIndex)
            return range.map { vIndex in
                let realIndex = PictriCircularCarouselEngine.realIndex(virtualIndex: vIndex, sourceCount: posts.count)
                let post = posts[realIndex]
                return PictriCarouselVirtualItem(virtualId: Self.virtualId(realId: post.id, virtualIndex: vIndex), post: post, virtualIndex: vIndex)
            }
        } else {
            return posts.enumerated().map { index, post in
                PictriCarouselVirtualItem(virtualId: post.id, post: post, virtualIndex: index)
            }
        }
    }

    // MARK: - Drag / snap

    private func dragGesture(metrics: PictriHomeCarouselLayoutMetrics) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard isCircular, !isCarouselLocked else { return }
                isDragging = true
                let limit = metrics.itemStep * (CGFloat(PictriCircularCarouselEngine.visibleIndexRadius) - 0.5)
                dragTranslation = Self.rubberBanded(value.translation.width, limit: limit)
            }
            .onEnded { value in
                guard isCircular, !isCarouselLocked else { return }
                endDrag(translation: value.translation.width, predicted: value.predictedEndTranslation.width, metrics: metrics)
            }
    }

    /// limitを超えた分は逓減させる(画面外へ無制限に引っ張れないようにする)。
    private static func rubberBanded(_ raw: CGFloat, limit: CGFloat) -> CGFloat {
        guard limit > 0, raw.isFinite else { return 0 }
        guard abs(raw) > limit else { return raw }
        let overflow = abs(raw) - limit
        let damped = limit + overflow / (1 + overflow / limit)
        return raw < 0 ? -damped : damped
    }

    private func endDrag(translation: CGFloat, predicted: CGFloat, metrics: PictriHomeCarouselLayoutMetrics) {
        isDragging = false
        let delta = PictriCircularCarouselEngine.pageDelta(translation: translation, predictedTranslation: predicted, itemStep: metrics.itemStep)
        animateSnap(delta: delta, itemStep: metrics.itemStep)
    }

    /// 4-step seamless update:
    /// 1. dragTranslationをdelta * -itemStepまでanimation
    /// 2. animation完了時にcenterVirtualIndex += delta
    /// 3. animationを無効化してdragTranslation = 0
    /// 4. 見た目の位置は変えない(relativePositionが同じ値になるため)
    private func animateSnap(delta: Int, itemStep: CGFloat) {
        let target = CGFloat(delta) * -itemStep
        withAnimation(.interactiveSpring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.15)) {
            dragTranslation = target
        } completion: {
            centerVirtualIndex += delta
            var txn = Transaction()
            txn.disablesAnimations = true
            withTransaction(txn) {
                dragTranslation = 0
            }
            recenterIfNeeded()
            syncCurrentPostId()
        }
    }

    /// centerVirtualIndexが端のlapへ近づいたら、同じ投稿を指す中央lap上の
    /// indexへ無アニメーションで移す。snap完了後(drag中でもsnap animation中
    /// でもない)にだけ呼ばれる。
    private func recenterIfNeeded() {
        guard isCircular else { return }
        guard let target = PictriCircularCarouselEngine.recenteredVirtualIndex(centerVirtualIndex: centerVirtualIndex, sourceCount: posts.count, laps: laps) else { return }
        var txn = Transaction()
        txn.disablesAnimations = true
        withTransaction(txn) {
            centerVirtualIndex = target
        }
    }

    private func syncCurrentPostId() {
        guard !posts.isEmpty else { return }
        let realIndex = PictriCircularCarouselEngine.realIndex(virtualIndex: centerVirtualIndex, sourceCount: posts.count)
        let realId = posts[realIndex].id
        if currentPostId != realId { currentPostId = realId }
    }

    /// DEBUG `-pictriHomeScrollTo`の指定先が、posts変化後に初めて実在するように
    /// なった(かつ現在の中央がまだそこを指していない)場合だけ、その位置への
    /// virtualIndexを返す。DEBUG指定が無い/Releaseでは常にnil。
    private func debugForcedRetargetIndex(newIds: [String]) -> Int? {
        #if DEBUG
        guard let raw = PictriVisualReview.homeScrollToPostId else { return nil }
        let resolvedRealId: String? = raw == "mine" ? posts.first(where: { $0.isMine })?.id : (newIds.contains(raw) ? raw : nil)
        guard let targetRealId = resolvedRealId, let realIndex = posts.firstIndex(where: { $0.id == targetRealId }) else { return nil }
        if !posts.isEmpty {
            let currentRealIndex = PictriCircularCarouselEngine.realIndex(virtualIndex: centerVirtualIndex, sourceCount: posts.count)
            if posts[currentRealIndex].id == targetRealId { return nil }
        }
        return Self.resolvedCenterVirtualIndex(sourceCount: posts.count, laps: laps, realIndex: realIndex)
        #else
        return nil
        #endif
    }

    private func isCenterStillValid(newIdsCount: Int) -> Bool {
        guard isCircular, posts.count > 0 else { return false }
        let realIndex = PictriCircularCarouselEngine.realIndex(virtualIndex: centerVirtualIndex, sourceCount: posts.count)
        return realIndex < newIdsCount
    }

    #if DEBUG
    private func applyDebugSimulateSwipeIfNeeded() {
        guard let direction = debugSimulateSwipeDirection, isCircular else { return }
        let step = metrics.itemStep > 1 ? metrics.itemStep : 320
        animateSnap(delta: direction, itemStep: step)
    }
    #else
    private func applyDebugSimulateSwipeIfNeeded() {}
    #endif

    #if DEBUG
    /// `-pictriHomeCarouselDragFraction <value>` QA専用: 実gestureを介さず、
    /// dragTranslationをitemStepの`<value>`倍(アニメーションなし)へ直接
    /// 設定する。Phase 10/11の「drag中間状態を画面上で確認する」ための
    /// スクリーンショット検証専用フックで、本番挙動には一切影響しない。
    private func applyDebugFreezeDragFractionIfNeeded() {
        guard let raw = PictriVisualReview.homeCarouselDebugDragFraction, let fraction = Double(raw), isCircular else { return }
        let step = metrics.itemStep > 1 ? metrics.itemStep : 320
        var txn = Transaction()
        txn.disablesAnimations = true
        withTransaction(txn) {
            dragTranslation = CGFloat(fraction) * step
        }
    }
    #else
    private func applyDebugFreezeDragFractionIfNeeded() {}
    #endif

    // MARK: - Card

    @ViewBuilder
    private func cardView(item: PictriCarouselVirtualItem, renderState: PictriCarouselRenderState, metrics: PictriHomeCarouselLayoutMetrics) -> some View {
        let post = item.post
        // v16: Card Shell(写真+bezel+identity+Social Capsule+Flip)には一切
        // 手を加えず、完成したCard全体へ1つの `scale` / `rotation3DEffect` /
        // `position` / `zIndex` を適用する(画像だけの回転、borderだけの
        // 別zIndex、mask、.clipped()は使わない — Phase 8要件)。
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
        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
        // v3 SIDE CARD DEPTH: 既存のzIndex/scale/opacity/rotationロジックには
        // 触れず、「Heroから離れるほどわずかに暗くなる」という深度手がかりを
        // 1層だけ追加する。absoluteDistance(0=Hero, 1=Side)に線形比例させ、
        // 上限0.16(Sideでも「半透明カード」に見えない範囲)に留める。
        // Card自体(写真+bezel)は`PictriHomeMemoryCard`のまま一切変更しない。
        .overlay {
            RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous)
                .fill(Color.black.opacity(min(Double(renderState.absoluteDistance), 1.0) * 0.16))
                .allowsHitTesting(false)
        }
        .scaleEffect(renderState.scale, anchor: renderState.rotationAnchor)
        .opacity(renderState.opacity)
        .rotation3DEffect(
            .degrees(renderState.rotationDegrees),
            axis: (x: 0, y: 1, z: 0),
            anchor: renderState.rotationAnchor,
            perspective: PictriHomeCarouselLayoutMetrics.perspective
        )
    }

    private func openComments(for postId: String) {
        isCarouselLocked = true
        openCommentsPostId = postId
    }
}
