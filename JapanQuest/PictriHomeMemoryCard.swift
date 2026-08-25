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

    private var flipDuration: Double { reduceMotion ? 0.001 : 0.5 }

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

            topScrim
            bottomScrim

            identityRow
                .padding(.horizontal, 14)
                .padding(.top, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous))
        // v8 REFERENCE FIDELITY BEZEL: 3候補を17 Pro Dark実写真で比較した。
        // A) CURRENT RESTRAINED — 縦方向LinearGradientの2.4pt stroke(旧実装)。
        //    厚みは出たが全周で明暗差が単調で、Referenceの「光源方向が
        //    感じられる」質感には届かなかった。
        // B) REFERENCE FIDELITY(採用) — AngularGradientで
        //    top-left champagne highlight → right warm terracotta reflection →
        //    bottom dark thickness → left neutral hairlineという方向性のある
        //    光を作り、lineWidthも3.6ptへ拡大。実写真で見るとCurrentより
        //    明確に「額縁」の物体感が出て、Referenceに最も近づいた。
        // C) REFERENCE FIDELITY -15% — Bの各stop opacityとlineWidthを
        //    約15%落とした版。悪くはないがBと並べると差が小さく、
        //    「怖がって弱くしすぎない」という方針とBの実写真での説得力を
        //    踏まえてBを採用した。
        // 内側にはpaper-thickness用の2層(neutral hairline+dark stroke)を
        // 追加し、額縁の断面のような厚みを表現している。
        .overlay {
            RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        stops: [
                            .init(color: PictriHomeCardTheme.bezelHighlight, location: 0.0),
                            .init(color: Color.white.opacity(0.30), location: 0.08),
                            .init(color: PictriHomeCardTheme.bezelWarm.opacity(0.85), location: 0.22),
                            .init(color: PictriHomeCardTheme.bezelWarm.opacity(0.20), location: 0.34),
                            .init(color: Color.black.opacity(0.42), location: 0.52),
                            .init(color: Color.black.opacity(0.30), location: 0.68),
                            .init(color: Color.white.opacity(0.14), location: 0.85),
                            .init(color: PictriHomeCardTheme.bezelHighlight, location: 1.0)
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    lineWidth: 3.6
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius - 3.6, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                .padding(3.6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius - 4.6, style: .continuous)
                .strokeBorder(Color.black.opacity(0.26), lineWidth: 1)
                .padding(4.6)
        }
        // 裏面表示中は内容へあらかじめ+180°の逆回転を掛け、外側の連続flip
        // (isFlipped)と合成させて鏡像化を防ぐ(PictriMemoryFlipCardで
        // 確立済みの手法をそのまま踏襲)。
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (showFront ? 0 : 180)),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(outerFlipDegrees),
            axis: (x: 0, y: 1, z: 0)
        )
        .shadow(color: PictriHomeCardTheme.ambientShadow, radius: 34, x: 0, y: 26)
        .shadow(color: PictriHomeCardTheme.contactShadow, radius: 6, x: 0, y: 4)
        // Referenceの「発光ではなく、光を纏っている」空気感。中心から均等に
        // 広がる非常に弱いwarm glowで、方向性を持たせない(方向を持たせると
        // 「orangeのdrop shadow」に見え、禁止されているneon glowに近づく)。
        .shadow(color: PictriDarkTheme.accent.opacity(0.14), radius: 20, x: 0, y: 0)
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

    @ViewBuilder
    private func photoLayer(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [PictriHomeCardTheme.placeholderTop, PictriHomeCardTheme.placeholderBottom],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    /// capsule背景を廃し、avatar+文字を直接scrimの上に乗せる(参考画像の
    /// 一体感を踏襲)。
    private var identityRow: some View {
        Button(action: onProfileTap) {
            HStack(spacing: 9) {
                Circle()
                    .fill(HomeFriendColor.accent(for: post.username).opacity(0.94))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    }
                    .overlay {
                        Text(String(post.username.prefix(1)).uppercased())
                            .font(PictriTypography.body(12, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.72))
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.username)
                        .font(PictriTypography.body(13.5, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    Text(post.relativeTimeText)
                        .font(PictriTypography.mono(10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
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
            withAnimation(.easeInOut(duration: 0.2)) {
                showFront.toggle()
            }
            isFlipped.toggle()
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

enum PictriHomeCardTheme {
    /// v8: 26→24。CardをHeroとしてさらに拡大した際、26のままだと角が
    /// 「アプリアイコン的」に丸すぎて見えたため、写真としてのproportionに
    /// 近い24へわずかに絞った(22/24/26を比較、24採用の詳細は最終報告)。
    static let cornerRadius: CGFloat = 24
    static var ambientShadow: Color { Color.black.opacity(0.5) }
    static var contactShadow: Color { Color.black.opacity(0.6) }
    static var placeholderTop: Color { PictriDarkTheme.surfaceRaised }
    static var placeholderBottom: Color { PictriDarkTheme.surfaceOverlay }
    /// v8 PHYSICAL PHOTOGRAPHY BEZEL用トークン。
    static var bezelHighlight: Color { Color.white.opacity(0.85) }
    static var bezelWarm: Color { PictriDarkTheme.accent }
}
