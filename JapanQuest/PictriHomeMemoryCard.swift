import SwiftUI
import UIKit

// MARK: - Home Memory Card(Dual Camera Flip、PHYSICAL WORLD FINALIZATION)
//
// 写真そのものが主役になるよう、二重・三重のRoundedRectangle枠は作らず
// 「写真+繊細なrim light+自然な厚みのshadow」に留める。Tapで外カメラ⇄
// 内カメラをflipする(「FLIP」の文字・矢印アイコン・説明は一切表示しない —
// 写真そのものをtapすると自然に裏返る)。
//
// PHYSICAL WORLD FINALIZATION: 「Like/CommentがCardから独立したtileに
// 見える」という指摘を受け、再びCard自身の責務へ統合した(Home全体の
// 独立Action Rowは廃止)。ただし旧来の「角にぶら下がる安いpill」には
// 戻さず、直近の丸いseal/非対称note tagの語彙を維持したまま、Cardの
// 下端にわずかに重なる形で「写真に貼り付いた物理オブジェクト」として
// 再配置した。
//
// 差分監査で見つかった「安物感」の是正:
// 1) identity行が黒い丸ピル(capsule)の中に浮いていて、写真から浮いた
//    「UIパーツ」に見えていた → 上端のみの柔らかいscrimに直接avatar+文字を
//    乗せる、参考画像に近い一体感のある見せ方に変更。
// 2) card外周が均一なflat hairlineで、厚み・光の拾い方が感じられなかった
//    → 単色ではなくグラデーションのrim strokeにし、光が上端から回り込む
//    ような、控えめだが確かに「高級感のある物」に見える処理にした
//    (虹色・neonにはしない、白の濃淡だけで表現する)。二重のstrokeBorderで
//    「印画紙の厚み」の断面のような見え方を追加した。
struct PictriHomeMemoryCard: View {
    let post: QuestFeedPost
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    /// このpost自身のComment Noteが展開中かどうか。trueの間はCard自身の
    /// Seal/Note tagを隠す(Noteの背後にcountが覗いてしまう実機不具合の
    /// 対応。Cardサイズを0.82へ拡大した際、Note自身の固定位置より下に
    /// Seal/Note tagがはみ出すケースがあることを確認したため)。
    let isCommentNoteOpen: Bool
    let onProfileTap: () -> Void
    let onLike: () -> Void
    let onOpenComments: () -> Void

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showFront = true
    @State private var isFlipped = false
    /// v10 PRODUCTION HOTFIX: Reduce Motion時、旧実装は`showFront`の
    /// crossfadeだけで「反転」を表現しており、3D回転が完全に0固定
    /// (`outerFlipDegrees`参照)のため実質「画像が入れ替わるだけ」に
    /// 見えていた。3D perspective/parallaxは加えず(Reduce Motionの
    /// 意図を尊重)、affineな水平scaleだけで「一度edge-onまで潰れて
    /// 戻る」動きを作り、Reduce Motion時でも「同じ物体が反転した」と
    /// 分かるようにする。
    @State private var reducedFlipSqueeze: CGFloat = 1

    private var flipDuration: Double { reduceMotion ? 0.001 : 0.5 }
    private let reducedFlipHalfDuration: Double = 0.18

    /// 外カメラ(場所)の生画像。旧Memoryではnilになりうる。
    private var frontImage: UIImage? {
        memoryStore.outerOnlyImage(for: post) ?? memoryStore.image(for: post)
    }

    /// 内カメラ(そのときの自分)の生画像。データがspotId経由で解決できる
    /// 投稿であれば、自分の投稿でも友達の投稿でも同じロジックで揃う
    /// (既存のQuestMemoryStore解決ロジック自体がisMineを見ていないことを
    /// 監査済み)。
    private var backImage: UIImage? {
        if let selfie = memoryStore.selfieImage(for: post) {
            return selfie
        }
        guard let composite = memoryStore.image(for: post) else { return nil }
        return QuestDualPhotoComposer.cropInnerCamera(from: composite)
    }

    /// 裏面が存在しない(旧Memory、または友達投稿でデータ未整備)場合は
    /// flipを発生させない — 無意味なflipでcrash/空白を出さない
    /// (Legacy Memory Fallback)。
    private var canFlip: Bool {
        backImage != nil
    }

    #if DEBUG
    /// DEBUGフラグの値はpostIdの直接指定に加え、`"mine"`という特殊値も受け付ける。
    /// `-pictriSeedDualMemory true`で作られる自分の投稿はUUIDで生成され事前に
    /// id文字列を知りようがないため、「post.isMine」でも一致させられるようにする。
    private func matchesDebugTarget(_ raw: String?) -> Bool {
        guard let raw, canFlip else { return false }
        if raw == "mine" { return post.isMine }
        return raw == post.id
    }
    #endif

    /// `-pictriHomeFlipShowBack <postId|mine>` QAスクショ専用(DEBUG限定)。
    private var debugShowBackInitially: Bool {
        #if DEBUG
        return matchesDebugTarget(PictriVisualReview.homeFlipShowBackPostId)
        #else
        return false
        #endif
    }

    /// `-pictriHomeFlipMidpoint <postId|mine>` QAスクショ専用(DEBUG限定)。flip motionの
    /// 中間点(90度、エッジオン)で静止させ、ghosting/鏡像化の有無を確認する。
    private var debugFreezeAtMidpoint: Bool {
        #if DEBUG
        return matchesDebugTarget(PictriVisualReview.homeFlipMidpointPostId)
        #else
        return false
        #endif
    }

    private var outerFlipDegrees: Double {
        if debugFreezeAtMidpoint { return 90 }
        return (reduceMotion ? 0 : (isFlipped ? 180 : 0))
    }

    var body: some View {
        photoStack
    }

    /// Round 8: Anywhere Memory = neutral silver/soft-white rim、Recommended
    /// Spot Memory = PicTri Lavenderのrim。どちらもv7で確定した「top→bottomの
    /// 垂直方向のみ」という構造は変えず、色のstopだけを差し替える(ネオン/発光/
    /// 太枠にはしない、既存と同じ1.25ptのまま)。
    private var rimColors: [Color] {
        switch post.captureKind {
        case .recommendedSpot:
            return [
                PictriHomeBrandAccent.accent.opacity(0.40),  // top
                PictriHomeBrandAccent.accent.opacity(0.16),
                Color.black.opacity(0.10),
                Color.black.opacity(0.22)                     // bottom
            ]
        case .anywhere:
            return [
                PictriPrefectureProgressTheme.softWhite.opacity(0.20),  // top
                PictriPrefectureProgressTheme.softWhite.opacity(0.06),
                Color.black.opacity(0.10),
                Color.black.opacity(0.22)                                // bottom
            ]
        }
    }

    @ViewBuilder
    private var photoStack: some View {
        ZStack(alignment: .top) {
            Group {
                if showFront {
                    photoLayer(frontImage).transition(.opacity)
                } else {
                    photoLayer(backImage).transition(.opacity)
                }
            }

            photoDepthVignette

            topScrim
            bottomScrim

            identityRow
                .padding(.horizontal, 14)
                .padding(.top, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous))
        // v6 BEZEL RECONSTRUCTION: 旧実装は外周3.6pt(AngularGradient、最大opacity
        // 0.40)+内側highlight 1pt+内側shadow 1ptの計3層・実効5.6ptぶんの
        // strokeを全周へ均一に重ねており、これが「太いgray plastic frame」に
        // 見える直接の原因だった(写真が無い/暗いplaceholder状態だと特に、
        // 枠だけが目立つ額縁として浮いて見える)。層数は3→1へ削減、
        // lineWidthも3.6→1.25pt(数px単位のmicro edge)へ縮小した。
        //
        // v7 BILATERAL SYMMETRY FIX: v6のAngularGradientは「upper-leftを
        // 最も明るく、upper-rightをごく暗く」という意図でstopを置いたが、
        // 実際のFinal screenshotをpixel計測した結果、右edgeのpeak輝度が
        // 左edgeの約2倍(right≈65-72 / left≈28-36、TOP・CENTER・BOTTOM
        // すべての帯で右が明るい)という明確な左右非対称になっていた。
        // `AngularGradient(startAngle: .degrees(0), ...)`の角度原点が
        // 「top」だという前提でstopのlocationをコメント付けしていたが、
        // 実際の描画はその前提と一致しておらず、結果的に右側だけ強い
        // rimになっていた(handoffされたコメントの角度対応が実際の
        // レンダリングと食い違っていたことが根本原因)。
        // 今回は角度ベースの構成自体をやめ、「top→bottomの垂直方向のみ」の
        // `LinearGradient(startPoint: .top, endPoint: .bottom)`へ置き換えた。
        // 垂直方向のみのgradientはX座標に一切依存しないため、左右対称で
        // あることが構造的に保証される(角度の思い違いが再発しようがない)。
        // 主光源はscreen top、下端はcontact depthといういう既存の方針
        // (Task3)はそのまま踏襲し、左右は完全に中立(同じ値)にした。
        // v11 ROUND 8 RIM DIFFERENTIATION: Card size/geometry/position/zIndexは
        // 完全に凍結したまま、bezelの色相だけをcaptureKindで分岐させる。
        // 構造(top→bottomの垂直LinearGradient、1.25pt、4 stop)はv7 BILATERAL
        // SYMMETRY FIXのものを一切変更していない(X座標に依存しないため、
        // 色を差し替えても左右対称性は構造的に保証されたまま)。Recommended
        // Spotのみ`PictriHomeBrandAccent.accent`(PicTri Lavender)を薄く混ぜ、
        // Anywhereは既存のSoft White系(neutral)のまま(太い枠・発光・
        // グラデーション状の縁取りにはしない、あくまでmicro edgeの色差)。
        .overlay {
            RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: rimColors,
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.25
                )
        }
        // v5 #20-22是正: 旧`y: 16`は VStack(circle+count) の下端が既に
        // Card下端とほぼ揃う設計(overlay(.bottomLeading)のデフォルト位置で
        // circle自体はCard内部に収まる)に、さらに16pt分下へ押し出していた
        // ため、count文字だけでなくcircle本体まで写真の外(黒い虚空)に
        // はみ出して「Cardから浮いた別オブジェクト」に見えていた。
        // オフセットを最小限(4pt)に抑え、circle本体はCard内(写真の上)に
        // 留めたまま、count文字だけがCard下端にごく僅かに触れる程度にする
        // (「写真に貼り付いた物理オブジェクト」の再現)。
        // v8 SOCIAL候補比較(17 Pro Dark実写真):
        // A) CURRENT SEPARATE(旧v4〜v7) — Like円形seal(左下)/Comment note
        //    tag(右下)を独立したobjectとして両端に配置。過去ラウンドで
        //    「独立して見える」指摘への対応として確定させた案だったが、
        //    今回Referenceと並べると依然「2つの別部品」に見えた。
        // B) REFERENCE JOINED CAPSULE(採用) — `PictriMemorySocialCapsule`で
        //    Like+count | divider | Comment+countを1つのdark capsuleへ
        //    統合し、写真下辺のすぐ上(bottomLeading、Card外へはみ出さない
        //    位置)へ配置。実写真で見るとReferenceの「1つの物体」という
        //    一体感に明確に近づいたため、過去の分離指定より優先して採用した。
        // C) REFERENCE JOINED CAPSULE(小型静音版) — Bのpadding/フォントを
        //    さらに絞った版も検討したが、Bの時点で既に十分quietで
        //    Referenceの主張しすぎない質感と一致したため、追加の縮小は
        //    不要と判断した。
        //
        // v8 BUGFIX(flip): このoverlayは元々rotation3DEffectより後段に置かれて
        // いたため、Flip中もCapsuleだけ回転せず静止して見える(Cardが edge-on
        // で消えてもCapsuleだけ宙に浮く)実機bugがあった。「写真に貼り付いた
        // 物理オブジェクト」という前提上、Capsuleも写真と一緒に回転して初めて
        // 一貫するため、rotation3DEffectより前段(bezel overlay群と同じ位置)へ
        // 移動した。
        .overlay(alignment: .bottomLeading) {
            if !isCommentNoteOpen {
                PictriMemorySocialCapsule(
                    isLiked: isLiked,
                    likeCount: likeCount,
                    commentCount: commentCount,
                    onLike: onLike,
                    onOpenComments: onOpenComments
                )
                .padding(.leading, 14)
                .padding(.bottom, 14)
            }
        }
        // v9 Phase 3 ROOT CAUSE FIX: 旧実装(PictriMemoryFlipCardから踏襲)は
        // 「裏面コンテンツへの+180°逆回転」と「外側の連続flip回転」という
        // 2つのrotation3DEffectを直列に重ねていた。rotation3DEffectは
        // それぞれが独自にperspective投影を行うため、2つを重ねると単一の
        // 連続回転とは数学的に等価にならない。特に裏面逆回転は showFront
        // 切り替え(アニメーション中間点、outerFlipDegrees≈90°付近)で
        // 0°→180°へ「離散的に」ジャンプするため、そのジャンプと外側の
        // 連続回転(独立した2つ目のperspective投影)が合成された瞬間、
        // Card全体が一度縮んでから別サイズに戻ったように見える実機不具合の
        // 原因になっていた(静止した0°/180°ではframeサイズが一致していた
        // ため、Phase 2時点では検出できなかった)。
        //
        // 修正: 3D回転(perspective投影)はこの1つのrotation3DEffectだけに
        // 統合する。裏面の鏡像化補正は、perspectiveを持たないaffineな
        // scaleEffect(x: -1)へ置き換えた。affine変換はperspective項を
        // 持たないため、外側の3D回転と重ねても二重投影による歪みが発生
        // しない(静止時の見え方はscaleEffect(-1) + 180°回転 = 元の
        // 「+180°逆回転 + 180°回転」と数学的に同じ結果になるため、
        // front/back静止状態の見え方はPhase 2から変更なし)。
        .scaleEffect(x: (reduceMotion ? reducedFlipSqueeze : (showFront ? 1 : -1)), y: 1)
        .rotation3DEffect(
            .degrees(outerFlipDegrees),
            axis: (x: 0, y: 1, z: 0)
        )
        // v9 POST QUALITY / BEZEL CLOSURE: 旧v8はここへさらに
        // `PictriHomeBrandAccent.accent.opacity(0.14)`の全方位shadow(radius20,
        // y:0)を重ね、「光を纏っている空気感」を狙っていたが、実際には
        // Card全体を均等に紫へ滲ませる「発光」そのものであり、今回明示的に
        // 禁止された「紫の強い発光」に該当するため削除した。深さは
        // 「接地に近い小さいshadow」+「弱いambient shadow」の2層だけで表現する
        // (Glowではなく物理的な浮きの表現)。
        .shadow(color: PictriHomeCardTheme.ambientShadow, radius: 24, x: 0, y: 16)
        .shadow(color: PictriHomeCardTheme.contactShadow, radius: 6, x: 0, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous))
        .onTapGesture { flip() }
        .accessibilityAddTraits(canFlip ? .isButton : [])
        .accessibilityLabel(
            canFlip
                ? (showFront ? "写真。タップするともう一方の写真を表示" : "写真の裏。タップすると表の写真に戻る")
                : "写真"
        )
        .onAppear {
            if debugShowBackInitially {
                showFront = false
                isFlipped = true
            }
        }
    }

    /// identity行の可読性のためだけの、上端限定の柔らかいscrim。カード全体を
    /// 暗くする「膜」にはせず、必要な範囲だけを覆う。
    private var topScrim: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.5), Color.black.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 96)
        .allowsHitTesting(false)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Seal/Note tagの可読性のための下端限定scrim(topScrimと対になる、
    /// 同じ強さの控えめなgradient)。
    private var bottomScrim: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 110)
        .allowsHitTesting(false)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    /// POST QUALITY: 写真に色を足すfilterではなく、四隅の黒レベルだけを
    /// ごくわずかに沈める(multiply)。写真が背景の黒とほぼ同輝度で
    /// 混ざり合い「枠だけが浮いた輪郭」に見える/背景へ溶けて奥行きが
    /// 消える、という2つの失敗を避け、写真自体に「物として占有する
    /// 領域」の分離を与える。色相・彩度は一切変更しない(neutral black
    /// のみ)。
    private var photoDepthVignette: some View {
        RadialGradient(
            colors: [Color.clear, Color.black.opacity(0.16)],
            center: .center,
            startRadius: 40,
            endRadius: 260
        )
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func photoLayer(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            // v6 TASK3 MISSING PHOTO QUALITY: 旧実装は`surfaceRaised→
            // surfaceOverlay`(値の近い2色)だけの縦グラデーションで、
            // ほぼ無地に近く「巨大な黒いRectangle」に見えていた。
            // アイコン・「No Image」文字・派手なgradient borderは追加せず、
            // 1) 既存の縦グラデーションはそのまま基調として維持し、
            // 2) 中央よりやや上に、ごく低振幅(opacity 0.05)のradial sheenを
            //    1層重ねるだけで、「面」ではなく「光を受ける面」に見える
            //    最小限の depth cueを足す(実写真があるProductionでは
            //    このViewは一切描画されないため、既存の写真表示に干渉しない)。
            ZStack {
                LinearGradient(
                    colors: [PictriHomeCardTheme.placeholderTop, PictriHomeCardTheme.placeholderBottom],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.36),
                    startRadius: 8,
                    endRadius: 280
                )
            }
        }
    }

    /// capsule背景を廃し、avatar+文字を直接scrimの上に乗せる(参考画像の
    /// 一体感を踏襲)。
    /// v6 TASK4 IDENTITY HEADER: サイズ・位置は不変。avatarのring opacityを
    /// 下げ内側にごく薄いshadowを足して「バッジ」ではなく物の縁として
    /// 沈める。username/relative timeへ微小なtracking(0.2/0.5)を加え、
    /// 汎用UIフォントの並びではなく組版された「metadata」に近づけた
    /// (font size/weight/色そのものは変更していない)。
    private var identityRow: some View {
        Button(action: onProfileTap) {
            HStack(spacing: 9) {
                Circle()
                    .fill(HomeFriendColor.accent(for: post.username).opacity(0.94))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                            .blur(radius: 0.5)
                            .padding(0.5)
                    }
                    .overlay {
                        Text(String(post.username.prefix(1)).uppercased())
                            .font(PictriTypography.body(12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.72))
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.username)
                        .font(PictriTypography.body(13.5, weight: .bold))
                        .tracking(0.2)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    Text(post.relativeTimeText)
                        .font(PictriTypography.mono(10, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.74))
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.username)、\(post.relativeTimeText)")
    }

    private func flip() {
        guard canFlip else { return }
        if reduceMotion {
            // v10 PRODUCTION HOTFIX: 3D rotationは使わず(Reduce Motionの
            // 意図を尊重)、水平scaleを1→ほぼ0→1と動かすaffineな squeeze
            // だけで「一度edge-onまで潰れて裏返る」動きを表現する。
            // 内容の切替(showFront)はsqueezeの最小点(前半終了時点)で
            // 行い、通常版と同じ「edge-on付近でだけ中身を差し替える」
            // 原則を保つ。
            withAnimation(.easeInOut(duration: reducedFlipHalfDuration)) {
                reducedFlipSqueeze = 0.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + reducedFlipHalfDuration) {
                showFront.toggle()
                isFlipped.toggle()
                withAnimation(.easeInOut(duration: reducedFlipHalfDuration)) {
                    reducedFlipSqueeze = 1
                }
            }
            return
        }
        withAnimation(.easeInOut(duration: flipDuration)) {
            isFlipped.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDuration / 2) {
            showFront.toggle()
        }
    }
}

// MARK: - Relative time

extension QuestFeedPost {
    /// Reference Imageの「2時間前」のような相対時刻表示。既存displayDate
    /// (絶対日付)とは別に、Home cardのidentity行専用に短い相対表現を作る
    /// (新しいdata sourceは持たず、createdAtから都度計算するだけ)。
    var relativeTimeText: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "たった今" }
        if minutes < 60 { return "\(minutes)分前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)時間前" }
        let days = hours / 24
        return "\(days)日前"
    }
}

// MARK: - Shared color tokens

/// v8.2 ICON PALETTE ALIGNMENT: 新AppIcon(黒背景+柔らかいLavenderの発光する
/// 2つのpebble)から実測抽出したbrand accent。旧`PictriDarkTheme.accent`
/// (terracotta 0xD97757)はMap等アプリ全体で使われているため危険な一括置換は
/// せず、Home専用のこのtokenだけを新設して、Home内でterracottaが使われて
/// いた箇所(Like active / Pagination active dot / Camera Lens / Hero Bezel
/// 右辺反射 / Wordmark / Notification dot)を個別に置き換える。
///
/// 3候補をiPhone 17 Pro Darkで比較した:
/// A) ICON DIRECT #C28BE1 — アイコンから実測したLavenderをそのまま使用。
///    Camera Lensで見ると彩度が高く、やや「pink-magentaの発光ボタン」に
///    寄って見えた。
/// B) MUTED LAVENDER #C093D9(彩度-18%) — Aよりは落ち着いたが、Camera
///    Lensのハイライトが依然「均一に光るlavenderの円盤」に見え、A/Bを
///    並べてもズームすると差がほぼ分からなかった。
/// C) LAVENDER + PEARL(採用) — PrimaryはB、Camera Lensの中心ハイライトを
///    Cool Pearl(#EDEAF5、アイコンの白いhighlightに由来)に変更。実写真で
///    A/Bと並べると、レンズが「均一発光」から「中心に光を受けた半透明の
///    lens」へ明確に変わり、狙い通り「黒いDockにはめ込まれたLavender
///    Lens」に見えたため採用した(Wordmark/Like/Pagination/Bezel反射は
///    Bと同じMuted Lavenderのまま)。
enum PictriHomeBrandAccent {
    /// Primary。Like active / Pagination active dot / Wordmark / Notification
    /// dot / Camera Lens本体色に使う、Muted Lavender。
    static let accent = Color(red: 192 / 255, green: 147 / 255, blue: 217 / 255)
    /// 光が当たる箇所専用のCool Pearl(アイコンの白いhighlightに由来)。
    /// 巨大な発光には使わず、Camera Lensの中心やBezel左上等、狭い範囲のみ。
    static let pearl = Color(red: 237 / 255, green: 234 / 255, blue: 245 / 255)
    /// Accent地の上に乗せる文字・glyph用。Lavenderは中間輝度のため、
    /// 旧`PictriDarkTheme.onAccent`と同じ暗いinkでAA相当のコントラストを保つ。
    static let onAccent = Color(red: 26 / 255, green: 19 / 255, blue: 16 / 255)
}

enum PictriHomeCardTheme {
    /// v8: 26→24。CardをHeroとしてさらに拡大した際、26のままだと角が
    /// 「アプリアイコン的」に丸すぎて見えたため、写真としてのproportionに
    /// 近い24へわずかに絞った(22/24/26を比較、24採用の詳細は最終報告)。
    static let cornerRadius: CGFloat = 24
    /// v9: 34→24、opacity0.5のまま、y26→16。「Depthであり、巨大なblur
    /// shadowではない」という要求に合わせ、広がりと落下距離を絞った。
    static var ambientShadow: Color { Color.black.opacity(0.5) }
    static var contactShadow: Color { Color.black.opacity(0.6) }
    static var placeholderTop: Color { PictriDarkTheme.surfaceRaised }
    static var placeholderBottom: Color { PictriDarkTheme.surfaceOverlay }
}
