import SwiftUI

// MARK: - PicTri Opening — Peel Reveal Rebuild(2026-08-23)
//
// ユーザーからの新しい明示的方針: 中核メカニクスを「crack(亀裂)」から
// 「peel(めくれ/剥離)」へ転換する。5段階(Foundation → Typography Emergence →
// Peel/Reveal Mechanics → Cinematic Polish → Final Reality Check)で作り直す。
//
// 既存の`PictriOpeningSignatureLab.swift`にある共有部品(`SignatureAssemblyGlyph`
// `makeSignatureFragments`/`signatureFragmentTransform`/`PictriSignatureEasing`/
// `PictriSignatureReducedFallback`)は文字出現(typography)の土台として引き続き
// 再利用する。今回新設するのは reveal(Home露出)を「crack mask」から
// 「1枚の面がめくれる」構造へ置き換える部分。

// MARK: - Phase 1/4: 共有Peel Opening Engine
//
// typography(文字出現)とrevealWrapper(露出メカニクス)を差し替え可能にした
// 骨格。Phase 2ではrevealを固定してtypographyを3案比較し、Phase 3では
// typographyを固定してrevealを3案比較する。
struct PictriPeelOpeningEngine: View {
    var onComplete: () -> Void

    let assemblyBaseDelay: Double
    let revealStart: Double
    let revealDuration: Double
    let totalDuration: Double

    /// fragElapsed(=elapsed - assemblyBaseDelay) → 文字(背景を含まない)のView。
    let typography: (Double) -> AnyView
    /// (背景+文字を含む1枚のcontent, revealProgress 0...1, 画面サイズ) → 露出後のView。
    let revealWrapper: (AnyView, Double, CGSize) -> AnyView

    @State private var hasStarted = false
    // 起動直後、実際にこのViewが可視化されるまでの待機時間をアニメーションの
    // elapsedへ混入させないため、`.task`が走り出した瞬間に`Date()`を取得する
    // (Signature Labフェーズで発見・修正済みのパターンを踏襲)。
    @State private var startDate: Date?

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
                let fragElapsed = max(0, elapsed - assemblyBaseDelay)
                let content = AnyView(
                    ZStack {
                        PictriDarkTheme.openingSurface
                        typography(fragElapsed)
                    }
                )
                let revealProgress = revealDuration > 0
                    ? min(max((elapsed - revealStart) / revealDuration, 0), 1)
                    : 0
                revealWrapper(content, revealProgress, geo.size)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            startDate = Date()
            try? await Task.sleep(for: .seconds(totalDuration))
            onComplete()
        }
    }
}

private let peelCanvasSize = CGSize(width: 300, height: 108)
private let peelWordmarkFont: CGFloat = 46

// MARK: - Phase 3: Peel Reveal(本命)
//
// 画面全体を1枚の印画紙/マット面と見立て、下端から上端へ向かって"めくれる"
// ことでHomeを露出する。めくれの最前線(front)のすぐ上、まだ完全には
// 剥がれきっていない帯(band)だけを一定角度で3D回転させ、「巻き上がって
// 浮き上がる」質感を出す。帯の下にはHome側へ落ちる柔らかい影を添える。
// crack maskのような分岐・亀裂は一切使わない — 単一の面が単一の方向へ
// 静かにめくれるだけ、という単純さを保つ。
func pictriPeelRevealWrapper(content: AnyView, progress: Double, size: CGSize) -> AnyView {
    let bandHeight: CGFloat = min(72, size.height * 0.05)
    let eased = PictriSignatureEasing.crackPropagation(progress) // 名前は流用だが「slow→rapid→soft」カーブとして再利用
    let frontY = size.height * (1 - eased)
    let flatHeight = max(0, frontY - bandHeight)

    return AnyView(
        ZStack(alignment: .top) {
            // まだ平らな残存面(これから剥がれる部分)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .mask(
                    Rectangle()
                        .frame(width: size.width, height: flatHeight)
                        .position(x: size.width / 2, y: flatHeight / 2)
                )

            if progress > 0.001 && progress < 0.999 {
                // めくれている帯: 上端(flatHeight側)がまだ面に接しており、
                // 下端(frontY側)が今まさに浮き上がって巻き上がる。
                ZStack(alignment: .bottom) {
                    content
                        .frame(width: size.width, height: size.height, alignment: .top)
                        .offset(y: -flatHeight)
                        .frame(width: size.width, height: bandHeight, alignment: .top)
                        .clipped()

                    // 巻き上がった縁に光が当たる、ごく控えめなハイライト
                    // (matte印画紙が湾曲することで生まれる質感の補助線)。
                    LinearGradient(
                        colors: [PictriDarkTheme.openingTextPrimary.opacity(0.16), Color.clear],
                        startPoint: .bottom, endPoint: .top
                    )
                    .frame(width: size.width, height: bandHeight * 0.5)
                }
                .rotation3DEffect(
                    .degrees(76), axis: (x: 1, y: 0, z: 0),
                    anchor: .top, anchorZ: 0, perspective: 0.5
                )
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
                .position(x: size.width / 2, y: flatHeight + bandHeight / 2)

                // 帯のすぐ下、Home側へ落ちる柔らかい影(浮き上がった質感の補助)。
                LinearGradient(
                    colors: [Color.black.opacity(0.28), Color.black.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: size.width, height: 44)
                .position(x: size.width / 2, y: frontY + 22)
                .allowsHitTesting(false)
            }
        }
    )
}

// MARK: - CINEMATIC PEEL FINALIZATION: Peel Method A(Segmented 3D Curl)
//
// 前回の単一band(1本だけ76°回転)は「maskで消えている」ように見える危険が
// あった。今回は巻き取りゾーンを複数の薄いstripへ分割し、付け根(まだ平らな
// 面に近い側)から先端(今まさに抜けていく側)へ向けて回転角を段階的に増やす
// ことで、直線的な蝶番ではなく連続した曲率を持つ弧(curl)として見せる。
// 先端に近いstripほどbrightnessを落とし(巻き込まれた裏側が暗く見える光の
// 回り込みを近似)、curl全体を1つの物体として一貫させる。
func pictriSegmentedCurlRevealWrapper(content: AnyView, progress: Double, size: CGSize) -> AnyView {
    let eased = PictriSignatureEasing.crackPropagation(progress)
    let frontY = size.height * (1 - eased)

    // 巻き取りゾーンの高さ: 開始時は非常に小さく、素早く基準サイズまで育ち、
    // 終盤はfrontYが縮むにつれ自然に小さくなって画面外へ抜けていく
    // (「開始時: 非常に小さなcurl / 中盤: 最大曲率 / 終盤: 自然に抜ける」)。
    let baseCurlZone: CGFloat = min(104, size.height * 0.095)
    let rampT = min(1, eased / 0.14)
    let curlZoneHeight = min(baseCurlZone * rampT, frontY)
    let flatHeight = max(0, frontY - curlZoneHeight)

    // 注記: 当初5分割で試作したところ、各stripの回転角が90°に近づくにつれ
    // 投影後の見かけの高さが急激に縮む(foreshortening)一方、隣接stripの
    // 中心Y位置の間隔は変わらないため、実機相当の録画で明確な帯状の継ぎ目
    // (seam)が視認された。continuous curveの近似としては破綻had。
    // 2分割・大きめのoverlapへ縮小し、継ぎ目が出ないことを録画で確認して
    // 採用している。
    let stripCount = 2
    let stripHeight = curlZoneHeight / CGFloat(stripCount)
    let overlap: CGFloat = 9 // foreshorteningによる継ぎ目の隙間を防ぐための重なり

    return AnyView(
        ZStack(alignment: .top) {
            // まだ平らな残存面
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .mask(
                    Rectangle()
                        .frame(width: size.width, height: flatHeight)
                        .position(x: size.width / 2, y: flatHeight / 2)
                )

            if progress > 0.001 && progress < 0.999 && curlZoneHeight > 1 {
                ForEach(0..<stripCount, id: \.self) { i in
                    let stripTopY = flatHeight + CGFloat(i) * stripHeight
                    // 0(付け根、まだほぼ平ら)...1(先端、抜けていく直前)
                    let localT = (Double(i) + 0.5) / Double(stripCount)
                    // 90°付近はforeshorteningが急峻になり継ぎ目が出やすいため、
                    // 安全域(最大約82°)に収める。
                    let angle = 12.0 + 70.0 * localT
                    let darken = 0.5 * localT

                    // Backface tint: 表(graphite-black)と同じ色のまま巻き上がると
                    // 「一枚の面」という説得力が弱まるため、先端に近いstripほど
                    // わずかにcool-neutral grayを混ぜ、「今は裏側が見えている」
                    // ことを暗示する(白い紙裏にはしない、あくまで表面と地続きの
                    // 素材だと分かる程度に留める)。
                    let backfaceTint = Color(red: 0.20, green: 0.205, blue: 0.215)

                    content
                        .frame(width: size.width, height: size.height, alignment: .top)
                        .offset(y: -stripTopY)
                        .frame(width: size.width, height: stripHeight + overlap, alignment: .top)
                        .clipped()
                        .brightness(-darken)
                        .overlay(backfaceTint.opacity(0.32 * localT))
                        .rotation3DEffect(
                            .degrees(angle), axis: (x: 1, y: 0, z: 0),
                            anchor: .top, anchorZ: 0, perspective: 0.45
                        )
                        .position(x: size.width / 2, y: stripTopY + stripHeight / 2)
                }

                // 曲率が最大になる付近(全stripの中間あたり)だけをなぞる、
                // progressに連動して動く柔らかく幅広いhighlight。静止した
                // gradientにしない(Peel progressで位置と強さが変わる)。
                let highlightY = flatHeight + curlZoneHeight * 0.4
                let highlightOpacity = 0.10 + 0.06 * sin(eased * .pi)
                LinearGradient(
                    colors: [Color.clear, PictriDarkTheme.openingTextPrimary.opacity(highlightOpacity), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: size.width, height: stripHeight * 2.2)
                .position(x: size.width / 2, y: highlightY)
                .allowsHitTesting(false)

                // Contact shadow: curlが持ち上がるほどblur/offsetが増え、
                // 「maskが消えた」のではなく「物体が持ち上がった」ことを伝える。
                let liftT = min(1, eased * 1.25)
                LinearGradient(
                    colors: [Color.black.opacity(0.34), Color.black.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: size.width, height: 28 + 42 * liftT)
                .blur(radius: 2 + 7 * liftT)
                .offset(y: 4 * liftT)
                .position(x: size.width / 2, y: frontY + 14 + 18 * liftT)
                .allowsHitTesting(false)
            }
        }
    )
}

// MARK: - Phase 3比較用: Seam(継ぎ目)Reveal
//
// crack風の"継ぎ目"が画面中央で左右に静かに開き、その隙間からHomeが覗く案。
// 亀裂のような分岐は持たず、単一の直線的な継ぎ目が均等に開くだけ、という
// 簡素な比較対象として実装する。
func pictriSeamRevealWrapper(content: AnyView, progress: Double, size: CGSize) -> AnyView {
    let eased = PictriSignatureEasing.crackPropagation(progress)
    let gap = size.width * 0.55 * eased
    return AnyView(
        ZStack {
            content
                .frame(width: size.width, height: size.height)
                .offset(x: -gap / 2)
                .mask(Rectangle().frame(width: size.width / 2, height: size.height).offset(x: -size.width / 4))
            content
                .frame(width: size.width, height: size.height)
                .offset(x: gap / 2)
                .mask(Rectangle().frame(width: size.width / 2, height: size.height).offset(x: size.width / 4))
        }
    )
}

// MARK: - Phase 3比較用: Latent Split(潜像の開口)Reveal
//
// 画面中央から柔らかい楕円形の開口がゆっくり広がり、Homeを覗かせる案。
// crackのような線的な要素を一切持たない、もっとも抽象的な比較対象。
func pictriLatentSplitRevealWrapper(content: AnyView, progress: Double, size: CGSize) -> AnyView {
    let eased = PictriSignatureEasing.crackPropagation(progress)
    let diag = sqrt(size.width * size.width + size.height * size.height)
    let radius = diag * 0.75 * eased
    return AnyView(
        content
            .frame(width: size.width, height: size.height)
            .mask(
                Circle()
                    .frame(width: max(0, diag - radius * 2), height: max(0, diag - radius * 2))
                    .position(x: size.width / 2, y: size.height / 2)
            )
    )
}

// MARK: - Phase 2: Typography Emergence 3案

/// A案: Latent Fragments — 断片が静かに収束し、ネガ→ポジ階調で定着する
/// (Signature Labで検証済みの技法を踏襲。もっとも「写真が現れる」感覚が強い)。
func pictriTypographyLatentFragments(elapsed: Double) -> AnyView {
    let fragments = makeSignatureFragments(
        canvasSize: peelCanvasSize, cols: 6, rows: 4,
        seed: 0xFEED01, maxDelay: 0.4, durationRange: 0.4...0.6,
        offsetMagnitude: 9, offsetDirection: signatureOutwardDirection,
        blurRange: 6...13, scaleRange: 1.5...2.2, rotationRange: -3...3
    )
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 0.95, 0), 1))
    let brightness = -0.3 * (1 - t)
    let saturation = 0.25 + 0.75 * t
    let contrast = 1.2 - 0.2 * t
    return AnyView(
        SignatureAssemblyGlyph(
            font: PictriDarkTheme.display(peelWordmarkFont, weight: .regular),
            textColor: PictriDarkTheme.openingTextPrimary,
            canvasSize: peelCanvasSize, fragments: fragments, elapsed: elapsed
        )
        .brightness(brightness)
        .saturation(saturation)
        .contrast(contrast)
    )
}

/// B案: Exposure Bloom — 断片を一切使わず、光と陰影(blur+contrast+opacity)
/// だけで文字が面として浮かび上がる。もっとも静かで、もっとも「印画紙の
/// 露光」に近いモチーフ。
func pictriTypographyExposureBloom(elapsed: Double) -> AnyView {
    let t = min(max(elapsed / 1.05, 0), 1)
    let eased = PictriSignatureEasing.fragmentSettle(t)
    let blur = 14 * (1 - eased)
    let opacity = min(1, elapsed / 0.25)
    let contrast = 0.3 + 0.7 * eased
    return AnyView(
        Text("PicTri")
            .font(PictriDarkTheme.display(peelWordmarkFont, weight: .regular))
            .foregroundStyle(PictriDarkTheme.openingTextPrimary)
            .blur(radius: blur)
            .opacity(opacity)
            .contrast(contrast)
    )
}

/// C案: Block Assembly — 断片より少なく・大きい「版(はん)」が、それぞれ
/// 異なる奥行きから届いてロックする。letterpress plateを思わせる、より
/// 存在感のある構築感。
func pictriTypographyBlockAssembly(elapsed: Double) -> AnyView {
    let fragments = makeSignatureFragments(
        canvasSize: peelCanvasSize, cols: 3, rows: 2,
        seed: 0xB10CC, maxDelay: 0.45, durationRange: 0.35...0.55,
        offsetMagnitude: 26, offsetDirection: signatureOutwardDirection,
        blurRange: 2...6, scaleRange: 1.1...1.3, rotationRange: -4...4
    )
    return AnyView(
        SignatureAssemblyGlyph(
            font: PictriDarkTheme.display(peelWordmarkFont, weight: .regular),
            textColor: PictriDarkTheme.openingTextPrimary,
            canvasSize: peelCanvasSize, fragments: fragments, elapsed: elapsed
        )
    )
}

// MARK: - CINEMATIC PEEL FINALIZATION(2026-08-23、続きのラウンド)
//
// 前回81/100の弱点再定義: (A) curlの立体感が弱い (B) maskで消えているように見える
// 危険 (C) 状態変化が静かすぎる (D) paper peelが一般的すぎる (E) PicTri文字の出現が
// 「組み立てアニメ」に見える複雑さを持っている。
//
// 今回はTypographyの主役を「断片が組み上がること」から外す。fragmentを内部技術
// として使うかどうかに関わらず、ユーザーからは分割が見えないことを最優先する。

/// A案: DEPTH EMERGENCE — 文字は最初から1枚のまま空間内に存在し、
/// blur・低contrast・わずかなscaleから焦点が合うように定着する。
/// fragment/tileを一切使わない、もっとも単純な案。
func pictriTypographyDepthEmergence(elapsed: Double) -> AnyView {
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 0.95, 0), 1))
    let blur = 9 * (1 - t)
    let scale = 1.05 - 0.05 * t
    let contrast = 0.45 + 0.55 * t
    let opacity = min(1, elapsed / 0.3)
    return AnyView(
        Text("PicTri")
            .font(PictriDarkTheme.display(peelWordmarkFont, weight: .regular))
            .foregroundStyle(PictriDarkTheme.openingTextPrimary)
            .scaleEffect(scale)
            .blur(radius: blur)
            .contrast(contrast)
            .opacity(opacity)
    )
}

/// B案: LATENT IMAGE — 写真の潜像のように、暗闇の中からごく微細な階調だけで
/// 文字が浮かぶ。opacityは早々に上がりきるが、contrastが非常にゆっくり
/// 立ち上がるため、途中まで「そこに何かがあるが読めない」状態が続く。
func pictriTypographyLatentImage(elapsed: Double) -> AnyView {
    let opacity = min(1, elapsed / 0.2)
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 1.05, 0), 1))
    let contrast = 0.12 + 0.88 * t
    let blur = 4 * (1 - t)
    let brightness = -0.12 * (1 - t)
    return AnyView(
        Text("PicTri")
            .font(PictriDarkTheme.display(peelWordmarkFont, weight: .regular))
            .foregroundStyle(PictriDarkTheme.openingTextPrimary)
            .blur(radius: blur)
            .contrast(contrast)
            .brightness(brightness)
            .opacity(opacity)
    )
}

/// C案: SOFT MATERIAL REVEAL — 文字がsurfaceにエンボスされているように、
/// 陰影側(暗)と光側(明)の2枚をわずかにoffsetして重ね、それが収束しながら
/// 1枚のivory文字へ定着する。光と陰影だけで立体感を作る案。
func pictriTypographySoftMaterialReveal(elapsed: Double) -> AnyView {
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 1.0, 0), 1))
    let embossOffset: CGFloat = 3 * (1 - t)
    let opacity = min(1, elapsed / 0.35)
    let font = PictriDarkTheme.display(peelWordmarkFont, weight: .regular)
    return AnyView(
        ZStack {
            Text("PicTri").font(font)
                .foregroundStyle(Color.black.opacity(0.5))
                .offset(x: -embossOffset, y: -embossOffset)
                .blur(radius: 1.5 * (1 - t))
            Text("PicTri").font(font)
                .foregroundStyle(PictriDarkTheme.openingTextPrimary.opacity(0.7))
                .offset(x: embossOffset, y: embossOffset)
                .blur(radius: 1.5 * (1 - t))
            Text("PicTri").font(font)
                .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                .opacity(t)
        }
        .opacity(opacity)
    )
}

/// Latent ImageにSurface Tension(めくれ開始直前のごく短い緊張の合図)を
/// 加えた最終版。画面全体ではなくglyphのみへ適用するため、過去に発覚した
/// 全画面フラッシュ事故を再発させない。
func pictriTypographyLatentImageFinal(elapsed: Double) -> AnyView {
    let opacity = min(1, elapsed / 0.2)
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 1.05, 0), 1))
    var contrast = 0.12 + 0.88 * t
    let blur = 4 * (1 - t)
    var brightness = -0.12 * (1 - t)

    // Surface Tension: 静止の終わり際(めくれが始まる直前)にごく短い山形の
    // パルスを重ねる。「面が一度static holdへ達し、その直後に開く」という
    // 状態変化の節目を作る(Dynamic Qualityの補強)。
    let tensionLocal = min(max((elapsed - 1.35) / 0.3, 0), 1)
    let tensionPulse = sin(tensionLocal * .pi)
    contrast += 0.08 * tensionPulse
    brightness += 0.04 * tensionPulse

    return AnyView(
        Text("PicTri")
            .font(PictriDarkTheme.display(peelWordmarkFont, weight: .regular))
            .foregroundStyle(PictriDarkTheme.openingTextPrimary)
            .blur(radius: blur)
            .contrast(contrast)
            .brightness(brightness)
            .opacity(opacity)
    )
}

/// Cinematic Peel Finalizationで確定した本番concept。
/// Typography = Latent Image(潜像)、Reveal = Segmented Curl(2分割の
/// 曲率近似+backface tint+curvature連動highlight+contact shadow)。
/// タイミング内訳(内部経過秒): 暗黒0.00-0.45 → PicTri emergence 0.45-1.35 →
/// focus lock 1.35-1.60 → 静止1.60-2.05(surface tensionのpulseを含む) →
/// peel 2.05-3.35(1.3秒) → 余韻0.15秒 → 完了(合計3.5秒、推奨T2=3.6秒相当)。
struct PictriPeelConceptCinematicFinal: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.45, revealStart: 2.05, revealDuration: 1.3, totalDuration: 3.5,
                typography: pictriTypographyLatentImageFinal,
                revealWrapper: pictriSegmentedCurlRevealWrapper
            )
        }
    }
}

// MARK: - IMAGE-FIRST IMPLEMENTATION(2026-08-23、続きのラウンド)
//
// Visual Source of Truth: /Users/takakikeita/Desktop/pictriimageopening.png
// (6-panel storyboard、実測結果は /tmp/pictri_opening_reference_match/
// REFERENCE_GEOMETRY.md 等を参照)。
//
// 最重要の発見: (1) wordmarkは寒色ivoryではなく暖色gold(#D6C79A)の
// engraved-metal表現。(2) Peelは水平ではなく、右下から左上へ向かう
// 対角線状のcorner peel(front lineは実測で約135°、真の45°対角線)。
// これらはHOME側の見た目(reference画像内のmockup Home)とは無関係の、
// Opening surface自体の特徴としてのみ抽出している。

enum PictriReferenceColors {
    static let deepGraphite = Color(red: 0x08 / 255, green: 0x08 / 255, blue: 0x0D / 255)
    static let charcoal = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x16 / 255)
    static let softGold = Color(red: 0xD6 / 255, green: 0xC7 / 255, blue: 0x9A / 255)
    static let paperEdge = Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x2D / 255)
}

/// Reference準拠のwordmark: engraved-metal(暖色gold、上左highlight+下右shadowの
/// 2重offsetでエンボス感)。出現は単純なblur/opacityではなく、
/// 「粒状のnoiseから解像していく」印象を、非対称(左"Pic"が右"Tri"よりわずかに
/// 遅れて定着する)なcontrast/opacityの立ち上がりで近似する。
func pictriTypographyReferenceGold(elapsed: Double) -> AnyView {
    let font = PictriDarkTheme.display(peelWordmarkFont, weight: .regular)
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 1.05, 0), 1))
    let opacity = min(1, elapsed / 0.35)
    let contrast = 0.35 + 0.65 * t
    let blur = 2.2 * (1 - t)

    // Emergence時の非対称性: "Pic"側がわずかに遅れて解像する
    // (reference panel 02で観察された、左側が粒状ノイズに埋もれ気味の状態)。
    let leftT = PictriSignatureEasing.fragmentSettle(min(max((elapsed - 0.08) / 1.05, 0), 1))

    return AnyView(
        ZStack {
            // 柔らかい暖色vignette glow(wordmarkの背後、Formed直前から強まる)
            RadialGradient(
                colors: [PictriReferenceColors.softGold.opacity(0.16 * t), Color.clear],
                center: .center, startRadius: 4, endRadius: 130
            )
            .frame(width: 260, height: 200)

            ZStack {
                // 下右shadow(彫り込みの陰影側)
                Text("PicTri").font(font)
                    .foregroundStyle(Color.black.opacity(0.55))
                    .offset(x: 1.1, y: 1.6)
                // 上左highlight(彫り込みの光側)
                Text("PicTri").font(font)
                    .foregroundStyle(PictriReferenceColors.softGold.opacity(0.55))
                    .offset(x: -0.9, y: -1.3)
                // 本体(gold)
                Text("PicTri").font(font)
                    .foregroundStyle(PictriReferenceColors.softGold)
            }
            .blur(radius: blur)
            .contrast(contrast)
            .opacity(opacity)
            .mask(
                HStack(spacing: 0) {
                    Rectangle().opacity(leftT)
                    Rectangle().opacity(t)
                }
            )
        }
    )
}

/// Referenceのcurl silhouetteは直線ではなくorganic S-curve(panel 05で顕著)。
/// front line上の位置sに沿って`amplitude * sin(sNorm * .pi)`という反対称な
/// 単一のS字ぶれを加える(sNorm=±1で0、中央付近で最大)ことで、両端は元の
/// 対角線に一致させたまま中間だけ湾曲させる。amplitudeはeasedで増大させ、
/// 序盤はほぼ直線・終盤ほど湾曲が目立つreferenceの見え方に合わせる。
private struct PictriWavyEdgeMask: Shape {
    var nx: CGFloat
    var ny: CGFloat
    var ux: CGFloat
    var uy: CGFloat
    var center: CGPoint
    var threshold: CGFloat
    var amplitude: CGFloat
    var reach: CGFloat
    var farDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segments = 48
        func edgeValue(_ s: CGFloat) -> CGFloat {
            let sNorm = max(-1, min(1, s / reach))
            return threshold + amplitude * sin(sNorm * .pi)
        }
        func point(_ s: CGFloat) -> CGPoint {
            let v = edgeValue(s)
            return CGPoint(x: center.x + nx * v + ux * s, y: center.y + ny * v + uy * s)
        }
        let start = point(-reach)
        path.move(to: start)
        for i in 1...segments {
            let s = -reach + reach * 2 * CGFloat(i) / CGFloat(segments)
            path.addLine(to: point(s))
        }
        let farEnd = point(reach)
        path.addLine(to: CGPoint(x: farEnd.x - nx * farDepth, y: farEnd.y - ny * farDepth))
        path.addLine(to: CGPoint(x: start.x - nx * farDepth, y: start.y - ny * farDepth))
        path.closeSubpath()
        return path
    }
}

/// curl band自体もwavyな2本の縁(outer/inner)で囲んだリング状に描く。
private struct PictriWavyBandMask: Shape {
    var nx: CGFloat
    var ny: CGFloat
    var ux: CGFloat
    var uy: CGFloat
    var center: CGPoint
    var nearEdge: CGFloat
    var bandDepth: CGFloat
    var amplitude: CGFloat
    var reach: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segments = 48
        func edgeValue(_ s: CGFloat, _ base: CGFloat) -> CGFloat {
            let sNorm = max(-1, min(1, s / reach))
            return base + amplitude * sin(sNorm * .pi)
        }
        func point(_ s: CGFloat, _ base: CGFloat) -> CGPoint {
            let v = edgeValue(s, base)
            return CGPoint(x: center.x + nx * v + ux * s, y: center.y + ny * v + uy * s)
        }
        let farEdge = nearEdge - bandDepth
        path.move(to: point(-reach, nearEdge))
        for i in 1...segments {
            let s = -reach + reach * 2 * CGFloat(i) / CGFloat(segments)
            path.addLine(to: point(s, nearEdge))
        }
        for i in stride(from: segments, through: 0, by: -1) {
            let s = -reach + reach * 2 * CGFloat(i) / CGFloat(segments)
            path.addLine(to: point(s, farEdge))
        }
        path.closeSubpath()
        return path
    }
}

/// Reference準拠のdiagonal corner peel: front lineが右下から左上へ向かう
/// 約135°の対角線として画面を横切る。mask境界・curl bandの回転軸ともに
/// この対角線に沿わせることで、水平/垂直のpeelとは全く異なるsilhouetteを作る。
/// backfaceにはPaper Edge(#2A2A2D)を使用。
func pictriDiagonalCornerPeelWrapper(content: AnyView, progress: Double, size: CGSize) -> AnyView {
    let eased = PictriSignatureEasing.crackPropagation(progress)

    // 対角線の"向き"(front lineに垂直な、まだ剥がれていない側=右下方向への単位ベクトル)。
    // 実測(REFERENCE_GEOMETRY.md)により、front lineは実ピクセル空間で真の45°。
    let nx: CGFloat = 0.7071
    let ny: CGFloat = 0.7071
    // front lineの方向(nに垂直、curlの回転軸として使う)
    let ux: CGFloat = -ny
    let uy: CGFloat = nx

    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    // 対角線方向の"到達距離": 画面中心から見て、四隅のうちn方向(右下)に
    // もっとも遠い点のs値。安全マージンを掛け、progress=0の時点で
    // 右下角も含め絶対に一切露出しないことを保証する
    // (以前、この値が小さすぎて起動直後から右下角がわずかに露出してしまう
    // 不具合があったため、実測に基づき修正)。
    let halfDiagS = (size.width + size.height) / 2 * 0.7071 * 1.08
    let threshold = halfDiagS - eased * 2 * halfDiagS

    let bandDepth: CGFloat = min(120, size.height * 0.11)
    let hugeSide = halfDiagS * 6
    // S-curve強度: 序盤はほぼ0(直線)、peelが進むほど湾曲が目立つ。
    let waveAmplitude = bandDepth * 1.7 * min(1, eased * 1.3)
    let waveReach = halfDiagS * 1.4

    // 平らな残存面のmask: 対角線(135°)で回転させた巨大矩形。
    // 矩形の"近い側の辺"がちょうどthresholdの位置に来るよう、中心をn方向へ
    // (threshold - hugeSide/2)だけずらす。
    func diagonalRect(edgeAt value: CGFloat, thickness: CGFloat? = nil, color: Color = .black) -> some View {
        let h = thickness ?? hugeSide
        return Rectangle()
            .fill(color)
            .frame(width: hugeSide, height: h)
            .rotationEffect(.degrees(45))
            .position(
                x: center.x + nx * (value - hugeSide / 2),
                y: center.y + ny * (value - hugeSide / 2)
            )
    }

    return AnyView(
        ZStack {
            content
                .frame(width: size.width, height: size.height)
                .mask(
                    PictriWavyEdgeMask(
                        nx: nx, ny: ny, ux: ux, uy: uy, center: center,
                        threshold: threshold, amplitude: waveAmplitude,
                        reach: waveReach, farDepth: hugeSide
                    )
                )

            if progress > 0.001 && progress < 0.999 {
                let bandAnchor = UnitPoint(
                    x: (center.x + nx * threshold) / size.width,
                    y: (center.y + ny * threshold) / size.height
                )
                let bandMask = PictriWavyBandMask(
                    nx: nx, ny: ny, ux: ux, uy: uy, center: center,
                    nearEdge: threshold, bandDepth: bandDepth,
                    amplitude: waveAmplitude, reach: waveReach
                )

                content
                    .frame(width: size.width, height: size.height)
                    .mask(bandMask)
                    .overlay(
                        PictriReferenceColors.paperEdge
                            .opacity(0.42)
                            .mask(bandMask)
                    )
                    .rotation3DEffect(
                        .degrees(72), axis: (x: ux, y: uy, z: 0),
                        anchor: bandAnchor, anchorZ: 0, perspective: 0.5
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 4, y: 4)

                // curvature連動highlight: 対角線に沿った、progressで強さが変わる
                // 柔らかい帯。
                let highlightOpacity = 0.14 + 0.08 * sin(eased * .pi)
                diagonalRect(
                    edgeAt: threshold - bandDepth * 0.3, thickness: bandDepth * 0.5,
                    color: PictriReferenceColors.softGold.opacity(highlightOpacity * 0.5)
                )
                .allowsHitTesting(false)

                // Home側へ落ちるcontact shadow(持ち上がるほど強まる)
                let liftT = min(1, eased * 1.25)
                diagonalRect(
                    edgeAt: threshold - bandDepth - 6 - 20 * liftT, thickness: 36 + 40 * liftT,
                    color: Color.black.opacity(0.3)
                )
                .blur(radius: 3 + 8 * liftT)
                .allowsHitTesting(false)
            }
        }
    )
}

/// Reference準拠の最終concept。timelineは画像内Timeline Summaryをそのまま採用:
/// Latent 0.00-0.80 / Emergence 0.80-1.60 / Formed 1.60-2.30 /
/// Peel Begins 2.30-3.20 / Reveal 3.20-4.00 / Home Revealed @4.00(合計4.0秒)。
struct PictriPeelConceptReferenceMatch: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.20, revealStart: 2.30, revealDuration: 0.90, totalDuration: 4.0,
                typography: pictriTypographyReferenceGold,
                revealWrapper: pictriDiagonalCornerPeelWrapper
            )
        }
    }
}

// MARK: - PURE PEEL REFINEMENT(2026-08-24、続きのラウンド)
//
// ユーザー評価: 「めくる方向・向きは合っているが、何かいらないものが写っている」
// 「普通に捲れるだけでいい」「まだ100点ではない」。
// Phase 1監査(/tmp/pictri_opening_pure_peel/audit.md)の結論: 実際に捲れている
// curl band(wavy、局所的)とは別に、画面全体を横切る直線・無限長のhighlight帯と
// contact shadow帯が独立して描画されており、curlの形状と連動していないため
// 「面と無関係な光と影の筋」に見えていた。これを削り、highlight/shadowを
// すべてcurl band自身と同じwavy silhouette(同じamplitude/reach)から導出する
// (=常に"同じ物質の続き"であることが構造的に保証される)よう再設計した。
//
// Wordmarkもわずかに縮小(46pt→41pt、約11%減)し、referenceの負のスペース比
// (wordmark幅は画面幅の約50%)に近づけた。

private let purePeelWordmarkFont: CGFloat = 41

/// Reference gold wordmarkのcompact版(サイズのみ変更、他は同一ロジック)。
func pictriTypographyPurePeelGold(elapsed: Double) -> AnyView {
    let font = PictriDarkTheme.display(purePeelWordmarkFont, weight: .regular)
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 1.05, 0), 1))
    let opacity = min(1, elapsed / 0.35)
    let contrast = 0.35 + 0.65 * t
    let blur = 2.2 * (1 - t)
    let leftT = PictriSignatureEasing.fragmentSettle(min(max((elapsed - 0.08) / 1.05, 0), 1))

    return AnyView(
        ZStack {
            RadialGradient(
                colors: [PictriReferenceColors.softGold.opacity(0.16 * t), Color.clear],
                center: .center, startRadius: 4, endRadius: 118
            )
            .frame(width: 234, height: 180)

            ZStack {
                Text("PicTri").font(font)
                    .foregroundStyle(Color.black.opacity(0.55))
                    .offset(x: 1.0, y: 1.4)
                Text("PicTri").font(font)
                    .foregroundStyle(PictriReferenceColors.softGold.opacity(0.55))
                    .offset(x: -0.8, y: -1.2)
                Text("PicTri").font(font)
                    .foregroundStyle(PictriReferenceColors.softGold)
            }
            .blur(radius: blur)
            .contrast(contrast)
            .opacity(opacity)
            .mask(
                HStack(spacing: 0) {
                    Rectangle().opacity(leftT)
                    Rectangle().opacity(t)
                }
            )
        }
    )
}

/// Pure Peelの装飾強度。すべて「curl band自身のwavy silhouetteから導出される」
/// ものだけを対象にし、画面を横切る独立した直線要素は一切持たない。
struct PictriPurePeelStyle {
    /// 0=なし。curl bandの稜線側にのみ乗る、band形状に沿ったgradientの強度。
    var rimLight: CGFloat
    /// 0=なし。curl bandの少し先(めくれた直後の領域)にband形状のまま落ちる、
    /// 局所的な影の強度。
    var contactShadow: CGFloat
}

enum PictriPurePeelConcepts {
    static let minimal = PictriPurePeelStyle(rimLight: 0.0, contactShadow: 0.0)
    static let editorial = PictriPurePeelStyle(rimLight: 0.45, contactShadow: 0.35)
    static let cinematic = PictriPurePeelStyle(rimLight: 0.8, contactShadow: 0.6)
}

/// Pure Peel本体: 平面mask境界・curl band(backface+3D回転+付随shadow)の幾何は
/// `pictriDiagonalCornerPeelWrapper`と同じものを再利用しつつ、画面を横切る
/// 独立した直線highlight/shadowを完全に廃止。rim lightとcontact shadowは
/// 必ずcurl bandと同じ`PictriWavyBandMask`(同じamplitude/reach)から導出し、
/// "別の物体"に見えることを構造的に防ぐ。
func pictriPurePeelWrapper(content: AnyView, progress: Double, size: CGSize, style: PictriPurePeelStyle) -> AnyView {
    let eased = PictriSignatureEasing.crackPropagation(progress)

    let nx: CGFloat = 0.7071
    let ny: CGFloat = 0.7071
    let ux: CGFloat = -ny
    let uy: CGFloat = nx

    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let halfDiagS = (size.width + size.height) / 2 * 0.7071 * 1.08
    let threshold = halfDiagS - eased * 2 * halfDiagS

    let bandDepth: CGFloat = min(120, size.height * 0.11)
    let waveAmplitude = bandDepth * 1.7 * min(1, eased * 1.3)
    let waveReach = halfDiagS * 1.4

    let bandAnchor = UnitPoint(
        x: (center.x + nx * threshold) / size.width,
        y: (center.y + ny * threshold) / size.height
    )
    let bandMask = PictriWavyBandMask(
        nx: nx, ny: ny, ux: ux, uy: uy, center: center,
        nearEdge: threshold, bandDepth: bandDepth,
        amplitude: waveAmplitude, reach: waveReach
    )
    let crestPoint = bandAnchor
    let farPoint = UnitPoint(
        x: (center.x + nx * (threshold - bandDepth)) / size.width,
        y: (center.y + ny * (threshold - bandDepth)) / size.height
    )

    return AnyView(
        ZStack {
            content
                .frame(width: size.width, height: size.height)
                .mask(
                    PictriWavyEdgeMask(
                        nx: nx, ny: ny, ux: ux, uy: uy, center: center,
                        threshold: threshold, amplitude: waveAmplitude,
                        reach: waveReach, farDepth: halfDiagS * 6
                    )
                )

            if progress > 0.001 && progress < 0.999 {
                // 局所的contact shadow: curl bandと全く同じsilhouette(amplitude/reach)を
                // band一枚分だけ奥へずらして落とす。独立した直線ではなく、
                // 常に"同じ物質の続き"として描かれる。
                if style.contactShadow > 0 {
                    PictriWavyBandMask(
                        nx: nx, ny: ny, ux: ux, uy: uy, center: center,
                        nearEdge: threshold - bandDepth * 0.85, bandDepth: bandDepth * 0.9,
                        amplitude: waveAmplitude, reach: waveReach
                    )
                    .fill(Color.black.opacity(0.22 * style.contactShadow))
                    .blur(radius: 7 + 5 * eased)
                    .allowsHitTesting(false)
                }

                // curlが深まるほど、band面に写る印字(wordmarkの一部)を静かに
                // 沈める。これがないと、まだ画面中央に残っている平らなwordmarkと
                // band上の傾いたwordmarkが同時に強く見え、"2つのPicTriが写っている"
                // ように見えてしまう(実機確認で判明、Phase 5で追加修正)。
                let bandPrintOpacity = max(0.32, 1 - 0.7 * eased)

                content
                    .frame(width: size.width, height: size.height)
                    .mask(bandMask)
                    .opacity(bandPrintOpacity)
                    .overlay(
                        LinearGradient(
                            colors: [
                                PictriReferenceColors.softGold.opacity(0.22 * style.rimLight),
                                PictriReferenceColors.paperEdge.opacity(0.42),
                                Color.black.opacity(0.22)
                            ],
                            startPoint: crestPoint, endPoint: farPoint
                        )
                        .mask(bandMask)
                    )
                    .rotation3DEffect(
                        .degrees(72), axis: (x: ux, y: uy, z: 0),
                        anchor: bandAnchor, anchorZ: 0, perspective: 0.5
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 4, y: 4)
            }
        }
    )
}

// MARK: - FINAL 100/100 PHYSICAL PEEL GATE(2026-08-24、続きのラウンド)
//
// フレーム単位の実機確認で4点の未完成部分が特定された:
// (1) wordmark背後の矩形Glow — 原因は`RadialGradient`を小さな`.frame()`で
//     クリップしていたこと。frameの境界がそのまま矩形の縁として見えていた。
// (2) Peelが「太い斜めband」に見える — 原因はcurlを1枚の矩形(band)を
//     rotation3DEffectで回転させるだけで表現していたこと。曲面ではなく
//     平らなカードが傾いているだけだった。
// (3) Peelが短すぎる — revealDuration 0.90秒 + crackPropagationイージング
//     (中盤53%の区間で6%→88%まで一気に進む)の組み合わせにより、
//     実質的な見た目の動きが0.5秒未満に圧縮されていた。
// (4) Status Barがcinematicな没入感を壊す — Opening中は完全に非表示にし、
//     終了時にHome本来の状態へ自動復帰させる(`.statusBarHidden`はOpening
//     のsubtree内にのみ適用され、Home側には一切影響しない)。
// 加えて既存の二重wordmark問題は、curlをK枚の薄いstripへ分割し
// 「同じcontentを1回だけmaskして回転させる」構造にすることで、
// 独立した2つ目の描画そのものを無くす形で解消する。

/// GATE 06比較用: wordmarkサイズ3候補。46pt→41pt(前ラウンド)を経て、
/// 今回は「大きすぎない」「negative spaceが美しい」という基準で
/// Small/Medium/Currentを実機比較のうえ選定する(採用値は下記
/// `finalWordmarkFont`)。
enum PictriFinalWordmarkSize: CGFloat {
    case small = 34
    case medium = 38
    case current = 41
}

/// 3案比較の結果、採用したサイズ(詳細: `/tmp/pictri_opening_100_final/`)。
let finalWordmarkFont: CGFloat = PictriFinalWordmarkSize.medium.rawValue

/// GATE01修正版wordmark。背後のvignetteから`.frame()`によるクリップ矩形を
/// 完全に除去し、画面全体スケールの非常に緩いradial falloffのみにした
/// (endRadiusに達する前に十分に透明へ収束するため、どのフレームでも
/// 境界線として視認されない)。
func pictriTypographyFinalGold(elapsed: Double, fontSize: CGFloat) -> AnyView {
    let font = PictriDarkTheme.display(fontSize, weight: .regular)
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 0.80, 0), 1))
    let opacity = min(1, elapsed / 0.30)
    let contrast = 0.32 + 0.68 * t
    let blur = 2.6 * (1 - t)
    let leftT = PictriSignatureEasing.fragmentSettle(min(max((elapsed - 0.06) / 0.80, 0), 1))

    return AnyView(
        ZStack {
            // GATE01: frameで切り取らない。ZStackの兄弟としてcontentと
            // 同じ画面サイズいっぱいに配置され、endRadius到達前に
            // 十分透明に収束するため矩形の縁が生まれない。
            RadialGradient(
                colors: [PictriReferenceColors.softGold.opacity(0.07 * t), Color.clear],
                center: .center, startRadius: 10, endRadius: 340
            )

            ZStack {
                Text("PicTri").font(font)
                    .foregroundStyle(Color.black.opacity(0.5))
                    .offset(x: 1.0, y: 1.4)
                Text("PicTri").font(font)
                    .foregroundStyle(PictriReferenceColors.softGold.opacity(0.5))
                    .offset(x: -0.8, y: -1.2)
                Text("PicTri").font(font)
                    .foregroundStyle(PictriReferenceColors.softGold)
            }
            .blur(radius: blur)
            .contrast(contrast)
            .opacity(opacity)
            .mask(
                HStack(spacing: 0) {
                    Rectangle().opacity(leftT)
                    Rectangle().opacity(t)
                }
            )
        }
    )
}

/// GATE03修正版easing。crackPropagationは中盤53%の区間だけで82%の
/// progressを消化してしまい、体感上「一瞬で終わる」原因になっていた。
/// smootherstep(6t^5-15t^4+10t^3)を主要区間に使い、同じ「非常に遅い
/// 立ち上がり→中盤で進む→柔らかく収まる」という3段階の性格を保ちながら、
/// 中盤の進み方をなだらかにして"味わえる"速度にする。
private func pictriFinalPeelEasing(_ t: Double) -> Double {
    let c = min(max(t, 0), 1)
    if c < 0.15 {
        let local = c / 0.15
        return 0.05 * local * local
    } else if c < 0.85 {
        let local = (c - 0.15) / 0.70
        let s = local * local * local * (local * (local * 6 - 15) + 10)
        return 0.05 + 0.90 * s
    } else {
        let local = (c - 0.85) / 0.15
        return 0.95 + 0.05 * (1 - pow(1 - local, 2))
    }
}

private let curlStripCount = 7
// 過去ラウンドの実測で判明した安全角度域(90°を超えると射影後の幅が
// 急減し継ぎ目が破綻する)を踏襲し、90°未満に収める。
private let curlMaxAngle: Double = 80

/// GATE02/07/08/09/10/13修正版peel: 「太いband 1枚」を回転させるのではなく、
/// 同じcurl帯をK枚の薄いstripへ分割し、各stripが自分の内側の辺(まだ平らな
/// 側)を軸に、角度をi=0(ほぼ0°)→i=K-1(curlMaxAngle°)まで滑らかにランプ
/// させながら独立して回転する。多数の平らな薄片が連なることで、遠目には
/// 連続した曲面に見える(ローポリで曲面を近似する古典的な手法)。
/// 90°を超えたstripはcontentのミラー表示ではなく、Paper Edge基調の
/// 単色backfaceへ切り替える(=表面/裏面が同じ1つの構造から自然に導出される)。
/// contentは各stripでmaskされるだけで、"別に描画された2つ目のwordmark"は
/// 存在しない(=二重表示の構造的解消)。
func pictriContinuousCurlWrapper(
    content: AnyView, progress: Double, size: CGSize, style: PictriPurePeelStyle,
    bandDepthScale: CGFloat = 1.0, stripCount: Int = curlStripCount
) -> AnyView {
    let eased = CGFloat(pictriFinalPeelEasing(progress))

    let nx: CGFloat = 0.7071
    let ny: CGFloat = 0.7071
    let ux: CGFloat = -ny
    let uy: CGFloat = nx

    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let halfDiagS = (size.width + size.height) / 2 * 0.7071 * 1.08
    let threshold = halfDiagS - eased * 2 * halfDiagS

    let bandDepth: CGFloat = min(120, size.height * 0.12) * bandDepthScale
    let waveAmplitude = bandDepth * 1.3 * min(1, eased * 1.3)
    let waveReach = halfDiagS * 1.4
    let hugeSide = halfDiagS * 6

    let K = max(1, stripCount)
    let stripWidth = bandDepth / CGFloat(K)
    // 各stripが独立にrotation3DEffectで回転するため、隣接stripとの
    // foreshortening量の違いから継ぎ目に隙間が見える不具合が実機で確認された。
    // 重なりを大きく取り、後から描画される(=より回転角が大きい)stripが
    // 前のstripの縁を覆うことで隙間を隠す(過去ラウンドの5-strip実装でも
    // 同種の問題があり、overlap=9で解消した実績を踏襲)。
    let overlap: CGFloat = 9

    func wavyBand(nearEdge: CGFloat, depth: CGFloat) -> PictriWavyBandMask {
        PictriWavyBandMask(
            nx: nx, ny: ny, ux: ux, uy: uy, center: center,
            nearEdge: nearEdge, bandDepth: depth,
            amplitude: waveAmplitude, reach: waveReach
        )
    }

    return AnyView(
        ZStack {
            // 平らな残存面。curl帯の領域も安全のため含めて描き、
            // stripが上からその部分を覆う(=継ぎ目に隙間が出ない)。
            content
                .frame(width: size.width, height: size.height)
                .mask(
                    PictriWavyEdgeMask(
                        nx: nx, ny: ny, ux: ux, uy: uy, center: center,
                        threshold: threshold, amplitude: waveAmplitude,
                        reach: waveReach, farDepth: hugeSide
                    )
                )

            if progress > 0.001 && progress < 0.999 {
                ZStack {
                    ForEach(0..<K, id: \.self) { i in
                        let outerEdge = threshold - CGFloat(K - 1 - i) * stripWidth
                        let angle = curlMaxAngle * Double(i + 1) / Double(K)
                        let hingeEdge = outerEdge - stripWidth
                        let mask = wavyBand(nearEdge: outerEdge + overlap, depth: stripWidth + overlap * 2)
                        let hingeAnchor = UnitPoint(
                            x: (center.x + nx * hingeEdge) / size.width,
                            y: (center.y + ny * hingeEdge) / size.height
                        )

                        // GATE09: front/back/edgeを別々の要素として切り替えるのではなく、
                        // 同じcontentを角度に応じて連続的に暗く(colorMultiply)して
                        // いくことで「曲がって光の当たり方が変わる1枚の面」を表現する。
                        // 角度で表示を丸ごとPaper Edge色へ切り替える分岐を廃止したのは、
                        // 実機確認でstrip間に不連続な色の段差(=継ぎ目)が生まれて
                        // いたため。curlMaxAngleを90°未満に抑えているため、contentが
                        // 鏡像(裏返しの文字)に見える角度にも達しない。
                        // opacityで薄めるとその下に安全backingとして描かれている
                        // 平らなcontentが半透明越しに透けて見え、wordmarkの縁が
                        // 二重に見える(ghost)不具合が実機で確認された。不透明の
                        // まま`colorMultiply`だけで暗くすることでghostを防ぐ。
                        let shade = 1.0 - 0.62 * (angle / curlMaxAngle)
                        let paperMix = 0.55 * (angle / curlMaxAngle)
                        content
                            .frame(width: size.width, height: size.height)
                            .mask(mask)
                            .colorMultiply(Color(white: shade))
                            .overlay(
                                PictriReferenceColors.paperEdge
                                    .opacity(paperMix)
                                    .mask(mask)
                            )
                            .rotation3DEffect(
                                .degrees(angle), axis: (x: ux, y: uy, z: 0),
                                anchor: hingeAnchor, anchorZ: 0, perspective: 0.42
                            )
                    }
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.30), radius: 9, x: 3, y: 3)

                // GATE11局所contact shadow: curlと同じwavy silhouetteの
                // 家族から作る、curlの少し先だけに落ちる柔らかい影。
                // 画面全体を横切る帯ではない。
                if style.contactShadow > 0 {
                    wavyBand(nearEdge: threshold - bandDepth * 0.95, depth: bandDepth * 0.5)
                        .fill(Color.black.opacity(0.16 * style.contactShadow))
                        .blur(radius: 6 + 4 * eased)
                        .allowsHitTesting(false)
                }

                // GATE12 rim light: curl頂点(最も角度が大きいstrip)付近だけの
                // 柔らかい光。curvatureから導出され、独立した1本の線には
                // ならない(wavy silhouetteそのものにマスクされるため)。
                if style.rimLight > 0 {
                    wavyBand(nearEdge: threshold, depth: stripWidth * 2.4)
                        .fill(PictriReferenceColors.softGold.opacity(0.14 * style.rimLight))
                        .blur(radius: 2.2)
                        .allowsHitTesting(false)
                }
            }
        }
    )
}

/// Reduce Motion版。単純fadeではなく、PicTri emergence → 小さなedge lift →
/// 短いmatte reveal → Home、という同じ視覚言語を短時間・小さな可動域で
/// 再生する(=ブランドidentityを保ったまま動きだけを縮小)。
struct PictriPeelReducedFallbackFinal: View {
    var onComplete: () -> Void
    @State private var hasStarted = false
    @State private var startDate: Date?

    private let assemblyBaseDelay = 0.25
    private let revealStart = 1.05
    private let revealDuration = 0.55
    private let totalDuration = 1.85

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
                let fragElapsed = max(0, elapsed - assemblyBaseDelay)
                let revealProgress = min(max((elapsed - revealStart) / revealDuration, 0), 1)

                let curledBackground = pictriContinuousCurlWrapper(
                    content: AnyView(PictriDarkTheme.openingSurface),
                    progress: revealProgress, size: geo.size,
                    style: PictriPurePeelStyle(rimLight: 0.2, contactShadow: 0.2),
                    bandDepthScale: 0.4, stripCount: 6
                )
                let wordmarkLayer = pictriTypographyFinalGold(elapsed: fragElapsed, fontSize: finalWordmarkFont)
                // reduced-motion版はcurlの可動域が小さいため、wordmarkの
                // 交差判定幅も同じ比率(bandDepthScale=0.4)だけ縮める。
                let wordmarkDecal = pictriWordmarkRigidCrossing(
                    wordmarkLayer: wordmarkLayer, progress: revealProgress, size: geo.size,
                    wordmarkHalfExtent: 78 * 0.4
                )

                ZStack {
                    curledBackground
                    wordmarkDecal
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            startDate = Date()
            try? await Task.sleep(for: .seconds(totalDuration))
            onComplete()
        }
    }
}

/// Production最終案。GATE01-15を満たすことを目標に、Timing T2
/// (dark 0.40 / emergence 0.85 / lock+stillness 0.65 / peel 1.40 / settle 0.25、
/// 合計3.55秒)を採用。Status Barの非表示/復帰は`PictriRootWithOpening`側
/// (`isOpeningActive`にbindingした`.statusBarHidden`)で行う
/// (このConcept自身では付けない — subview消滅では復帰しない不具合を回避)。
//
// MARK: - PHYSICAL PEEL CLOSURE(2026-08-24、続きのラウンド)
//
// 実機の高密度スクリーンショットで、wordmarkがfoldを通過する瞬間に
// 「くの字」のせん断artifactが再現することを確認した(詳細:
// `/tmp/pictri_opening_physical_closure/artifact_root_cause.md`)。
// 原因はstrip境界をまたぐ文字ストロークが、境界の左右で異なる
// rotation3D角度を受けてしまうという、離散facetで連続曲面を近似する
// 手法に共通する幾何学的な限界であり、strip数やoverlapの調整だけでは
// 解消できない。
//
// 対策: 背景とwordmarkを完全に分離した。背景はcolorのみ(細部を
// 持たないためfacet境界が知覚されない)をmulti-strip continuous curl
// で変形し、wordmarkは別レイヤーとして、foldが到達するまでは完全に
// 無変形、foldが通過する短い間だけ「ただ1つの剛体」として単一角度で
// 回転+maskする(=strip境界をまたがないため、せん断が構造的に
// 発生し得ない)。通過完了後は消える。

/// wordmarkは画面中心(diagonal座標系のs=0)に配置されている前提で、
/// fold通過中だけ単一rigid回転を適用する。sliceされないため
/// GATE10/11のせん断artifactが原理的に発生しない。
func pictriWordmarkRigidCrossing(
    wordmarkLayer: AnyView, progress: Double, size: CGSize, wordmarkHalfExtent: CGFloat = 78
) -> AnyView {
    let eased = CGFloat(pictriFinalPeelEasing(progress))
    let nx: CGFloat = 0.7071
    let ny: CGFloat = 0.7071
    let ux: CGFloat = -ny
    let uy: CGFloat = nx
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let halfDiagS = (size.width + size.height) / 2 * 0.7071 * 1.08
    let threshold = halfDiagS - eased * 2 * halfDiagS

    let crossT = 1 - min(max((threshold + wordmarkHalfExtent) / (2 * wordmarkHalfExtent), 0), 1)

    if crossT <= 0.001 {
        return wordmarkLayer
    }
    if crossT >= 0.999 {
        return AnyView(EmptyView())
    }

    let angle = 74.0 * Double(crossT)
    let shade = 1.0 - 0.5 * crossT
    let hugeSide = halfDiagS * 6

    return AnyView(
        wordmarkLayer
            .mask(
                Rectangle()
                    .frame(width: hugeSide, height: hugeSide)
                    .rotationEffect(.degrees(45))
                    .position(
                        x: center.x + nx * (threshold - hugeSide / 2),
                        y: center.y + ny * (threshold - hugeSide / 2)
                    )
            )
            .colorMultiply(Color(white: shade))
            .rotation3DEffect(
                .degrees(angle), axis: (x: ux, y: uy, z: 0),
                anchor: .center, anchorZ: 0, perspective: 0.42
            )
    )
}

struct PictriPeelConceptFinal100: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false
    @State private var startDate: Date?

    private let assemblyBaseDelay = 0.40
    private let revealStart = 1.90
    private let revealDuration = 1.40
    private let totalDuration = 3.55

    var body: some View {
        Group {
            if reduceMotion {
                PictriPeelReducedFallbackFinal(onComplete: onComplete)
            } else {
                GeometryReader { geo in
                    TimelineView(.animation) { context in
                        let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
                        let fragElapsed = max(0, elapsed - assemblyBaseDelay)
                        let revealProgress = min(max((elapsed - revealStart) / revealDuration, 0), 1)

                        let curledBackground = pictriContinuousCurlWrapper(
                            content: AnyView(PictriDarkTheme.openingSurface),
                            progress: revealProgress, size: geo.size,
                            style: PictriPurePeelConcepts.editorial
                        )
                        let wordmarkLayer = pictriTypographyFinalGold(elapsed: fragElapsed, fontSize: finalWordmarkFont)
                        let wordmarkDecal = pictriWordmarkRigidCrossing(
                            wordmarkLayer: wordmarkLayer, progress: revealProgress, size: geo.size
                        )

                        ZStack {
                            curledBackground
                            wordmarkDecal
                        }
                    }
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .task {
                    guard !hasStarted else { return }
                    hasStarted = true
                    startDate = Date()
                    try? await Task.sleep(for: .seconds(totalDuration))
                    onComplete()
                }
            }
        }
    }
}

struct PictriPurePeelConcept_Minimal: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.20, revealStart: 2.30, revealDuration: 0.90, totalDuration: 4.0,
                typography: pictriTypographyPurePeelGold,
                revealWrapper: { content, progress, size in
                    pictriPurePeelWrapper(content: content, progress: progress, size: size, style: PictriPurePeelConcepts.minimal)
                }
            )
        }
    }
}

struct PictriPurePeelConcept_Editorial: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.20, revealStart: 2.30, revealDuration: 0.90, totalDuration: 4.0,
                typography: pictriTypographyPurePeelGold,
                revealWrapper: { content, progress, size in
                    pictriPurePeelWrapper(content: content, progress: progress, size: size, style: PictriPurePeelConcepts.editorial)
                }
            )
        }
    }
}

struct PictriPurePeelConcept_Cinematic: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.20, revealStart: 2.30, revealDuration: 0.90, totalDuration: 4.0,
                typography: pictriTypographyPurePeelGold,
                revealWrapper: { content, progress, size in
                    pictriPurePeelWrapper(content: content, progress: progress, size: size, style: PictriPurePeelConcepts.cinematic)
                }
            )
        }
    }
}

// MARK: - Reduce Motion共通(Peel識別を保ったまま簡略化)

struct PictriPeelReducedFallback: View {
    var onComplete: () -> Void
    @State private var textOpacity: Double = 0
    @State private var peelProgress: Double = 0
    @State private var wholeOpacity: Double = 1

    var body: some View {
        GeometryReader { geo in
            pictriPeelRevealWrapper(
                content: AnyView(
                    ZStack {
                        PictriDarkTheme.openingSurface
                        Text("PicTri")
                            .font(PictriDarkTheme.display(peelWordmarkFont, weight: .regular))
                            .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                            .opacity(textOpacity)
                    }
                ),
                progress: peelProgress,
                size: geo.size
            )
        }
        .ignoresSafeArea()
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeInOut(duration: 0.35)) { textOpacity = 1 }
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeInOut(duration: 0.4)) { peelProgress = 1 }
            try? await Task.sleep(for: .seconds(0.45))
            onComplete()
        }
    }
}

// MARK: - Phase 1/2/3 比較用Concept群(DEBUG Lab専用)

struct PictriPeelConcept_LatentFragments_SeamReveal: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.2, revealStart: 1.9, revealDuration: 0.75, totalDuration: 3.4,
                typography: pictriTypographyLatentFragments,
                revealWrapper: pictriPeelRevealWrapper
            )
        }
    }
}

/// Phase 4/5で確定した本番タイミング。Phase 2/3で採用したLatent Fragments +
/// Peel Revealの組み合わせに、精密なタイミング調整を加えた最終版。
/// 内訳(内部経過時間): 暗黒0.00-0.25 → 断片アセンブリ0.25-1.35 →
/// 静止1.35-2.35(1.0秒、「文字出現後に静止して見せる時間」を確保) →
/// めくれ2.35-3.15(0.8秒) → 余韻0.15秒 → 完了(合計約3.3秒、
/// 要求レンジ3.0〜4.5秒の中央寄り)。
struct PictriPeelConceptFinal: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.25, revealStart: 2.35, revealDuration: 0.8, totalDuration: 3.3,
                typography: pictriTypographyLatentFragmentsFinal,
                revealWrapper: pictriPeelRevealWrapper
            )
        }
    }
}

/// Phase 4調整版のLatent Fragments: 「じわんと立ち上がる」感覚を強めるため、
/// fragmentの収束速度をやや緩やかにした(durationRangeを0.45...0.7へ延長)。
/// Phase 5でDynamic Qualityを補うため、静止の終わり際(めくれが始まる直前)に
/// ごく短い山形のcontrast/brightnessパルス(Glyph Lock)を追加した — 「面が
/// 一度static holdへ達し、その直後に静かに開く」という状態変化の節目を作る。
func pictriTypographyLatentFragmentsFinal(elapsed: Double) -> AnyView {
    let fragments = makeSignatureFragments(
        canvasSize: peelCanvasSize, cols: 6, rows: 4,
        seed: 0xFEED01, maxDelay: 0.4, durationRange: 0.45...0.7,
        offsetMagnitude: 9, offsetDirection: signatureOutwardDirection,
        blurRange: 6...13, scaleRange: 1.5...2.2, rotationRange: -3...3
    )
    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 1.1, 0), 1))
    var brightness = -0.3 * (1 - t)
    let saturation = 0.25 + 0.75 * t
    var contrast = 1.2 - 0.2 * t

    // Glyph Lock: めくれ開始(fragElapsed換算で約2.10秒)の直前、1.85-2.10秒に
    // 山形のパルスを重ねる。画面全体ではなくglyphのみへ適用するため、
    // 過去に発覚した全画面フラッシュ事故を再発させない。
    let lockLocal = min(max((elapsed - 1.85) / 0.25, 0), 1)
    let lockPulse = sin(lockLocal * .pi)
    contrast += 0.09 * lockPulse
    brightness += 0.045 * lockPulse

    return AnyView(
        SignatureAssemblyGlyph(
            font: PictriDarkTheme.display(peelWordmarkFont, weight: .regular),
            textColor: PictriDarkTheme.openingTextPrimary,
            canvasSize: peelCanvasSize, fragments: fragments, elapsed: elapsed
        )
        .brightness(brightness)
        .saturation(saturation)
        .contrast(contrast)
    )
}

struct PictriPeelConcept_ExposureBloom: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.2, revealStart: 1.9, revealDuration: 0.75, totalDuration: 3.4,
                typography: pictriTypographyExposureBloom,
                revealWrapper: pictriPeelRevealWrapper
            )
        }
    }
}

// MARK: - Cinematic Peel Finalization: Typography比較3案(DEBUG Lab)

struct PictriPeelConcept_DepthEmergence: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.45, revealStart: 2.0, revealDuration: 0.8, totalDuration: 3.2,
                typography: pictriTypographyDepthEmergence,
                revealWrapper: pictriPeelRevealWrapper
            )
        }
    }
}

struct PictriPeelConcept_LatentImageTypo: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.45, revealStart: 2.0, revealDuration: 0.8, totalDuration: 3.2,
                typography: pictriTypographyLatentImage,
                revealWrapper: pictriPeelRevealWrapper
            )
        }
    }
}

struct PictriPeelConcept_SegmentedCurl: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.45, revealStart: 2.0, revealDuration: 0.9, totalDuration: 3.3,
                typography: pictriTypographyLatentImage,
                revealWrapper: pictriSegmentedCurlRevealWrapper
            )
        }
    }
}

struct PictriPeelConcept_SoftMaterialReveal: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.45, revealStart: 2.0, revealDuration: 0.8, totalDuration: 3.2,
                typography: pictriTypographySoftMaterialReveal,
                revealWrapper: pictriPeelRevealWrapper
            )
        }
    }
}

struct PictriPeelConcept_BlockAssembly: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.2, revealStart: 1.9, revealDuration: 0.75, totalDuration: 3.4,
                typography: pictriTypographyBlockAssembly,
                revealWrapper: pictriPeelRevealWrapper
            )
        }
    }
}

struct PictriPeelConcept_SeamRevealCompare: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.2, revealStart: 1.9, revealDuration: 0.6, totalDuration: 3.2,
                typography: pictriTypographyLatentFragments,
                revealWrapper: pictriSeamRevealWrapper
            )
        }
    }
}

struct PictriPeelConcept_LatentSplitCompare: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            PictriPeelReducedFallback(onComplete: onComplete)
        } else {
            PictriPeelOpeningEngine(
                onComplete: onComplete,
                assemblyBaseDelay: 0.2, revealStart: 1.9, revealDuration: 0.6, totalDuration: 3.2,
                typography: pictriTypographyLatentFragments,
                revealWrapper: pictriLatentSplitRevealWrapper
            )
        }
    }
}
