import SwiftUI

// MARK: - NO PEEL SIGNATURE FINAL(2026-08-24)
//
// ユーザーの最終判断: Production OpeningからPeel/めくれ表現を完全撤去する。
// 88点まで技術的に磨いたPeelも、実際にユーザーが見た結果「捲れる時間が
// 短く、何が起きているのか分からない」という根本的な問題が残った。
// 起動画面は技術的な高度さより「一度見ただけで理解できる」ことを
// 優先する。
//
// 新しい核: 暗闇 → PicTriがじわんと浮かび上がる → sharp → 静止 →
// 写真の"ピントが移る"ように世界のfocus/exposure/depthが変化 →
// 実Homeが自然に現れる → PicTriはHomeへ溶ける。
//
// Peel関連の実装(`PictriOpeningPeelLab.swift`,
// `PictriOpeningCoreAnimationCurl.swift`)はDEBUG比較用Labとして
// そのまま残し、Production経路(`PictriOpeningView`→
// `PictriRootWithOpening`)からは完全に参照を外す。Cold LaunchでPeel
// 関連のView/StripLayer等が一切生成されないため、そのぶん軽量になる。

// MARK: - Home側光学状態

/// Home(実ContentView())へOpening側のroot wrapperから適用する、
/// フォーカス/露出/深度の光学状態。HomeView/ContentView自体のコードは
/// 一切変更せず、呼び出しサイトにmodifierとして重ねるだけ。
struct PictriHomeOpticalState {
    var blur: CGFloat
    var brightness: Double
    var saturation: Double
    var contrast: Double
    var scale: CGFloat

    static let identity = PictriHomeOpticalState(blur: 0, brightness: 0, saturation: 1, contrast: 1, scale: 1)
}

// MARK: - 共有タイムライン定数(Timing T2)

let pictriNoPeelDarkness = 0.45
let pictriNoPeelEmergenceEnd = 1.30
let pictriNoPeelSharpLockEnd = 1.50
// v6 HOLD TIMING MICRO FIX: 「PicTriが完成してからHomeへ移り始めるまでが
// 短すぎる」という実機フィードバックを受け、sharpLockEnd→stillnessEndの
// HOLD区間を0.40秒(旧1.90-1.50)から0.80秒へ拡大した。0.55/0.80/1.05の
// 3候補を比較し、0.55は既存とほぼ体感差が無く、1.05は「止まった」と
// 感じられるリスクが高いと判断、ユーザー希望レンジ(0.75〜0.90秒)の
// 中心である0.80を採用した。Darkness/emergence/sharpLock/reveal choreography
// 自体(pictriHandoffWordmark/pictriHandoffHomeState)には一切手を入れて
// いない(タイミングの数値だけを変更)。
let pictriNoPeelStillnessEnd = 2.30 // = reveal開始(HOLD = stillnessEnd - sharpLockEnd = 0.80秒)
let pictriNoPeelRevealDuration = 1.30 // reveal終了 = 3.60
let pictriNoPeelTotalDuration = 3.90 // reveal完了後、旧比と同じ0.30秒のsettle余白を維持

/// 中盤が急すぎない、なだらかなsmootherstep。Peelのような物理的な
/// 「持ち上がり」ではなく、光学的な変化(focus/exposure)にふさわしい
/// 単純な滑らかさのみを持たせる。
func pictriNoPeelEase(_ t: Double) -> Double {
    let c = min(max(t, 0), 1)
    return c * c * c * (c * (c * 6 - 15) + 10)
}

private func pictriNoPeelRevealT(_ elapsed: Double) -> Double {
    pictriNoPeelEase(min(max((elapsed - pictriNoPeelStillnessEnd) / pictriNoPeelRevealDuration, 0), 1))
}

/// Opening自身のdark surface(veil)。revealが進むほど透明になり、
/// 完全に消えるとOpening層そのものが何も描画しない状態になる。
func pictriNoPeelVeilOpacity(elapsed: Double) -> Double {
    1 - pictriNoPeelRevealT(elapsed)
}

// MARK: - Wordmark消失スタイル(3案で切り替え)

enum PictriWordmarkDissolveStyle {
    case focusOut       // Concept A: ピントが外れるように柔らかくぼけて消える
    case contrastMerge  // Concept B: コントラストが下がりHomeへ溶け込む
    case depthRecede    // Concept C: わずかに縮小・後退しながら消える
}

/// wordmarkのemergence(既存`pictriTypographyFinalGold`をそのまま利用)+
/// reveal期における消失処理を1つの関数にまとめる。
func pictriNoPeelWordmark(elapsed: Double, style: PictriWordmarkDissolveStyle) -> AnyView {
    let fragElapsed = max(0, elapsed - pictriNoPeelDarkness)
    let base = pictriTypographyFinalGold(elapsed: fragElapsed, fontSize: finalWordmarkFont)
    // iteration 2: wordmarkの消失をHomeのreveal開始より0.18秒だけ遅らせる。
    // 同時に動くと「何が起きているか」が同時多発的に見えてしまうため、
    // 「Homeが先にsharpになり始める → その後PicTriが道を譲るように消える」
    // という順序をはっきりさせ、Clarityを上げる。
    let wordmarkDelay = 0.18
    let revealT = pictriNoPeelEase(
        min(max((elapsed - pictriNoPeelStillnessEnd - wordmarkDelay) / (pictriNoPeelRevealDuration - wordmarkDelay), 0), 1)
    )

    switch style {
    case .focusOut:
        let blur = 7.0 * revealT
        let opacity = 1 - min(1, revealT * 1.25)
        return AnyView(base.blur(radius: blur).opacity(opacity))
    case .contrastMerge:
        let contrast = 1 - 0.55 * revealT
        let opacity = 1 - min(1, revealT * 1.15)
        return AnyView(base.contrast(contrast).opacity(opacity))
    case .depthRecede:
        let scale = 1 - 0.12 * revealT
        let blur = 3.0 * revealT
        let opacity = 1 - min(1, revealT * 1.2)
        return AnyView(base.scaleEffect(scale).blur(radius: blur).opacity(opacity))
    }
}

// MARK: - Concept別 Home光学状態

/// CONCEPT A — FOCUS TRANSFER: blurが主役。カメラのピントが奥へ移る
/// ような体験。brightness/saturationは控えめに追従するだけ。
func pictriNoPeelHomeState_Focus(elapsed: Double) -> PictriHomeOpticalState {
    let t = pictriNoPeelRevealT(elapsed)
    // iteration 3: 初期のblur/暗さをより深くし(26→32pt, -0.38→-0.45)、
    // 「わずかにぼやけている」ではなく「完全に合焦していない世界」から
    // 開放される、という状態差を大きくした(新しいeffectの追加ではなく、
    // 既存パラメータのみの調整)。
    return PictriHomeOpticalState(
        blur: 32 * (1 - t), brightness: -0.45 * (1 - t),
        saturation: 0.38 + 0.62 * t, contrast: 1.0, scale: 1.0
    )
}

/// CONCEPT B — LATENT DEVELOPMENT: contrastとsaturationが主役。
/// セピア/褐色を一切使わず、単に「まだ定着していない」低contrast/低
/// saturationから、現代的な写真の階調へ収束する。
func pictriNoPeelHomeState_Latent(elapsed: Double) -> PictriHomeOpticalState {
    let t = pictriNoPeelRevealT(elapsed)
    return PictriHomeOpticalState(
        blur: 14 * (1 - t), brightness: -0.15 * (1 - t),
        saturation: 0.3 + 0.7 * t, contrast: 0.55 + 0.45 * t, scale: 1.0
    )
}

/// Reduce Motion版のHome光学状態。`PictriNoPeelReducedFallback`の短い
/// timeline(stillnessEnd 0.65 / revealDuration 0.55)と同期させる
/// (フル尺のタイムラインのまま使うと、Reduce Motion時にOpeningが先に
/// `onComplete`してもHome側のblurが解決しきらないまま残ってしまう)。
func pictriNoPeelHomeState_FocusReduced(elapsed: Double) -> PictriHomeOpticalState {
    let t = pictriNoPeelEase(min(max((elapsed - 0.65) / 0.55, 0), 1))
    return PictriHomeOpticalState(
        blur: 18 * (1 - t), brightness: -0.3 * (1 - t),
        saturation: 0.5 + 0.5 * t, contrast: 1.0, scale: 1.0
    )
}

/// CONCEPT C — OPTICAL DEPTH OPEN: scaleが主役。Homeがわずかに手前へ
/// 「やってくる」ような奥行きの変化。blur/brightnessは控えめな補助。
func pictriNoPeelHomeState_Depth(elapsed: Double) -> PictriHomeOpticalState {
    let t = pictriNoPeelRevealT(elapsed)
    return PictriHomeOpticalState(
        blur: 16 * (1 - t), brightness: -0.22 * (1 - t),
        saturation: 0.55 + 0.45 * t, contrast: 1.0, scale: 0.965 + 0.035 * t
    )
}

// MARK: - SIGNATURE FOCUS HANDOFF(2026-08-24、続きのラウンド)
//
// 10倍slow-motionでの実機監査(`/tmp/pictri_opening_focus_signature/
// baseline_audit.md`)で、旧Focus Transferは「PicTriが完全にsharpな
// まま長時間保持され、Homeだけが先に大きくblur解除され、PicTriは
// 最後にほぼ一括で消える」という非対称な体感になっていたと判明した。
// PicTri側とHomeがreveal開始と同時にほぼ同じcurveを共有していたため、
// PicTri側の変化開始(0.18秒遅延+急なopacity dropoff)が結果的に
// "後から慌てて消える"ように見えていた。
//
// 今回のSignature Focus Handoffは、PicTriが先に手放し始め、Homeが
// 追いかけて合焦し、両者が同じ終着点で完了する、という明確な
// choreographyへ再設計する:
//
//   PicTriが柔らかくなり始める(stillness終了と同時、most early)
//     ↓ 約130ms
//   Homeのfocus shiftが始まる
//     ↓ 約160ms
//   PicTriのluminance/opacityが本格的に退く
//     ↓
//   Home完全sharp、PicTri完全消失(同じ終着点)
//
// PicTri側のcurveがHome側より"早く"始まることで、視線誘導が
// 「Homeが勝手に浮かぶ」のではなく「PicTriが道を譲る」という
// 能動的な印象になる。

/// PicTri側とHome側、両方の進行度を計算するための共有の"leadOffset"。
/// PicTriのcurveはreveal開始と同時に始まり(lead)、Home側のcurveは
/// `homeLeadDelay`だけ遅れて始まる(follow)。両者は同じ終着点
/// (stillnessEnd + revealDuration)で1.0に到達する。
let pictriHandoffHomeLeadDelay = 0.13

private func pictriHandoffPicTriT(_ elapsed: Double) -> Double {
    pictriNoPeelEase(min(max((elapsed - pictriNoPeelStillnessEnd) / pictriNoPeelRevealDuration, 0), 1))
}

private func pictriHandoffHomeT(_ elapsed: Double) -> Double {
    let start = pictriNoPeelStillnessEnd + pictriHandoffHomeLeadDelay
    let duration = max(pictriNoPeelRevealDuration - pictriHandoffHomeLeadDelay, 0.001)
    return pictriNoPeelEase(min(max((elapsed - start) / duration, 0), 1))
}

enum PictriFocusHandoffStyle {
    case rack    // A: PRECISION RACK FOCUS — blurのみ、露出変化最小
    case latent  // B: LATENT FOCUS HANDOFF — contrast/saturation/luminanceが中心
    case depth   // C: DEPTH BREATH HANDOFF — 極小のscale(lens breathing)を追加
}

/// PicTri側。opacityは「最後の整理」としてのみ使う(cubicで終盤にだけ
/// 落ちる)。blur/contrast/scaleが本体で、picTriT(Homeより早く進む)に
/// 従って早めに変化を始める。
func pictriHandoffWordmark(elapsed: Double, style: PictriFocusHandoffStyle) -> AnyView {
    let fragElapsed = max(0, elapsed - pictriNoPeelDarkness)
    let base = pictriTypographyFinalGold(elapsed: fragElapsed, fontSize: finalWordmarkFont)
    let t = pictriHandoffPicTriT(elapsed)
    // opacityは終盤(t→1)にだけ効く3乗カーブ。序盤はblur/contrastだけが
    // 変化し、"opacity fadeで消えた"という印象を避ける。
    let opacity = 1 - t * t * t

    switch style {
    case .rack:
        let blur = 8.0 * t
        let contrast = 1 - 0.12 * t
        return AnyView(base.blur(radius: blur).contrast(contrast).opacity(opacity))
    case .latent:
        let contrast = 1 - 0.5 * t
        let blur = 4.0 * t
        return AnyView(base.contrast(contrast).blur(radius: blur).opacity(opacity))
    case .depth:
        let scale = 1 - 0.010 * t
        let blur = 3.0 * t
        return AnyView(base.scaleEffect(scale).blur(radius: blur).opacity(opacity))
    }
}

/// Home側。picTriTより`pictriHandoffHomeLeadDelay`だけ遅れて始まる
/// homeTに従う。
func pictriHandoffHomeState(elapsed: Double, style: PictriFocusHandoffStyle) -> PictriHomeOpticalState {
    let t = pictriHandoffHomeT(elapsed)
    switch style {
    case .rack:
        // 露出変化は最小に留め、blurだけでfocus shiftを表現する。
        return PictriHomeOpticalState(
            blur: 30 * (1 - t), brightness: -0.16 * (1 - t),
            saturation: 0.85 + 0.15 * t, contrast: 1.0, scale: 1.0
        )
    case .latent:
        // 「まだ定着していない」低contrast/低saturationから現代的な
        // 階調へ収束する。セピア/褐色は使わない。
        return PictriHomeOpticalState(
            blur: 22 * (1 - t), brightness: -0.22 * (1 - t),
            saturation: 0.55 + 0.45 * t, contrast: 0.62 + 0.38 * t, scale: 1.0
        )
    case .depth:
        return PictriHomeOpticalState(
            blur: 26 * (1 - t), brightness: -0.20 * (1 - t),
            saturation: 0.7 + 0.3 * t, contrast: 1.0, scale: 1.012 - 0.012 * t
        )
    }
}

/// Reduce Motion版のHome光学状態(Focus Handoff採用案用)。`PictriFocusHandoffReducedFallback`の
/// 短いtimeline(stillnessEnd 0.80 / revealDuration 0.55)と同期させる。
/// v6 HOLD TIMING MICRO FIX: この関数はPictriFocusHandoffReducedFallbackの
/// private定数とは別に0.65をハードコードしていたため、そちらのstillnessEndを
/// 0.65→0.80へ変更した際に見落とすとHome側のblur解除タイミングだけズレて
/// 残る(Wordmarkは長く保持されるのにHomeだけ先にsharpになる)desyncが
/// 起きるところだった。値を揃えて同期させる。
func pictriHandoffHomeStateReduced(elapsed: Double) -> PictriHomeOpticalState {
    let t = pictriNoPeelEase(min(max((elapsed - 0.80 - pictriHandoffHomeLeadDelay) / (0.55 - pictriHandoffHomeLeadDelay), 0), 1))
    return PictriHomeOpticalState(
        blur: 24 * (1 - t), brightness: -0.18 * (1 - t),
        saturation: 0.85 + 0.15 * t, contrast: 1.0, scale: 1.0
    )
}

struct PictriFocusHandoffEngine: View {
    var onComplete: () -> Void
    var style: PictriFocusHandoffStyle
    var totalDuration: Double = pictriNoPeelTotalDuration

    @State private var hasStarted = false
    @State private var startDate: Date?

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
            ZStack {
                PictriDarkTheme.openingSurface
                    .opacity(pictriNoPeelVeilOpacity(elapsed: elapsed))
                pictriHandoffWordmark(elapsed: elapsed, style: style)
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

struct PictriFocusHandoffConcept_Rack: View {
    var onComplete: () -> Void
    var body: some View { PictriFocusHandoffEngine(onComplete: onComplete, style: .rack) }
}

struct PictriFocusHandoffConcept_Latent: View {
    var onComplete: () -> Void
    var body: some View { PictriFocusHandoffEngine(onComplete: onComplete, style: .latent) }
}

struct PictriFocusHandoffConcept_Depth: View {
    var onComplete: () -> Void
    var body: some View { PictriFocusHandoffEngine(onComplete: onComplete, style: .depth) }
}

struct PictriFocusHandoffReducedFallback: View {
    var onComplete: () -> Void
    @State private var hasStarted = false
    @State private var startDate: Date?

    // v6 HOLD TIMING MICRO FIX: Reduce Motion版もフル尺と同じ趣旨で
    // hold(stillnessEnd)を0.65→0.80秒へ延長。ただし「通常版ほど長い
    // holdにしなくてよい」という方針通り、フル尺の+0.40秒よりずっと
    // 控えめな+0.15秒に留めた(0.35〜0.50秒レンジの上寄り)。
    private let assemblyBaseDelay = 0.20
    private let stillnessEnd = 0.80
    private let revealDuration = 0.55
    private let totalDuration = 1.55

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
            let fragElapsed = max(0, elapsed - assemblyBaseDelay)
            let t = pictriNoPeelEase(min(max((elapsed - stillnessEnd) / revealDuration, 0), 1))
            let opacity = 1 - t * t * t
            ZStack {
                PictriDarkTheme.openingSurface.opacity(1 - t)
                pictriTypographyFinalGold(elapsed: fragElapsed, fontSize: finalWordmarkFont)
                    .blur(radius: 6.0 * t)
                    .opacity(opacity)
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

// MARK: - 共有Engine(Opening surface + wordmark)

struct PictriNoPeelEngine: View {
    var onComplete: () -> Void
    var wordmarkStyle: PictriWordmarkDissolveStyle
    var totalDuration: Double = pictriNoPeelTotalDuration

    @State private var hasStarted = false
    @State private var startDate: Date?

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
            ZStack {
                PictriDarkTheme.openingSurface
                    .opacity(pictriNoPeelVeilOpacity(elapsed: elapsed))
                pictriNoPeelWordmark(elapsed: elapsed, style: wordmarkStyle)
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

// MARK: - Root: HomeへOpeningと同じ時間軸で光学状態を適用

/// `ContentView()`(実Home)へ、Opening側と全く同じ経過時間(elapsed)を
/// 使ってfocus/exposure/depthの変化を適用するroot構造。ContentView/
/// HomeView自体のコードは一切変更しない。OpeningとHome、両方が同じ
/// `.task`起動パターン(このView自身の`startDate`)を共有することで、
/// 別々のTimelineViewでも自然に同期する。
struct PictriNoPeelRoot<OpeningContent: View>: View {
    var homeState: (Double) -> PictriHomeOpticalState
    var totalDuration: Double
    @ViewBuilder var opening: (@escaping () -> Void) -> OpeningContent

    @State private var isOpeningActive = true
    @State private var startDate: Date?

    var body: some View {
        ZStack {
            TimelineView(.animation) { context in
                let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
                let state = isOpeningActive ? homeState(elapsed) : .identity
                ContentView()
                    .blur(radius: state.blur)
                    .brightness(state.brightness)
                    .saturation(state.saturation)
                    .contrast(state.contrast)
                    .scaleEffect(state.scale)
            }

            if isOpeningActive {
                opening { isOpeningActive = false }
                    .zIndex(10)
            }
        }
        .statusBarHidden(isOpeningActive)
        .task {
            guard startDate == nil else { return }
            startDate = Date()
        }
    }
}

// MARK: - 3案(DEBUG比較用 + 最終採用候補)

struct PictriNoPeelConcept_Focus: View {
    var onComplete: () -> Void
    var body: some View {
        PictriNoPeelEngine(onComplete: onComplete, wordmarkStyle: .focusOut)
    }
}

struct PictriNoPeelConcept_Latent: View {
    var onComplete: () -> Void
    var body: some View {
        PictriNoPeelEngine(onComplete: onComplete, wordmarkStyle: .contrastMerge)
    }
}

struct PictriNoPeelConcept_Depth: View {
    var onComplete: () -> Void
    var body: some View {
        PictriNoPeelEngine(onComplete: onComplete, wordmarkStyle: .depthRecede)
    }
}

// MARK: - Reduce Motion(Peel関連コードを一切使わない)

struct PictriNoPeelReducedFallback: View {
    var onComplete: () -> Void
    @State private var hasStarted = false
    @State private var startDate: Date?

    private let assemblyBaseDelay = 0.20
    private let stillnessEnd = 0.65
    private let revealDuration = 0.55
    private let totalDuration = 1.30

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
            let fragElapsed = max(0, elapsed - assemblyBaseDelay)
            let revealT = pictriNoPeelEase(min(max((elapsed - stillnessEnd) / revealDuration, 0), 1))
            ZStack {
                PictriDarkTheme.openingSurface.opacity(1 - revealT)
                pictriTypographyFinalGold(elapsed: fragElapsed, fontSize: finalWordmarkFont)
                    .opacity(1 - min(1, revealT * 1.2))
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
