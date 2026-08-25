import SwiftUI

// MARK: - Opening Motion Lab (Phase 7)
//
// 前回Run(PictriOpeningView, v2 "Memory Exposure")のA判定は今回のセッションで無効化された。
// 「光が広がる→収束する、の1往復だけで質感変化が1段階しかない」という再評価に基づき、
// 完全に異なる仕組みを持つ3つの新規conceptをゼロから構築した(v2の使い回しではない)。
// 各conceptは同じ`onComplete: () -> Void`インターフェースを持ち、DEBUG限定の
// `PictriOpeningPreviewHarness`(JapanQuestApp.swift)から`-pictriOpeningConcept a|b|c`で
// 個別に起動・録画・スコアリングできる。採用されたconceptのみが最終的に
// PictriOpeningView(v3)として本番へ接続され、このファイル自体はLab記録として残す。
//
// 3案の設計原則(audit.mdの指摘への直接回答):
// - v2は「同心円のradial glowが広がって収束するだけ」の単一パターン → 3案はそれぞれ
//   全く異なる物理現象(レンズのフォーカス送り/暗室での現像/絞り羽根の開放)を採用し、
//   「AIテンプレ感のある汎用glow」から明確に距離を取る。
// - 色は既存PictriDarkTheme(surfaceBase/textPrimary/accent)のみ。新しいhexは足さない。
// - 横方向(左右)へ走る要素は持たない(v1がB以下だった理由の再発防止)。
// - 各conceptは1.6〜1.8秒、Reduce Motion時は共通の簡易fallbackへ分岐する。

// MARK: - Shared reduced-motion fallback(3案共通。評価対象はフル版のみのため複製しない)

private struct PictriOpeningReducedFallback: View {
    var onComplete: () -> Void
    @State private var glowOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var wholeOpacity: Double = 1

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PictriDarkTheme.accent.opacity(0.5), PictriDarkTheme.accent.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .opacity(glowOpacity)
            Text("PicTri")
                .font(PictriDarkTheme.display(52, weight: .regular))
                .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                .opacity(textOpacity)
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeInOut(duration: 0.35)) { glowOpacity = 1 }
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeInOut(duration: 0.4)) { textOpacity = 1 }
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeInOut(duration: 0.2)) { wholeOpacity = 0 }
            try? await Task.sleep(for: .seconds(0.2))
            onComplete()
        }
    }
}

// MARK: - Concept A — Lens Focus Pull
//
// 「PicTriはカメラで残す旅の記録」を、抽象的な光ではなくレンズの物理挙動そのもので表現する。
// 背景に非対称に配置したbokeh円(被写界深度の奥/手前を暗示)を強いdefocus(blur 40pt)から始め、
// フォーカスが中心のwordmarkへ送られる過程を「blur収束+わずかなscale breathing」で見せる。
// 合焦の瞬間だけ薄いfocus-confirmリング(カメラのAF枠を抽象化、□や十字は使わない)が一瞬灯る。
struct PictriOpeningConceptA_LensFocus: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    @State private var bokehOpacity: Double = 0
    @State private var bokehBlur: CGFloat = 42
    @State private var bokehScale: CGFloat = 1.16
    @State private var wordBlur: CGFloat = 26
    @State private var wordOpacity: Double = 0
    @State private var wordScale: CGFloat = 1.05
    @State private var ringOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.7
    @State private var pulse: Double = 0
    @State private var wholeOpacity: Double = 1

    private struct Bokeh { let dx: CGFloat; let dy: CGFloat; let d: CGFloat; let warm: Bool }
    private let bokehs: [Bokeh] = [
        .init(dx: -96, dy: -140, d: 46, warm: false),
        .init(dx: 118, dy: -110, d: 60, warm: true),
        .init(dx: -132, dy: 70, d: 70, warm: false),
        .init(dx: 104, dy: 96, d: 40, warm: true),
        .init(dx: 20, dy: -170, d: 34, warm: false),
        .init(dx: -30, dy: 150, d: 50, warm: true)
    ]

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    ForEach(Array(bokehs.enumerated()), id: \.offset) { _, b in
                        Circle()
                            .fill(b.warm ? PictriDarkTheme.accent : PictriDarkTheme.openingTextPrimary)
                            .frame(width: b.d, height: b.d)
                            .opacity(b.warm ? 0.30 : 0.16)
                            .offset(x: b.dx, y: b.dy)
                    }
                    .blur(radius: bokehBlur)
                    .opacity(bokehOpacity)
                    .scaleEffect(bokehScale)

                    Circle()
                        .stroke(PictriDarkTheme.openingTextPrimary.opacity(0.5), lineWidth: 1)
                        .frame(width: 96, height: 96)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    Text("PicTri")
                        .font(PictriDarkTheme.display(52, weight: .regular))
                        .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                        .blur(radius: wordBlur)
                        .opacity(wordOpacity)
                        .scaleEffect(wordScale)
                }
                .brightness(pulse)
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        // 0.15–0.55: 強くdefocusしたbokehがふわっと現れる(まだ何も合っていない)。
        withAnimation(.easeOut(duration: 0.40)) {
            bokehOpacity = 1
            bokehScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }

        // 0.45–0.95: フォーカスが送られる。bokehは軽く収束、wordmarkは強いblurから
        // 一気にシャープへ。ここが本conceptの核(単なるopacity fadeではない)。
        withAnimation(.easeInOut(duration: 0.5)) {
            bokehBlur = 20
            wordBlur = 0
            wordOpacity = 1
            wordScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.45))
        guard !Task.isCancelled else { return }

        // 0.90–1.15: 合焦confirm(薄いリングが一瞬だけ現れて少し拡大しつつ消える)。
        withAnimation(.easeOut(duration: 0.18)) {
            ringOpacity = 0.8
            ringScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.10))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.08)) { pulse = 0.08 }
        try? await Task.sleep(for: .seconds(0.10))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            pulse = 0
            ringOpacity = 0
            ringScale = 1.3
        }
        try? await Task.sleep(for: .seconds(0.45))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.35)) { wholeOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

// MARK: - Concept B — Darkroom Developing Tray
//
// 「露光」ではなく「現像」そのものを主役にする。wordmarkは最初、ほぼ白紙の印画紙のように
// 淡くしか存在せず、波打つ現像液の境界線が下から上へ昇るにつれて像が定着していく
// (v1で禁止された左右方向のsweepとは異なる、縦方向・かつ直線ではない有機的な境界)。
// 常時ごく薄いgrain(粒子)を重ねることで、v2には無かった「写真の物質感」を足す。
struct PictriOpeningConceptB_DarkroomTray: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    @State private var ghostOpacity: Double = 0
    @State private var grainOpacity: Double = 0
    @State private var waveProgress: CGFloat = 0
    @State private var edgeGlowOpacity: Double = 0
    @State private var pulse: Double = 0
    @State private var wholeOpacity: Double = 1

    private let stageSize = CGSize(width: 300, height: 96)

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    grainField.opacity(grainOpacity)

                    ZStack {
                        wordmark.opacity(ghostOpacity * 0.10)

                        wordmark
                            .mask(developedWaveMask)

                        waveEdgeGlow
                            .opacity(edgeGlowOpacity)
                    }
                    .frame(width: stageSize.width, height: stageSize.height)
                }
                .brightness(pulse)
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    private var wordmark: some View {
        Text("PicTri")
            .font(PictriDarkTheme.display(52, weight: .regular))
            .foregroundStyle(PictriDarkTheme.openingTextPrimary)
    }

    /// 決定論的な粒子field(乱数seedは固定、再生のたびに同じパターン。GPU負荷を避けるため
    /// 一定数のstatic dotのみ、アニメーションはopacityだけ)。
    private var grainField: some View {
        Canvas { context, size in
            var seed: UInt64 = 1_469_598_103
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) & 0xFFFF) / Double(0xFFFF)
            }
            for _ in 0..<260 {
                let x = next() * size.width
                let y = next() * size.height
                let r = 0.4 + next() * 0.7
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(PictriDarkTheme.openingTextPrimary.opacity(0.5))
                )
            }
        }
    }

    /// 現像液の境界線(下から上へ昇る、正弦波で有機的な縁を持つ)をmaskとして使う。
    private var developedWaveMask: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let w = proxy.size.width
            let boundaryY = h * (1 - waveProgress)
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: boundaryY))
                let steps = 24
                for i in 0...steps {
                    let x = size.width * CGFloat(i) / CGFloat(steps)
                    let wobble = sin((x / w) * .pi * 2.4 + waveProgress * 3) * 3.5
                    path.addLine(to: CGPoint(x: x, y: boundaryY + wobble))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(.white))
            }
        }
    }

    private var waveEdgeGlow: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            Rectangle()
                .fill(PictriDarkTheme.accent)
                .frame(height: 10)
                .blur(radius: 8)
                .position(x: proxy.size.width / 2, y: h * (1 - waveProgress))
        }
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        // 0.15–0.30: 印画紙にまだ薄くしか像が無い状態+粒子が現れ始める。
        withAnimation(.easeOut(duration: 0.25)) {
            ghostOpacity = 1
            grainOpacity = 0.10
        }
        try? await Task.sleep(for: .seconds(0.20))
        guard !Task.isCancelled else { return }

        // 0.35–1.10: 現像液の境界(有機的な波)が下から上へ昇り、通過した部分だけ
        // フル発色する。同時に境界に沿ってamber glowが動く(v2の同心円glowとは
        // 全く異なる、線状・上昇方向のダイナミズム)。
        withAnimation(.easeInOut(duration: 0.15)) { edgeGlowOpacity = 0.45 }
        withAnimation(.easeInOut(duration: 0.75)) { waveProgress = 1 }
        try? await Task.sleep(for: .seconds(0.75))
        guard !Task.isCancelled else { return }

        // 1.10–1.30: 「定着」— 粒子が落ち着き、短い明るさの揺らぎ(現像トレイから
        // 引き上げて明かりの下で確認する瞬間)。
        withAnimation(.easeOut(duration: 0.2)) { edgeGlowOpacity = 0 }
        withAnimation(.easeOut(duration: 0.10)) { pulse = 0.06 }
        try? await Task.sleep(for: .seconds(0.12))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            pulse = 0
            grainOpacity = 0.045
        }
        try? await Task.sleep(for: .seconds(0.40))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.35)) { wholeOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

// MARK: - Concept C — Aperture Iris Bloom
//
// カメラ絞り羽根(iris diaphragm)そのものの開閉を、抽象glowではなく幾何形状として描く。
// 7枚の羽根(背景色で塗った不透明panel)が中心を覆って閉じた状態から始まり、羽根が
// 外側へ引くことで開口部が生まれ、その奥にあるwarm bloomが覗く → wordmarkが開口部の
// 中心に現れる、という「シャッターが開いて記憶を迎え入れる」構成。
struct PictriOpeningConceptC_ApertureIris: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    @State private var bloomOpacity: Double = 0
    @State private var bloomScale: CGFloat = 0.6
    @State private var opening: CGFloat = 0
    @State private var wordOpacity: Double = 0
    @State private var wordScale: CGFloat = 0.94
    @State private var pulse: Double = 0
    @State private var wholeOpacity: Double = 1

    private let bladeCount = 7
    private let bladeOuterRadius: CGFloat = 150
    private let irisMaxOpenRadius: CGFloat = 92

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PictriDarkTheme.openingTextPrimary, PictriDarkTheme.accent, PictriDarkTheme.accent.opacity(0)],
                                center: .center, startRadius: 0, endRadius: 120
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 22)
                        .opacity(bloomOpacity)
                        .scaleEffect(bloomScale)

                    irisBlades

                    Text("PicTri")
                        .font(PictriDarkTheme.display(52, weight: .regular))
                        .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                        .opacity(wordOpacity)
                        .scaleEffect(wordScale)
                }
                .brightness(pulse)
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    /// N枚の羽根。各羽根はopening(0=閉/中心を覆う, 1=全開/外周へ退避)に応じて
    /// 中心方向のtipを引き戻す1つの三角形Path。回転コピーで円周上に均等配置する。
    /// Opening Lab初回実装のバグ(外周コーナーの座標計算を誤り、巨大な棘状に破綻した)を
    /// 修正: 座標計算を「tip 1点+外周円周上の2点」の単純な三角形に単純化し、さらに
    /// `.clipShape(Circle())`を安全網として掛けることで、どのopening値でも羽根が
    /// 意図した円の外へはみ出さないことを幾何学的に保証する。
    private var irisBlades: some View {
        ZStack {
            ForEach(0..<bladeCount, id: \.self) { i in
                bladeShape(opening: opening)
                    .fill(PictriDarkTheme.openingSurface)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(bladeCount))))
            }
        }
        .frame(width: bladeOuterRadius * 2, height: bladeOuterRadius * 2)
        .clipShape(Circle())
    }

    private func bladeShape(opening: CGFloat) -> Path {
        let tipRadius = irisMaxOpenRadius * opening
        let outerRadius = bladeOuterRadius * 1.05
        // 隣接羽根と重なりを持たせ、閉じた状態(tipRadius=0)で隙間なく円を覆う。
        // 2π/bladeCountちょうどだと直線の外周辺(弦)が円周よりわずかに内側へ入り込み、
        // 羽根間に細い隙間ができるため、幅を35%広げて確実にoverlapさせる。
        let halfWidthAngle: CGFloat = (.pi / Double(bladeCount)) * 1.35

        var path = Path()
        let tip = CGPoint(x: tipRadius, y: 0)
        let outerA = CGPoint(
            x: outerRadius * cos(halfWidthAngle),
            y: outerRadius * sin(halfWidthAngle)
        )
        let outerB = CGPoint(
            x: outerRadius * cos(-halfWidthAngle),
            y: outerRadius * sin(-halfWidthAngle)
        )
        path.move(to: tip)
        path.addLine(to: outerA)
        path.addLine(to: outerB)
        path.closeSubpath()
        return path
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        // 0.15–0.30: 閉じた羽根の隙間から、奥の光がわずかに滲む(期待感)。
        withAnimation(.easeOut(duration: 0.25)) {
            bloomOpacity = 0.35
        }
        try? await Task.sleep(for: .seconds(0.20))
        guard !Task.isCancelled else { return }

        // 0.35–0.90: 絞りが開く。機械式らしい、わずかなovershoot付きのspring。
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
            opening = 1
        }
        withAnimation(.easeOut(duration: 0.5)) {
            bloomOpacity = 0.85
            bloomScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.55))
        guard !Task.isCancelled else { return }

        // 0.75–1.15: 開いた開口部にwordmarkが現れる。
        withAnimation(.easeOut(duration: 0.4)) {
            wordOpacity = 1
            wordScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }

        // 1.10–1.25: シャッターが切れた瞬間の短いflash pulse。
        // Concept A(Lens Focus Pull)の検証で、.brightness()の値が大きいと静止フレームで
        // 画面全体が灰色に洗い流されて見える不具合が見つかったため、同じ理由で値を抑える。
        withAnimation(.easeOut(duration: 0.07)) { pulse = 0.03 }
        try? await Task.sleep(for: .seconds(0.09))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.25)) { pulse = 0 }
        try? await Task.sleep(for: .seconds(0.40))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.35)) { wholeOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

// MARK: - Concept D — Hybrid(Iris Glimpse → Lens Focus Pull)
//
// 「絞りが開く」という最も強い着想(Concept C)を、演出全体の主役にはせず最初の
// 約0.3秒だけの"気配"として使い、そこからConcept A(Lens Focus Pull)へ
// クロスフェードで受け渡す。「全部盛り」にしないため、絞り羽根はごく短時間・
// 小さくしか見せず、フォーカス送りの方を本体として最後まで担わせる。
struct PictriOpeningConceptD_Hybrid: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    // Iris(冒頭のみ)
    @State private var irisOpening: CGFloat = 0
    @State private var irisBloomOpacity: Double = 0
    @State private var irisGroupOpacity: Double = 1

    // Lens Focus Pull(本体)
    @State private var bokehOpacity: Double = 0
    @State private var bokehBlur: CGFloat = 42
    @State private var bokehScale: CGFloat = 1.16
    @State private var wordBlur: CGFloat = 26
    @State private var wordOpacity: Double = 0
    @State private var wordScale: CGFloat = 1.05
    @State private var ringOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.7
    @State private var pulse: Double = 0
    @State private var wholeOpacity: Double = 1

    private let bladeCount = 7
    private let bladeOuterRadius: CGFloat = 130
    private let irisMaxOpenRadius: CGFloat = 80

    private struct Bokeh { let dx: CGFloat; let dy: CGFloat; let d: CGFloat; let warm: Bool }
    private let bokehs: [Bokeh] = [
        .init(dx: -96, dy: -140, d: 46, warm: false),
        .init(dx: 118, dy: -110, d: 60, warm: true),
        .init(dx: -132, dy: 70, d: 70, warm: false),
        .init(dx: 104, dy: 96, d: 40, warm: true),
        .init(dx: 20, dy: -170, d: 34, warm: false),
        .init(dx: -30, dy: 150, d: 50, warm: true)
    ]

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    // Iris(冒頭の気配。本体へ引き継いだ後はopacityで消える)
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [PictriDarkTheme.openingTextPrimary, PictriDarkTheme.accent, PictriDarkTheme.accent.opacity(0)],
                                    center: .center, startRadius: 0, endRadius: 100
                                )
                            )
                            .frame(width: 130, height: 130)
                            .blur(radius: 20)
                            .opacity(irisBloomOpacity)

                        irisBlades
                    }
                    .opacity(irisGroupOpacity)

                    // Lens Focus Pull(本体)
                    ForEach(Array(bokehs.enumerated()), id: \.offset) { _, b in
                        Circle()
                            .fill(b.warm ? PictriDarkTheme.accent : PictriDarkTheme.openingTextPrimary)
                            .frame(width: b.d, height: b.d)
                            .opacity(b.warm ? 0.30 : 0.16)
                            .offset(x: b.dx, y: b.dy)
                    }
                    .blur(radius: bokehBlur)
                    .opacity(bokehOpacity)
                    .scaleEffect(bokehScale)

                    Circle()
                        .stroke(PictriDarkTheme.openingTextPrimary.opacity(0.5), lineWidth: 1)
                        .frame(width: 96, height: 96)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    Text("PicTri")
                        .font(PictriDarkTheme.display(52, weight: .regular))
                        .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                        .blur(radius: wordBlur)
                        .opacity(wordOpacity)
                        .scaleEffect(wordScale)
                }
                .brightness(pulse)
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    private var irisBlades: some View {
        ZStack {
            ForEach(0..<bladeCount, id: \.self) { i in
                bladeShape(opening: irisOpening)
                    .fill(PictriDarkTheme.openingSurface)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(bladeCount))))
            }
        }
        .frame(width: bladeOuterRadius * 2, height: bladeOuterRadius * 2)
        .clipShape(Circle())
    }

    private func bladeShape(opening: CGFloat) -> Path {
        let tipRadius = irisMaxOpenRadius * opening
        let outerRadius = bladeOuterRadius * 1.05
        let halfWidthAngle: CGFloat = (.pi / Double(bladeCount)) * 1.35

        var path = Path()
        let tip = CGPoint(x: tipRadius, y: 0)
        let outerA = CGPoint(x: outerRadius * cos(halfWidthAngle), y: outerRadius * sin(halfWidthAngle))
        let outerB = CGPoint(x: outerRadius * cos(-halfWidthAngle), y: outerRadius * sin(-halfWidthAngle))
        path.move(to: tip)
        path.addLine(to: outerA)
        path.addLine(to: outerB)
        path.closeSubpath()
        return path
    }

    private func runTimeline() async {
        // 0.00–0.12: 真っ暗。
        try? await Task.sleep(for: .seconds(0.12))
        guard !Task.isCancelled else { return }

        // 0.12–0.42: 絞りが素早く開く一瞬の気配(全体演出の主役にはしない、短時間のみ)。
        withAnimation(.easeOut(duration: 0.18)) { irisBloomOpacity = 0.7 }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.7)) { irisOpening = 1 }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }

        // 0.42–0.62: irisを消しながら、bokeh(Lens Focus Pull本体)へクロスフェード。
        withAnimation(.easeInOut(duration: 0.28)) {
            irisGroupOpacity = 0
            bokehOpacity = 1
            bokehScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }

        // 0.72–1.15: フォーカスが送られる(Concept Aと同じ核)。
        withAnimation(.easeInOut(duration: 0.45)) {
            bokehBlur = 20
            wordBlur = 0
            wordOpacity = 1
            wordScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.40))
        guard !Task.isCancelled else { return }

        // 1.12–1.35: 合焦confirm + 短いshutter pulse。
        withAnimation(.easeOut(duration: 0.18)) {
            ringOpacity = 0.8
            ringScale = 1.0
        }
        try? await Task.sleep(for: .seconds(0.10))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.08)) { pulse = 0.03 }
        try? await Task.sleep(for: .seconds(0.10))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            pulse = 0
            ringOpacity = 0
            ringScale = 1.3
        }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.35)) { wholeOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

// MARK: - Opening Cinema v2 (2026-08-23 追加ラウンド)
//
// v4(Iris Glimpse → Lens Focus Pull)は「2つの異なる視覚文法を中間で接着した」
// ことがシンプルさ・映画的没入感の不足の原因と再監査で判明した
// (詳細: /tmp/pictri_opening_cinema_v2/audit.md)。今回は単一の強い写真的モチーフを
// 最後まで貫く4案(E/F/G/H)を新たに構築する。v4(A〜Dのconcept群)はLab記録として
// 残し、削除しない。

// MARK: - Concept E — Rack Focus(被写界深度の移動)
//
// 「同時にblur→sharpする」のではなく、手前のbokehがピントを失っていくのと
// 方向性を持って入れ替わりに奥のwordmarkがピントを獲得する、本物のrack focusを模す。
// 意図的にbokehのdefocus開始とwordmarkのsharpen開始をずらし、両方が同時に
// ぼやけた"どちらにもピントが無い"中間状態を経由させる。
struct PictriOpeningConceptE_RackFocus: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    @State private var bokehOpacity: Double = 0
    @State private var bokehBlur: CGFloat = 6
    @State private var bokehScale: CGFloat = 1.0
    @State private var wordBlur: CGFloat = 30
    @State private var wordOpacity: Double = 0
    @State private var glintOpacity: Double = 0
    @State private var wholeOpacity: Double = 1

    private struct Bokeh { let dx: CGFloat; let dy: CGFloat; let d: CGFloat; let warm: Bool }
    /// 前作より数を絞り(6→4)、非対称配置は維持。1個だけterracottaにすることで
    /// 「旅先の何か」をほのめかす程度に留める(直接的な地図・写真は使わない)。
    private let bokehs: [Bokeh] = [
        .init(dx: -110, dy: -130, d: 50, warm: false),
        .init(dx: 120, dy: -80, d: 64, warm: true),
        .init(dx: -90, dy: 110, d: 58, warm: false),
        .init(dx: 100, dy: 140, d: 38, warm: false)
    ]

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    ForEach(Array(bokehs.enumerated()), id: \.offset) { _, b in
                        Circle()
                            .fill(b.warm ? PictriDarkTheme.accent : PictriDarkTheme.openingTextPrimary)
                            .frame(width: b.d, height: b.d)
                            .opacity(b.warm ? 0.32 : 0.15)
                            .offset(x: b.dx, y: b.dy)
                    }
                    .blur(radius: bokehBlur)
                    .opacity(bokehOpacity)
                    .scaleEffect(bokehScale)

                    Text("PicTri")
                        .font(PictriDarkTheme.display(52, weight: .regular))
                        .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                        .blur(radius: wordBlur)
                        .opacity(wordOpacity)
                        .overlay(alignment: .topTrailing) {
                            // 合焦の瞬間だけ灯る、局所的な1点のglint。画面全体には広がらない。
                            Circle()
                                .fill(PictriDarkTheme.accent)
                                .frame(width: 5, height: 5)
                                .blur(radius: 1.5)
                                .opacity(glintOpacity)
                                .offset(x: 6, y: -4)
                        }
                }
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(0.20))
        guard !Task.isCancelled else { return }

        // 0.20–0.55: bokehがまだ比較的シャープな状態で浮かぶ(何なのかまだ分からない)。
        withAnimation(.easeOut(duration: 0.35)) { bokehOpacity = 1 }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }

        // 0.55–1.15: rack focus本体。bokehが手前でdefocusしながらわずかに拡散。
        withAnimation(.easeInOut(duration: 0.60)) {
            bokehBlur = 38
            bokehScale = 1.08
        }
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        // 0.70–1.15: bokehより遅れてwordmarkが奥からピントを獲得する
        // (開始をずらすことで、0.70–1.00あたりに「両方ぼやけている」中間状態ができる)。
        withAnimation(.easeInOut(duration: 0.45)) {
            wordBlur = 0
            wordOpacity = 1
        }
        try? await Task.sleep(for: .seconds(0.45))
        guard !Task.isCancelled else { return }

        // 1.15–1.30: 合焦confirmの局所glint(画面全体には広がらない1点だけの光)。
        withAnimation(.easeOut(duration: 0.10)) { glintOpacity = 0.9 }
        try? await Task.sleep(for: .seconds(0.12))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.18)) { glintOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }

        // 1.60–1.90: fade out。
        withAnimation(.easeInOut(duration: 0.30)) { wholeOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

// MARK: - Concept F — Exposure Print(露光と現像の気配)
//
// 暗闇の中、粒子(film grain)にまみれた像が非線形にcontrastを上げながら現像され、
// 粒子が落ち着くのと同時に像がクリアになる。前回のbrightness pulse事故
// (画面全体が灰色に洗われる)を、pulseをwordmark単体にだけ適用する設計で
// 構造的に回避する。
struct PictriOpeningConceptF_ExposurePrint: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    @State private var grainOpacity: Double = 0
    @State private var wordOpacity: Double = 0
    @State private var wordContrast: Double = 0.2
    @State private var toningOpacity: Double = 0
    @State private var wordPulse: Double = 0
    @State private var wholeOpacity: Double = 1

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    grainField
                        .opacity(grainOpacity)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PictriDarkTheme.accent.opacity(0.5), PictriDarkTheme.accent.opacity(0)],
                                center: .center, startRadius: 0, endRadius: 160
                            )
                        )
                        .frame(width: 260, height: 260)
                        .blur(radius: 40)
                        .opacity(toningOpacity)

                    Text("PicTri")
                        .font(PictriDarkTheme.display(52, weight: .regular))
                        .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                        .contrast(wordContrast)
                        .opacity(wordOpacity)
                        .brightness(wordPulse)
                }
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    /// 決定論的なfilm grain。乱数seedは固定・再生成しない(GPU/CPU負荷を避けるため
    /// opacityだけをアニメーションさせ、dot配置自体は1度描画したら不変)。
    private var grainField: some View {
        Canvas { context, size in
            var seed: UInt64 = 2_654_435_761
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) & 0xFFFF) / Double(0xFFFF)
            }
            for _ in 0..<420 {
                let x = next() * size.width
                let y = next() * size.height
                let r = 0.4 + next() * 0.8
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(PictriDarkTheme.openingTextPrimary.opacity(0.55))
                )
            }
        }
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        // 0.15–0.40: 強いgrainが浮かぶ。まだ何の形も見えない。
        withAnimation(.easeOut(duration: 0.25)) {
            grainOpacity = 0.38
            wordOpacity = 0.06
        }
        try? await Task.sleep(for: .seconds(0.25))
        guard !Task.isCancelled else { return }

        // 0.40–1.30: 現像本体。contrastが非線形に上がり、grainが落ち着く。
        // 現像液の色味を暗示するterracotta toningが中心から一瞬だけ滲んで消える。
        withAnimation(.easeIn(duration: 0.5)) { toningOpacity = 0.5 }
        withAnimation(.easeOut(duration: 0.9).delay(0.2)) { toningOpacity = 0 }
        withAnimation(.easeIn(duration: 0.9)) {
            wordContrast = 1.0
            wordOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 0.9)) {
            grainOpacity = 0.07
        }
        try? await Task.sleep(for: .seconds(0.90))
        guard !Task.isCancelled else { return }

        // 1.30–1.55: 「定着」の一瞬。brightness pulseはwordmark単体にのみ掛かるため、
        // 画面全体が灰色に洗われる事故が構造的に起きない。
        withAnimation(.easeOut(duration: 0.10)) { wordPulse = 0.10 }
        try? await Task.sleep(for: .seconds(0.12))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.20)) { wordPulse = 0 }
        try? await Task.sleep(for: .seconds(0.33))
        guard !Task.isCancelled else { return }

        // 1.75–2.10: fade out。grainがもう一段薄くなりながら消える。
        withAnimation(.easeInOut(duration: 0.35)) {
            wholeOpacity = 0
            grainOpacity = 0
        }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

// MARK: - Concept G — Aperture Breath(絞りの一呼吸)
//
// 絞り羽根が開閉するだけでなく「息を吸って吐く」ように一度だけ呼吸する。
// 前回修復済みの羽根ジオメトリ(三角形+円clip)を流用し、開放時の微小な回転と
// 開ききった直後の単発の脈動、終盤の"閉じきらない"余韻を追加する。
struct PictriOpeningConceptG_ApertureBreath: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    @State private var bloomOpacity: Double = 0
    @State private var opening: CGFloat = 0
    @State private var bladeRotation: Double = 0
    @State private var coreScale: CGFloat = 1.0
    @State private var wordOpacity: Double = 0
    @State private var wordBlur: CGFloat = 18
    @State private var wholeOpacity: Double = 1

    private let bladeCount = 7
    private let bladeOuterRadius: CGFloat = 140
    private let irisMaxOpenRadius: CGFloat = 86

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PictriDarkTheme.openingTextPrimary, PictriDarkTheme.accent, PictriDarkTheme.accent.opacity(0)],
                                center: .center, startRadius: 0, endRadius: 130
                            )
                        )
                        .frame(width: 170, height: 170)
                        .blur(radius: 24)
                        .opacity(bloomOpacity)
                        .scaleEffect(coreScale)

                    irisBlades

                    Text("PicTri")
                        .font(PictriDarkTheme.display(52, weight: .regular))
                        .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                        .blur(radius: wordBlur)
                        .opacity(wordOpacity)
                }
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    private var irisBlades: some View {
        ZStack {
            ForEach(0..<bladeCount, id: \.self) { i in
                bladeShape(opening: opening)
                    .fill(PictriDarkTheme.openingSurface)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(bladeCount)) + bladeRotation))
            }
        }
        .frame(width: bladeOuterRadius * 2, height: bladeOuterRadius * 2)
        .clipShape(Circle())
    }

    private func bladeShape(opening: CGFloat) -> Path {
        let tipRadius = irisMaxOpenRadius * opening
        let outerRadius = bladeOuterRadius * 1.05
        let halfWidthAngle: CGFloat = (.pi / Double(bladeCount)) * 1.35

        var path = Path()
        let tip = CGPoint(x: tipRadius, y: 0)
        let outerA = CGPoint(x: outerRadius * cos(halfWidthAngle), y: outerRadius * sin(halfWidthAngle))
        let outerB = CGPoint(x: outerRadius * cos(-halfWidthAngle), y: outerRadius * sin(-halfWidthAngle))
        path.move(to: tip)
        path.addLine(to: outerA)
        path.addLine(to: outerB)
        path.closeSubpath()
        return path
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        // 0.15–0.35: 羽根の隙間からごく僅かな光が滲む(期待感)。
        withAnimation(.easeOut(duration: 0.20)) { bloomOpacity = 0.3 }
        try? await Task.sleep(for: .seconds(0.20))
        guard !Task.isCancelled else { return }

        // 0.35–0.75: 呼吸本体。羽根がわずかに回転しながら開く。
        withAnimation(.spring(response: 0.40, dampingFraction: 0.68)) {
            opening = 1
            bladeRotation = 6
        }
        withAnimation(.easeOut(duration: 0.45)) { bloomOpacity = 0.9 }
        try? await Task.sleep(for: .seconds(0.40))
        guard !Task.isCancelled else { return }

        // 0.75–0.95: 開ききった直後、単発の脈動(心拍のような1回だけの呼吸)。
        withAnimation(.easeOut(duration: 0.10)) { coreScale = 1.03 }
        try? await Task.sleep(for: .seconds(0.10))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.10)) { coreScale = 1.0 }
        try? await Task.sleep(for: .seconds(0.10))
        guard !Task.isCancelled else { return }

        // 0.95–1.35: coreの中でwordmarkにフォーカスが合う。
        withAnimation(.easeInOut(duration: 0.40)) {
            wordBlur = 0
            wordOpacity = 1
        }
        try? await Task.sleep(for: .seconds(0.40))
        guard !Task.isCancelled else { return }

        // 1.35–1.55: 羽根がほんの少しだけ閉じ戻る(完全には閉じない、一呼吸ついた余韻)。
        withAnimation(.easeInOut(duration: 0.20)) { opening = 0.85 }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }

        // 1.55–1.85: fade out。
        withAnimation(.easeInOut(duration: 0.30)) { wholeOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}

// MARK: - Concept H — Afterimage(記憶の残像)
//
// 明るい地平線の光が一瞬灯って消え、その残像(補色方向へずらした低彩度のゴースト)が
// 同じ位置にぼんやり残る、という実際の視覚残像現象を模す。残像の最も明るかった
// 中心点からwordmarkが結晶化する。色相反転の強度は「バグに見える」リスクを
// 避けるため控えめに設定している。
struct PictriOpeningConceptH_Afterimage: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false

    @State private var horizonOpacity: Double = 0
    @State private var ghostOpacity: Double = 0
    @State private var wordOpacity: Double = 0
    @State private var wordBlur: CGFloat = 22
    @State private var wholeOpacity: Double = 1

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            if reduceMotion {
                PictriOpeningReducedFallback(onComplete: onComplete)
            } else {
                ZStack {
                    // 地平線の光(空/地面を暗示する色温度差のみ、具体的な形は持たない)。
                    horizonGlow
                        .opacity(horizonOpacity)

                    // 残像(補色方向への軽いhue shift+低彩度、明るい版が消えた後に残る)。
                    horizonGlow
                        .hueRotation(.degrees(150))
                        .saturation(0.35)
                        .opacity(ghostOpacity)

                    Text("PicTri")
                        .font(PictriDarkTheme.display(52, weight: .regular))
                        .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                        .blur(radius: wordBlur)
                        .opacity(wordOpacity)
                }
                .accessibilityHidden(true)
            }
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            if reduceMotion { return }
            await runTimeline()
        }
    }

    /// 空/地面の色温度差だけで地平線を暗示する、抽象的な2層グラデーション。
    /// 具体的な地図・写真・水平線の描線は一切持たない。
    private var horizonGlow: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [PictriDarkTheme.accent.opacity(0.55), PictriDarkTheme.accent.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 150
                    )
                )
                .frame(width: 320, height: 180)
                .blur(radius: 46)
                .offset(y: -18)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [PictriDarkTheme.openingTextPrimary.opacity(0.28), PictriDarkTheme.openingTextPrimary.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 140
                    )
                )
                .frame(width: 260, height: 120)
                .blur(radius: 40)
                .offset(y: 30)
        }
    }

    private func runTimeline() async {
        try? await Task.sleep(for: .seconds(0.15))
        guard !Task.isCancelled else { return }

        // 0.15–0.45: 地平線の光が明るく灯る(この演出で最も明るい瞬間)。
        withAnimation(.easeOut(duration: 0.30)) { horizonOpacity = 0.9 }
        try? await Task.sleep(for: .seconds(0.30))
        guard !Task.isCancelled else { return }

        // 0.45–0.75: 明るい光が消えていくのと入れ替わりに、残像(ghost)が現れる。
        withAnimation(.easeIn(duration: 0.35)) { horizonOpacity = 0 }
        withAnimation(.easeOut(duration: 0.30).delay(0.05)) { ghostOpacity = 0.5 }
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled else { return }

        // 0.75–1.35: 残像の中心からwordmarkが結晶化する。
        withAnimation(.easeInOut(duration: 0.55)) {
            wordBlur = 0
            wordOpacity = 1
        }
        withAnimation(.easeInOut(duration: 0.6)) { ghostOpacity = 0.18 }
        try? await Task.sleep(for: .seconds(0.60))
        guard !Task.isCancelled else { return }

        // 1.35–1.60: 静止(ピークフレーム: 淡い地平線の名残+シャープなwordmark)。
        try? await Task.sleep(for: .seconds(0.25))
        guard !Task.isCancelled else { return }

        // 1.60–2.00: fade out。地平線の色味の記憶をほんの少し残したまま。
        withAnimation(.easeInOut(duration: 0.40)) { wholeOpacity = 0 }
        try? await Task.sleep(for: .seconds(0.40))
        guard !Task.isCancelled else { return }
        onComplete()
    }
}
