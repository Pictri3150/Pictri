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
/// v10 NEW REFERENCE MIGRATION: Homeは「旅の地図」(訪問済み県の一覧)と
/// 「最近の記録」(既存Horizontal Carousel)の2状態を持つ。背景/上部PicTri/
/// 右上Notification・Account/Bottom Dockは共通のまま、中央コンテンツだけが
/// この値で切り替わる。
enum PictriHomeMode: Equatable {
    case map
    case recent
}

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
    /// v10: 新Reference 2枚(「旅の地図」/「最近の記録」)に対応する2状態。
    /// Reference 1が「旅の地図」であることと、CLAUDE.mdのコアフロー
    /// (「地図でスポット発見→...」)がMap起点であることに合わせ、既定値は`.map`。
    /// DEBUGでは`-pictriHomeMode map|recent`で起動時の状態を直接指定できる。
    ///
    /// v5 TRUE VERTICAL PAGING: 旧v10〜v4は「homeModeがUIを交換する」構造
    /// (`switch`+`.transition`+手動DragGesture)だった。今回は逆に、
    /// `ScrollView(.vertical)` + `.scrollTargetBehavior(.paging)` +
    /// `.scrollPosition(id:)`を単一のSource of Truthとし、`homeMode`は
    /// 「今scroll positionがどのpageにあるか」から**導出するだけ**の
    /// 読み取り専用値にする(`scrolledMode`が正、`homeMode`はその反映)。
    @State private var scrolledMode: PictriHomeMode? = Self.resolveInitialHomeMode()

    /// 他のコードから見た「現在のmode」。`scrolledMode`(scroll由来)が
    /// nilになる一瞬(初期化直後等)だけ`.map`にフォールバックする。
    private var homeMode: PictriHomeMode { scrolledMode ?? .map }

    private static func resolveInitialHomeMode() -> PictriHomeMode {
        #if DEBUG
        return PictriVisualReview.homeModeOverride ?? .map
        #else
        return .map
        #endif
    }
    /// v7 PAGINATION DOTS用。Carousel側から現在中央のREAL post id(virtual idではない)
    /// だけを一方向で受け取る(HomeViewからCarouselのscrollPositionへ書き戻すことは
    /// 一切しない — v5で「双方向bindingにするとcenter anchorが壊れる」ことが判明済み
    /// のため、常にCarousel→HomeViewの一方向syncに限定する)。
    @State private var currentPostId: String?
    #if DEBUG
    @State private var didOpenDebugAccountSheet = false
    #endif

    /// v8.1 HERO VERTICAL COMPOSITION FINAL MICRO ADJUSTMENT: Reference実測
    /// (tagline下端→Hero上端 = 画面高さの4.7%)に対し、v8時点のCurrentは19.6%
    /// と約4倍の空白があった(実測は`/tmp/pictri_home_v81/BASELINE_GEOMETRY.md`
    /// / `REFERENCE_GEOMETRY.md`参照)。
    /// 3候補を17 Pro Dark実写真で比較した:
    /// A) CURRENT 0.196(旧来のgreedy Spacer) — header直下に「まだ何か入る
    ///    はずの空間」が残ったままだった。
    /// B) BALANCED LIFT 0.107(約60%短縮) — 明確に改善したが、Referenceと
    ///    並べるとまだHero開始が遅く感じた。
    /// C) REFERENCE FIDELITY 0.047(採用) — Referenceの実測値そのもの。17 Pro
    ///    Darkで実写真確認した結果、Dynamic Island/status bar/taglineとの衝突
    ///    無く、Heroが画面上部へ十分近づき「密度」がReferenceに最も近づいた
    ///    ため、Cを採用した(「攻めすぎ」と事前判断せず実画面で比較した結果)。
    ///
    /// この変更でHero-Dock間に生まれた余剰スペースは、Pagination直後の
    /// Spacer(後述)が引き受ける。Pagination自体の位置は「Heroへ密着
    /// (候補A)」/「Hero-Dock間の余白の視覚的中心へ再配置(候補B)」を比較し、
    /// BはHero-Pagination間にもReference実測(0.0425、密着に近い)より大きな
    /// 空白を作ってしまい「Heroから浮いた別要素」に見えたため、Aを採用した。
    ///
    /// v9 Phase 2: 新しいReference `pictriimagehome.png`実測でHero top比率は
    /// 0.168(旧referenceの0.211とは別画像・別数値)。Current実測は0.220
    /// だったため、fresh screenshotで実測した比例関係
    /// (0.047 → 実測比率0.220、目標0.168への削減率0.460)から逆算し、
    /// 0.047 * 0.460 ≈ 0.0216を暫定値として採用。Hero幅/aspect変更と併せて
    /// 再度fresh screenshotで実測・微調整する。
    private static let heroTopGapRatio: CGFloat = 0.013

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

                    // v9 Phase 2の`heroTopGapRatio`は元はheader→Hero写真間専用
                    // だったが、v10では「header→タイトルブロック」間の gap として
                    // そのまま転用する(両Reference共に header と タイトルの間隔は
                    // 密なまま、という点は変わっていないため)。
                    Color.clear.frame(height: screen.size.height * Self.heroTopGapRatio)

                    // v5: dotsはScrollView(下記)の外側・兄弟要素として置くことで、
                    // 「pageは動くがdotsは動かない」を特別なoverlay座標計算なしで
                    // 実現する(ScrollViewの外にあるため、内部スクロールの影響を
                    // 受けようがない)。
                    modeIndicatorOverlay
                        .padding(.bottom, 6)
                        .zIndex(2)

                    // v5 TRUE VERTICAL PAGING: 旧`Group{switch}+.transition+
                    // 手動DragGesture`を廃止し、`ScrollView(.vertical)` +
                    // `.scrollTargetBehavior(.paging)` + `.scrollPosition(id:)`
                    // による本物の縦ページングへ置き換えた。Map page/Recent page
                    // それぞれが画面のcontent領域とちょうど同じ高さ(`pageArea.
                    // size.height`)を持つ2枚の全画面pageとして並び、`.paging`が
                    // 「指の動きにそのまま追従し、離すと必ずどちらかのpage境界へ
                    // snapする」ネイティブな挙動を保証する(手動しきい値判定は
                    // 不要になった)。
                    //
                    // Horizontal Carousel(Recent page内、`PictriHomeCarousel`)との
                    // 競合対策: このScrollViewは`.vertical`軸のみを宣言しているため、
                    // 横方向のpan成分はこのScrollView自身のスクロールには一切
                    // 寄与しない(UIScrollViewの軸ロック)。Carousel側の独立した
                    // 横DragGesture(`.gesture`、minimumDistance 8)は今まで通り
                    // 単独で横方向のtranslationを受け取り続けるため、Carouselの
                    // circular/snap/zIndexロジックには一切触れていない。
                    GeometryReader { pageArea in
                        // v5 BUGFIX: heroMaxHeight/maxMapHeightの上限比率は元々
                        // `screen.size.height`(header/dots/dock分を差し引く前の
                        // フル高さ)基準だった。Page化により各pageの実際に使える
                        // 高さは`pageArea.size.height`(header/gap/dots/dock分を
                        // 既に差し引いた後の値、screen.size.heightより小さい)に
                        // なったため、旧基準のままだとRecent pageでHero+title+
                        // paginationの合計高さがpageArea.size.heightを超え、
                        // paginationがpage下端の外へclipされて見えなくなる実機
                        // バグがあった(v5実装直後のscreenshotで発見・修正)。
                        // 上限比率の算出元を`pageArea.size.height`へ揃えることで
                        // 必ずpage内に収まるようにする。
                        let heroCap = pageArea.size.height * (pageArea.size.height > 560 ? 0.72 : 0.50)
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                mapPage(
                                    containerWidth: screen.size.width,
                                    maxMapHeight: heroCap
                                )
                                .frame(width: pageArea.size.width, height: pageArea.size.height, alignment: .top)
                                .id(PictriHomeMode.map)

                                recentPage(heroMaxHeight: heroCap)
                                .frame(width: pageArea.size.width, height: pageArea.size.height, alignment: .top)
                                .id(PictriHomeMode.recent)
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $scrolledMode, anchor: .top)
                        // Comment Note展開中はpage自体を動かさない(scrim操作と競合させない)。
                        .scrollDisabled(openCommentsPostId != nil)
                        .scrollClipDisabled(false)
                    }
                }
                // v17 FLOATING CAPSULE BAR: 旧v7〜v16は`PictriHomeControlDock`を
                // このVStack自身の末尾要素として配置していたため、Dockの
                // 上端カーブと下端がVStackの自然な下端(=Safe Area上端)に
                // 直結し、「画面下端に固定されたDock」に見えていた。v17では
                // バー本体をこのVStackから完全に分離し、下のZStack階層へ
                // 独立したoverlayとして重ねる。メインコンテンツ側は、バーが
                // 占有する高さ(バー本体+浮遊させるための下余白+中央ボタンの
                // 突出量)ぶんだけ`.padding(.bottom)`で確保し、offsetだけで
                // 見た目を合わせる実装(=レイアウト上の占有領域を無視する
                // 実装)にはしない。
                .padding(.bottom, PictriHomeFloatingBarMetrics.reservedContentHeight(containerWidth: screen.size.width))

                // v17 FLOATING CAPSULE BAR本体。メインコンテンツのVStackとは
                // 独立したZStackレイヤーとして、画面下端(=このGeometryReaderの
                // `screen.size`はSafe Area減算後のため、ここでの下端は
                // 「bottom Safe Areaの上端」と一致する)へ`.bottom`寄せで重ねる。
                // `.padding(.bottom, bottomGap)`が、その安全領域上端から
                // さらに浮かせるための黒い隙間になる(offsetではなくpadding
                // なので、この隙間ぶんバーの表示位置そのものが動く)。
                PictriHomeControlDock(
                    containerWidth: screen.size.width,
                    onMapTap: { selectedTab = .map },
                    onCameraTap: { selectedTab = .camera },
                    onAlbumTap: { selectedTab = .memories }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, PictriHomeFloatingBarMetrics.bottomGap)

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
    /// v9 BRAND CENTERING: サブタイトル「あなたの旅の記録」を削除し、PicTriを
    /// 画面の水平中央へ独立配置する。単純なHStack中央寄せだと右上pillの
    /// 幅ぶんだけ視覚的に左へ偏るため、ZStackで「右上pill(HStack)」と
    /// 「PicTri(画面幅いっぱいの.frame(maxWidth:.infinity)で中央固定)」を
    /// 別レイヤーとして重ね、pillの存在に一切影響されない中央配置にする。
    private var header: some View {
        ZStack {
            Text("PicTri")
                .font(PictriTypography.display(24))
                .tracking(2.2)
                // v8.2: wordmarkの暖色gradient終点を、新AppIconのbrand
                // accent(muted lavender)へ置き換えた。ink→lavenderという
                // 既存の2-stop構造・opacityはそのまま維持し、「巨大purple
                // logo」にならないごく控えめな変更に留めている。
                .foregroundStyle(
                    LinearGradient(
                        colors: [PictriFinalTheme.ink, PictriHomeBrandAccent.accent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .center, spacing: 10) {
                Spacer(minLength: 0)

                Button(action: onAccountTap) {
                    PictriHomeTopPill(badgeCount: friendStore.incomingRequests.count)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("アカウント")
                .accessibilityValue(friendStore.incomingRequests.count == 0 ? "" : "フレンド申請\(friendStore.incomingRequests.count)件")
            }
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
            // v10 CAROUSEL AMBIENT DEPTH: 既存の2色構造(paper土台 +
            // surfaceRaisedの明るいdepth radial)は変更せず、その上へ
            // Home brand accent(muted lavender)由来のごく弱いradial光を
            // 1層だけ追加する。中心・半径は上のsurfaceRaised radialと
            // 揃えつつ、endRadiusはそれよりも一回り小さく抑え、Hero+左右
            // Side Cardの範囲にだけ自然に収まるようにした(header/Dock側は
            // 既存の深いdarkカラーのまま)。opacityは0.05を頂点とし、円や
            // 帯として視認できない広く滑らかなfalloffのみで構成する
            // (単色→透明の2 stopのみ、追加のstop/線は入れない)。
            RadialGradient(
                colors: [
                    PictriHomeBrandAccent.accent.opacity(0.05),
                    PictriHomeBrandAccent.accent.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 30,
                endRadius: 380
            )
            .allowsHitTesting(false)
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

    // MARK: - v5 True Vertical Paging

    private var modeAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.26)
    }

    /// v5: プログラム的な遷移(「最近の記録 ⌄」タップ・右dotタップ)は
    /// `scrolledMode`を`withAnimation`内で更新するだけで、SwiftUIが
    /// `.scrollPosition(id:)`バインディングの変化をscroll animationとして
    /// 自動的に扱う(programmatic jumpではなく実際のscrollアニメーション)。
    private func scrollToMode(_ mode: PictriHomeMode) {
        guard scrolledMode != mode else { return }
        withAnimation(modeAnimation) {
            scrolledMode = mode
        }
    }

    /// 画面右上に固定表示する縦2dotのmode indicator。v4まではmodeごとに
    /// 切り替わるtitle blockの右上に相対配置していたが、v5でtitleがpage自身に
    /// 移動した(pageと一緒にスクロールする)ため、dotsは画面座標に固定した
    /// 独立したoverlayにした(スクロール中も位置が動かない、標準的なpage
    /// indicatorの挙動)。`scrolledMode`(実際のscroll position由来)を直接見て
    /// active/inactiveを判定するため、scroll中も常に同期している。
    private var modeIndicatorOverlay: some View {
        HStack {
            Spacer(minLength: 0)
            PictriHomeModeDots(mode: homeMode, onSelect: scrollToMode)
        }
        .padding(.horizontal, PictriFinalTheme.screenPadding)
    }

    private func titleBlock(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PictriTypography.display(20))
                .foregroundStyle(PictriFinalTheme.ink)

            Capsule()
                .fill(PictriHomeBrandAccent.accent)
                .frame(width: 34, height: 3)

            if let subtitle {
                Text(subtitle)
                    .font(PictriTypography.body(13, weight: .semibold))
                    .foregroundStyle(PictriDarkTheme.textFaint)
                    .monospacedDigit()
            }
        }
    }

    /// MAP STATE: 中央に既存のJapan geometry/data(`PictriJapanCollectionMap`)を
    /// rounded rectangle cardへ入れず、背景空間へ直接置く。下部の
    /// 「最近の記録 ⌄」でRecentへ遷移する。
    ///
    /// v2 MAP COMPOSITION: `PictriJapanCollectionMap`本体(Map本画面と共有、
    /// 変更禁止)は自分に与えられたframe内で`fitScale = min(width/canvasWidth,
    /// height/canvasHeight)`によりJapan形状を中央寄せする。旧実装は
    /// `.frame(maxWidth: .infinity, maxHeight: .infinity)`で「使える縦空間
    /// 全部」を渡していたため、width基準でfitScaleが決まった後の余った
    /// 縦方向が上下均等にletterboxされ、「title直下の不要な上余白」として
    /// 見えていた(下半分の余白はボタンで紛れて目立たなかっただけ)。
    /// 今回は共有コンポーネント自体(内部centeringロジック)には触れず、
    /// Home側wrapperが渡すframeの高さを「width基準でこの形状が実際に
    /// 描画される高さ」(= containerWidth × canvasHeight/canvasWidth)に
    /// 正確に合わせることで、width/height両方の制約が同時に効くように
    /// (=内部letterboxがほぼ0になるように)する(Method A)。
    /// このexact-heightのMap自体をVStackの先頭(top)に置き、余った縦
    /// 空間は明示的なSpacerとして「最近の記録」ボタンの上に集める
    /// (Referenceの「tightな上余白 / 独立してゆとりのある下部」という
    /// 非対称な構図を、共有コンポーネントを変更せずに再現する)。
    /// v3 TASK4 MAP VISUAL QUALITY: `PictriJapanCollectionMap`本体・
    /// `PictriDarkTheme.mapUnvisitedFill/Stroke`(Map本画面と共有のtoken)は
    /// 一切変更しない。既存の`palette`引数(コンポーネント側に元から
    /// 存在する差し替えポイント)だけを使い、Home限定でdormantStroke
    /// (県境の線)のopacityだけ0.09→0.16へ引き上げ、「未訪問県がただの
    /// 灰色ベタ塗りに見える」問題(県境が背景へ溶けて輪郭階層が消える)を
    /// 緩和する。dormantFill(塗り色)・visitedStroke・memoryColor(訪問時の
    /// 実データ色)は`.light`と完全に同じ値のまま(訪問データの改ざんは
    /// 一切していない)。
    /// v4 TASK1 BLACK DOT: Referenceには県中心の黒point markerが無い。「県の塗り分け
    /// だけを見せたい」というHome限定要求のため、`centroidDot`だけ`.clear`にする
    /// (Map本画面のデフォルト`.light`パレットは`centroidDot: PictriFinalTheme.paper`の
    /// ままで、この変更の影響を受けない)。
    /// v4 TASK3 背景統一: `PictriJapanCollectionMap`は自分のframe全体へ`palette.background`
    /// (旧`.light`では`PictriFinalTheme.paper`という不透明な単色)を塗るため、Home側の
    /// `homeBackground`(radial gradient + atmosphere flecks)の上に、Mapの矩形部分だけ
    /// 「フラットな単色の帯」が重なって見えていた(これが「背景色が違う」と感じる正体)。
    /// Home限定パレットでは`background`を`.clear`にし、Mapの塗りをやめて`homeBackground`を
    /// そのまま透過させることで、画面全体を1枚の連続した背景にする(Map本画面の
    /// `.light`は不透明のまま、影響なし)。
    /// v5 TASK2: dash→solidへの変更(共有描画コード側)に合わせ、solid線として
    /// 見たときの体感の太さ/主張が変わらないようdormantStroke opacityを微調整
    /// (0.16→0.20、dashは隙間で同じopacityでも軽く見えるため)。visitedStrokeは
    /// 「白い太線が主役になる」問題を避けるため、`PictriFinalTheme.ink`
    /// (primary text、明るい白)からmode-awareな中間トーンの`textFaint`寄りへ
    /// 落とし、fillの色そのものが主役に見えるようにした(Map本画面の`.light`は
    /// 無変更、Home限定)。
    /// Round 8: 旧`static var`(memoryColorが常にPictriFinalTheme.memoryColorという
    /// stateless funcだった)から、`memoryStore`を参照するinstance var化した
    /// (Prefecture Progress ResolverはMemoryStoreの実データを必要とするため)。
    /// dormantFill/dormantStroke/visitedStroke/centroidDot・背景統一・黒dot除去等、
    /// 過去roundで確定した値は一切変更しない。memoryColorの中身だけ、旧
    /// 「47県を5色でローテーションする」ロジックから「おすすめSpotコンプリート進捗の
    /// 6段階color」へ差し替えた(Map本画面の`.light`パレット・`PictriFinalTheme.memoryColor`
    /// 自体は無変更、Home限定の新設token`PictriPrefectureProgressTheme`を使う)。
    /// Round「HOME MAP FINAL VISUAL CORRECTION」で確定した最終Visual Direction。
    /// 直前Round(HOME WHITE MAP REDESIGN)の白いMap Canvas/白いRounded Cardは
    /// ユーザーの明示的な却下により不採用。`background`は必ず`.clear`にし、
    /// Home自身のdark background(`homeBackground`)をそのまま透過させる
    /// ——地図専用の背景色は一切持たない(G01-G04)。
    /// `dormantFill`が呼ばれるのは`visited == false`の時だけ(共有コンポーネント
    /// 側の既存分岐)なので、`memoryColor`クロージャは「visited」判定を通過した
    /// 県にしか呼ばれない(Round 8から不変の契約)。クロージャ内の判定順序は
    /// spec通り: 1.completedSpotIDsが空→anywhereVisited 2.complete→gold
    /// 3.それ以外→地方色。
    private var mapPaletteForHome: PictriJapanCollectionMapPalette {
        PictriJapanCollectionMapPalette(
            background: .clear,
            dormantFill: PictriHomeMapTheme.unvisited,
            dormantStroke: PictriHomeMapTheme.unvisitedBorder.opacity(0.75),
            visitedStroke: PictriHomeMapTheme.visitedBorder,
            centroidDot: .clear,
            memoryColor: { prefectureId in
                let progress = resolvedPrefectureProgress(for: prefectureId)
                if progress.completedRecommendedSpotIDs.isEmpty {
                    return PictriHomeMapTheme.anywhereVisited
                }
                if progress.collectionLevel == .complete {
                    return PictriHomeMapTheme.complete
                }
                let region = questPrefectureShapes.first(where: { $0.id == prefectureId })?.region ?? "kanto"
                return PictriHomeMapTheme.regionColor(forRegion: region)
            }
        )
    }

    /// Round 8 QA専用、HOME WHITE MAP REDESIGNで10〜15件容量に対応させた。
    /// `-pictriMapProgressOverrides "tokyo:5:12,osaka:3"`のように
    /// `県id:達成数[:総数]`で渡すと、その県だけ実際のMemoryデータを無視して
    /// 指定の達成数/総数(総数省略時は12、将来の10〜15件運用を見越した既定値)を
    /// 強制表示する。UserDefaults/QuestMemoryStoreへは一切書き込まない、
    /// 表示専用の上乗せ(プロセス終了で消える)。本番データ・本番Spot catalogは
    /// 一切触らない。
    #if DEBUG
    private func debugPrefectureProgress(for prefectureId: String) -> PrefectureProgress? {
        guard let override = PictriVisualReview.mapProgressOverrides[prefectureId] else { return nil }
        let total = max(1, override.total)
        let clamped = max(0, min(override.completed, total))
        let syntheticIds = Set((0..<clamped).map { "debug_qa_spot_\($0)" })
        return PrefectureProgress(
            prefectureID: prefectureId,
            hasVisited: true,
            completedRecommendedSpotIDs: syntheticIds,
            totalRecommendedSpotCount: total
        )
    }
    #endif

    private func resolvedPrefectureProgress(for prefectureId: String) -> PrefectureProgress {
        #if DEBUG
        if let debugProgress = debugPrefectureProgress(for: prefectureId) {
            return debugProgress
        }
        #endif
        return memoryStore.prefectureProgress(for: prefectureId)
    }

    /// Round 8 QA専用。DEBUG override対象の県は、実際のMemoryが無くても
    /// 「訪問済み」として塗り分けさせる必要がある(`visited`判定がfalseだと
    /// dormantFillのまま=色が反映されないため)。Production起動時
    /// (overridesが空)はmemoryStore.visitedPrefectureIdsと完全に同じ集合。
    private var visitedPrefectureIdsForHomeMap: Set<String> {
        var ids = memoryStore.visitedPrefectureIds
        #if DEBUG
        ids.formUnion(PictriVisualReview.mapProgressOverrides.keys)
        #endif
        return ids
    }

    /// Round「HOME MAP FINAL VISUAL CORRECTION」: 前Round(HOME WHITE MAP
    /// REDESIGN)の白いcard専用insetは、cardごと廃止したため不要になった
    /// (Mapはcardへ収めない、Homeの中央領域へ直接大きく配置する)。
    /// `.scaleEffect`はcenter-anchorだと上下均等にoverflowし、左上の
    /// achievementBadgeへ被る実機不具合を過去に起こしているため、今回は
    /// `.top`をanchorにして「Japan形状が下方向にだけ少し大きくなる」構成にし、
    /// badgeとの重なりを構造的に避ける(layoutサイズ自体は不変、視覚のみ拡大)。
    private static let mapDisplayScale: CGFloat = 1.12

    /// Round「HOME MAP OKINAWA REPOSITION」: 沖縄(本体+離島7件、全211点)を
    /// canvas座標系でそのまま左上の空白域へ平行移動するだけの上書き。
    /// 形状は歪めない(scale=1.0、translationのみ)。
    ///
    /// 算出根拠(scratchpadでQuestMapGeoData.swiftの実座標を集計して確認済み):
    /// - 沖縄クラスタ(本体+全離島)の現在の重心(全点単純平均): (258.11, 383.35)
    /// - 他の都道府県・離島は canvas の x<140, y<160 の領域に1点も存在しない
    ///   (空白であることを実座標で確認済み、目視の当てずっぽうではない)
    /// - 沖縄クラスタのbounding boxは幅約66.7×高さ約58.0(canvas単位)
    /// - 移動先の重心を(58, 55)に置くと、bounding boxの余白が上下左右とも
    ///   約25〜30canvas単位確保でき、本土のどの県からも離れ、canvas範囲
    ///   [0, 312]×[0, 424.37]内に収まる(=clippingしない)
    /// - translation = 目標重心 − 現在の重心 = (58−258.11, 55−383.35)
    private static let okinawaRegionOverride = PictriMapRegionOverride(
        scale: 1.0,
        translation: CGSize(width: -200.11, height: -328.35)
    )

    /// HOME WHITE MAP REDESIGN: 旧「旅の地図」の大見出し+underline+subtitleという
    /// titleBlockは削除し、達成度(訪問県数/47)だけを左上の小さなpillへ移す
    /// (spec「達成度表示を左上に移動する」)。Home上部のnotification/account
    /// pillと同じ「暗いcapsule」語彙を再利用し、既存Design Systemを壊さない。
    private var mapAchievementBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PictriHomeBrandAccent.accent)
            Text("\(memoryStore.visitedPrefectureIds.count) / \(questPrefectureShapes.count)")
                .font(PictriTypography.body(13, weight: .bold))
                .foregroundStyle(PictriFinalTheme.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.85))
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("訪れた都道府県 \(memoryStore.visitedPrefectureIds.count) / \(questPrefectureShapes.count)")
    }

    private func mapPage(containerWidth: CGFloat, maxMapHeight: CGFloat) -> some View {
        let idealMapHeight = containerWidth * (QuestJapanMapMetrics.canvasHeight / QuestJapanMapMetrics.canvasWidth)
        let mapHeight = min(idealMapHeight, maxMapHeight)
        return VStack(spacing: 0) {
            mapAchievementBadge
                .padding(.horizontal, PictriFinalTheme.screenPadding)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            // HOME MAP FINAL VISUAL CORRECTION: card/canvas/rounded rectangle/
            // shadowは一切付けない。`PictriJapanCollectionMap`は`background: .clear`
            // (mapPaletteForHome)で自身の矩形を透過させるため、ここでも
            // 追加のbackground/clipShape/overlay/shadowを重ねない
            // ——Homeのdark backgroundの上に日本列島の形だけが直接浮かぶ。
            PictriJapanCollectionMap(
                visitedPrefectureIds: visitedPrefectureIdsForHomeMap,
                onSelect: { _ in },
                palette: mapPaletteForHome,
                interactionEnabled: false,
                progressResolver: { resolvedPrefectureProgress(for: $0) },
                regionLayoutOverrides: ["okinawa": Self.okinawaRegionOverride]
            )
            .frame(width: containerWidth, height: mapHeight)
            .scaleEffect(Self.mapDisplayScale, anchor: .top)

            Spacer(minLength: 12)

            Button {
                scrollToMode(.recent)
            } label: {
                VStack(spacing: 4) {
                    Text("最近の記録")
                        .font(PictriTypography.body(13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PictriDarkTheme.textFaint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("最近の記録を見る")
            .padding(.bottom, 4)
        }
    }

    /// RECENT STATE: 既存のHorizontal Circular Carouselをそのまま使う。
    /// dotsではなく「current / total」形式のnumeric paginationへ変更。
    /// v5: pageがVStackとして画面のcontent領域全体の高さを持つようになった
    /// ため、末尾に本物のflexible Spacerを置けるようになった。これにより
    /// 旧来からの既知の残差(pagination→Dock間が詰まりすぎ)を、Hero
    /// Geometry(Freeze対象)やCarousel自身のoverflowBufferには一切触れずに
    /// 緩和する(page自身の余白配分だけの変更)。
    private func recentPage(heroMaxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            titleBlock(title: "最近の記録", subtitle: nil)
                .padding(.horizontal, PictriFinalTheme.screenPadding)

            feedSection(heroMaxHeight: heroMaxHeight)
                .padding(.top, 14)
            // v2 RECENT COMPOSITION: Reference実測(Hero bottom→pagination
            // ≈26.5pt)に対し、旧`.padding(.top, 8)`はCarousel自身のoverflow
            // buffer(Like/Comment clipping防止用、Freeze対象)と合わせると
            // 実測50pt超になっていた。Carousel側のoverflowBufferには触れず、
            // ここの追加paddingだけ0へ縮小し、可能な範囲でReferenceの
            // 密度(Hero直後にpaginationが来る感覚)へ寄せる。
            paginationLabel

            Spacer(minLength: 16)
        }
    }

    @ViewBuilder
    private var paginationLabel: some View {
        if !visiblePosts.isEmpty {
            let currentIndex = max(visiblePosts.firstIndex(where: { $0.id == currentPostId }) ?? 0, 0)
            Text("\(currentIndex + 1) / \(visiblePosts.count)")
                .font(PictriTypography.body(13, weight: .semibold))
                .foregroundStyle(PictriDarkTheme.textFaint)
                .monospacedDigit()
                .animation(.easeOut(duration: 0.2), value: currentIndex)
        }
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
/// Round: MAP/ALBUM REFERENCE MIGRATIONでMap/Albumの新Top Areaからも再利用する
/// ため`private`を外しただけ(ロジック・見た目は一切変更していない、Homeの
/// 描画結果はpixel単位で無変更)。
struct PictriHomeTopPill: View {
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
                    // v8.2: notification dotも旧terracottaからHome brand
                    // accentへ(「tiny detail」としてlavenderを使う対象の一つ)。
                    Circle()
                        .fill(PictriHomeBrandAccent.accent)
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

/// v10 RIGHT MODE INDICATOR: Reference右側の縦2dot。小さく控えめ、tapで
/// Map⇄Recentを切り替える。Circular Carouselのpagination dots(廃止済み)
/// とは無関係の、mode切替専用インジケータ。
private struct PictriHomeModeDots: View {
    let mode: PictriHomeMode
    let onSelect: (PictriHomeMode) -> Void

    var body: some View {
        VStack(spacing: 8) {
            dot(for: .map)
            dot(for: .recent)
        }
        .padding(6)
        .contentShape(Rectangle())
    }

    private func dot(for target: PictriHomeMode) -> some View {
        let isActive = mode == target
        return Button {
            onSelect(target)
        } label: {
            Circle()
                .fill(isActive ? PictriHomeBrandAccent.accent : PictriDarkTheme.textFaint.opacity(0.55))
                .frame(width: isActive ? 7 : 6, height: isActive ? 7 : 6)
        }
        .buttonStyle(.plain)
        .contentShape(Circle().inset(by: -10))
        .accessibilityLabel(target == .map ? "旅の地図を見る" : "最近の記録を見る")
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

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .settings:
            // v9 Phase 2 — DARK ONLY POLICY: 外観切替行(ダーク/ライト)は
            // Production UIから撤去した(Light Modeはもう選べない選択肢を
            // 残さない)。切り替え先の`PictriAppearanceStore.mode`自体は
            // `.current`が常に`.dark`を返すため、仮にこの行が復活しても
            // 実際にはLightへ切り替わらない状態になっている。
            VStack(spacing: 12) {
                JQAccountMenuRow(icon: "person.crop.circle", title: "プロフィール編集")
                JQAccountMenuRow(icon: "lock.fill", title: "友達の見え方")
                JQAccountMenuRow(icon: "bell.fill", title: "通知")
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
