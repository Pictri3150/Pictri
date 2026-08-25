import SwiftUI
import UIKit

// MARK: - Pictri Memory Flip Card
//
// Product Concept(Memory Flip Phase): Pictriの1 Memoryは「2枚の別写真」ではなく
// 「1つの思い出の表と裏」。表 = その場所、裏 = そのときの自分。
//
// Phase A監査で判明した重要事実: 保存写真(QuestMemoryPhoto.imageName)は
// QuestDualPhotoComposer.composeによる「外カメラ+内カメラinset」の合成1枚であり、
// insetの下の外カメラ画素は上書きされ復元不可能(=表に人物insetが写り込んだまま
// では「場所だけ」が成立しない)。そのためCameraView保存時にcompose前の生画像も
// outerOnlyImageName/selfieImageNameとして追加保存するよう変更した
// (QuestMemoryStore.swift参照)。本コンポーネントはfront/backそれぞれ「どの画像を
// 使うべきか」を一切知らず、呼び出し側(MemoriesView)がSource of Truthの優先順位
// (新規=生画像優先、旧Memory=composite/cropへgraceful fallback)を解決した結果の
// UIImage?を渡されるだけの、純粋な表示・flipコンポーネントに徹する。
//
// Physical Print化(Memory Flip B→A Polish): Claude Design Final Handoffの
// Photography節「raised-paper padding 3-6, radius outer4/image3, print shadow
// (2層), rotation ≤1°」を、既存の共有トークン(PictriFinalTheme)へ1:1でマップする。
// タップで裏返る。曜日タブ・大きな説明文は使わない。曜日アクセントラインは
// このPhaseで撤去した(理由は後述PictriWeekdayAccent削除コメント相当、日付文字列
// 自体が既に曜日を含むため独立した線は情報の重複でしかなく、紙の質感という
// 「本当のモチーフ」と競合するノイズと判断した)。
struct PictriMemoryFlipCard: View {
    let frontImage: UIImage?
    let backImage: UIImage?
    /// 写真部分だけに適用するaspect ratio(footer bandの高さはこの比率の計算に
    /// 含めない)。カード全体ではなく写真層だけに閉じたmodifierとして持たせる
    /// (以前、外側からaspectRatioを掛けてfooterごと画面外へ押し出したレイアウト
    /// バグの再発防止)。
    let photoAspectRatio: CGFloat
    /// カード外枠の角丸。写真そのものの角丸(photoCornerRadius)はこれよりわずかに
    /// 小さい値を内部で算出し、「紙の外枠 > 写真の内枠」というprintらしい階層を作る
    /// (Design Tokens「Photo print | 5 (outer 4, image 3)」)。
    let cornerRadius: CGFloat
    /// nilなら footer bandを一切出さない(Prefecture Memoriesの72px prints等、
    /// 小さすぎて文字を乗せるとうるさくなる場所向け)。
    var footer: Footer?
    /// 写真まわりの「紙のふち」の太さ。Design Tokens「raised-paper padding 3-6」。
    /// 大きいカード(hero)ほど太く、小さいカード(grid)ほど細く、呼び出し側が渡す。
    var printMargin: CGFloat = 5
    /// カード全体の非常に微細な傾き(度)。0なら傾けない。Grid側は仕様上
    /// 「no rotation」のため常に0を渡すこと(PlaceMemoryGrid制約)。Heroのみ、
    /// 呼び出し側が固定値(乱数ではない)を渡す。
    var rotationDegrees: Double = 0
    /// 写真部分の高さ上限。初期viewport内にfooterが収まるよう、呼び出し側が
    /// GeometryReaderで算出したスクリーン残り高さから逆算して渡す(UIScreen.main
    /// 依存を避けるため、この値は常に呼び出し側から注入される)。nilなら無制限
    /// (=写真の横幅から自然に高さが決まる、from Gridなど元々小さいケース向け)。
    var maxPhotoHeight: CGFloat? = nil
    /// 初期表示を裏面にしたい場合のみtrueを渡す(既定はfalse=表始まり、実際の
    /// タップ導線には影響しない)。DEBUG QAスクショ専用。
    var startsFlippedForDebug: Bool = false

    @State private var isFlipped: Bool
    @State private var showFront: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Footer {
        let placeName: String
        let dateText: String
        /// nilならVlog導線を出さない(その日のVlogが成立しない場合等)。
        let vlogAction: (() -> Void)?
    }

    init(
        frontImage: UIImage?,
        backImage: UIImage?,
        photoAspectRatio: CGFloat,
        cornerRadius: CGFloat,
        footer: Footer?,
        printMargin: CGFloat = 5,
        rotationDegrees: Double = 0,
        maxPhotoHeight: CGFloat? = nil,
        startsFlippedForDebug: Bool = false
    ) {
        self.frontImage = frontImage
        self.backImage = backImage
        self.photoAspectRatio = photoAspectRatio
        self.cornerRadius = cornerRadius
        self.footer = footer
        self.printMargin = printMargin
        self.rotationDegrees = rotationDegrees
        self.maxPhotoHeight = maxPhotoHeight
        self.startsFlippedForDebug = startsFlippedForDebug
        _isFlipped = State(initialValue: startsFlippedForDebug)
        _showFront = State(initialValue: !startsFlippedForDebug)
    }

    private var flipDuration: Double { reduceMotion ? 0.001 : 0.42 }
    private var photoCornerRadius: CGFloat { max(cornerRadius - 2, 2) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if showFront {
                    photoLayer(frontImage).transition(.opacity)
                } else {
                    photoLayer(backImage).transition(.opacity)
                }
            }
            // contentMode: .fitでなければならない(ScrollView内は親からの高さ提案が
            // 無制限=infiniteなため)。.frame(maxHeight:)をaspectRatioの外側
            // (=後、モディファイアチェーン上でより外)に置くことで、aspectRatioが
            // 「幅だけでなく高さも有限」な提案を受け取れるようにし、必要な時だけ
            // 幅方向にも縮む(=写真の存在感を保ちながらfooterを初期viewportへ収める)。
            .aspectRatio(photoAspectRatio, contentMode: .fit)
            .frame(maxHeight: maxPhotoHeight ?? .infinity)
            .clipShape(RoundedRectangle(cornerRadius: photoCornerRadius, style: .continuous))
            .padding(printMargin)
            .contentShape(Rectangle())
            .onTapGesture { flip() }

            if let footer {
                footerBand(footer)
            }
        }
        // カード全体(写真+footer)を1つの剛体として回転させる180°地点では、
        // 何も補正しないと裏面コンテンツ自体が鏡像(左右反転)で表示されてしまう
        // (実機検証で発覚: 場所名・日付・Vlogリンクの文字が反転して見えた)。
        // 裏面表示中(showFront=false)はコンテンツ側へあらかじめ+180°の逆回転を
        // 掛けておき、外側の連続flipアニメーションのisFlipped=180°と合成させて
        // 360°(=0°と等価)に相殺することで、静止時は常に正しい向きで読める
        // ようにする(トランプの裏表が常に正しく読めるのと同じ仕組み)。
        // Reduce Motion時は外側の回転自体を出さない(0°固定)ため、この逆回転も
        // 合わせて0°固定にしないと、外側なし・内側だけ180°で鏡像化してしまう。
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (showFront ? 0 : 180)),
            axis: (x: 0, y: 1, z: 0)
        )
        .background(PictriFinalTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(PictriFinalTheme.line, lineWidth: 1)
        }
        // 「同じ物体が裏返る」ように見せるため、flipは写真だけでなく紙全体
        // (写真+footer)を1つの剛体として回転させる。写真だけが独立して回転し
        // footerが静止したままだと、印刷物というより「デジタルなカードめくり
        // ギミック」に見えてしまうため、Physical Print化にあたりこの階層へ
        // 移動した。
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : (isFlipped ? 180 : 0)),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotationEffect(.degrees(rotationDegrees))
        // Design Tokens print shadow(2層): 「0 1px 0 rgba(...,.08)」の紙が
        // 接地する極薄いラインと、「0 8px 16px -12px rgba(...,.28)」の柔らかい
        // 持ち上がりを、SwiftUIのshadowを2回重ねて近似する。
        // shadowは常にPictriDarkTheme.shadowColor(常に黒ベース)を参照する。
        .shadow(color: PictriDarkTheme.shadowColor.opacity(0.6), radius: 0.5, x: 0, y: 1)
        .shadow(color: PictriDarkTheme.shadowColor, radius: 9, x: 0, y: 6)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(showFront ? "写真、タップで裏を見る" : "写真の裏、タップで表に戻る")
    }

    @ViewBuilder
    private func photoLayer(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            PictriFinalTheme.dormant
        }
    }

    private func footerBand(_ footer: Footer) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(footer.placeName)
                .font(PictriTypography.body(12, weight: .bold))
                .foregroundStyle(PictriFinalTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            if !showFront, let vlogAction = footer.vlogAction {
                Button(action: vlogAction) {
                    HStack(spacing: 3) {
                        Text("その日のVlogへ")
                        Image(systemName: "arrow.right")
                    }
                    .font(PictriTypography.mono(10, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)
                }
                // Vlogリンクだけは独立したButtonとして存在し、親のonTapGesture(flip)
                // より優先させる。footer内で明示的にヒット領域を空間分割する案も
                // 検討したが、HStack内の1要素だけ「親のタップ領域から除外する」
                // レイアウトはDynamic Type時の折返しに弱く、かえって壊れやすい。
                // highPriorityGestureはAppleが「子が親のジェスチャーに勝つ」ケース
                // 向けに用意した標準機構であり、これ以上UIを複雑にしてまで別の
                // 構造へ置き換える方が安全性で劣ると判断し、この方式を維持した。
                .highPriorityGesture(TapGesture().onEnded { vlogAction() })
            }

            Text(footer.dateText)
                .font(PictriTypography.mono(11, weight: .regular))
                .foregroundStyle(PictriFinalTheme.inkFaint)
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onTapGesture { flip() }
    }

    private func flip() {
        if reduceMotion {
            // Reduce Motion時は3D回転を使わず、控えめなフェードだけで面を入れ替える。
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
