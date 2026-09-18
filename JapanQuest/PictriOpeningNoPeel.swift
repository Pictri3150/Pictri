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

// v16 P1 LAUNCH DURATION FIX: 実機動画計測で、アプリ内Launch演出が実質
// 約1.2〜1.3秒しかなく、PicTriロゴを認識する前にHomeへ切り替わっている
// ことが判明した(アイコンタップ2.0秒→Opening出現2.25秒→Home表示3.5秒、
// という動画上の絶対時刻から逆算)。前ラウンド(v10)でstillnessEnd/
// totalDurationを延長したはずが、実機では反映されていなかった(実機側の
// Reduce Motion設定や古いBuildが動いていた可能性がある)。今回は
// 「0.00-0.20暗闇 → 0.20-0.90出現 → 0.90-1.80保持 → 1.80-2.60 Homeへ
// クロスフェード、合計2.6秒」という明示的な目標タイムラインに合わせて
// 数値を作り直した。emergence/reveal自体のcurve(`pictriTypographyFinalGold`
// の内部0.80秒assembly、`pictriNoPeelEase`のsmootherstep)は変更していない
// (タイミングの窓=定数だけを変更)。
//
// 旧`pictriNoPeelEmergenceEnd`/`pictriNoPeelSharpLockEnd`はどの計算式からも
// 参照されていない死にコードだったため削除した(grep で使用箇所ゼロを確認)。
let pictriNoPeelDarkness = 0.20
let pictriNoPeelStillnessEnd = 1.80 // = reveal開始(暗闇0.20 + 出現/保持で1.60秒)
let pictriNoPeelRevealDuration = 0.80 // reveal終了 = 2.60
let pictriNoPeelTotalDuration = 2.60 // 目標2.6秒(許容範囲2.4〜2.8秒)ちょうど。
// reveal完了時点で既にveilが透明・wordmarkが不可視になるため、旧v10のような
// 追加settle余白(0.30秒)は今回付けない(合計を2.6秒に収めるため)。

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
/// timeline(stillnessEnd 1.80 / revealDuration 0.80)と同期させる。
/// v6 HOLD TIMING MICRO FIX: この関数はPictriFocusHandoffReducedFallbackの
/// private定数とは別に0.65をハードコードしていたため、そちらのstillnessEndを
/// 0.65→0.80へ変更した際に見落とすとHome側のblur解除タイミングだけズレて
/// 残る(Wordmarkは長く保持されるのにHomeだけ先にsharpになる)desyncが
/// 起きるところだった。値を揃えて同期させる。
/// v16 P1 LAUNCH DURATION FIX: 「Reduce Motionを理由に起動演出を大幅短縮
/// しない、最小表示時間はフル尺と同程度(約2.4〜2.6秒)を維持する」という
/// 明示的な要求を受け、stillnessEnd/revealDurationをフル尺(1.80/0.80)と
/// 揃えた(v10までの「Reduce Motionは控えめに短くする」方針から転換)。
/// blur自体は視差を伴わない単純なopacity変化として維持する(scale/blurの
/// 大きな動きは追加しない)。
func pictriHandoffHomeStateReduced(elapsed: Double) -> PictriHomeOpticalState {
    let t = pictriNoPeelEase(min(max((elapsed - 1.80 - pictriHandoffHomeLeadDelay) / (0.80 - pictriHandoffHomeLeadDelay), 0), 1))
    return PictriHomeOpticalState(
        blur: 24 * (1 - t), brightness: -0.18 * (1 - t),
        saturation: 0.85 + 0.15 * t, contrast: 1.0, scale: 1.0
    )
}

/// v16 P1 LAUNCH DURATION FIX: 「Launch演出の最小表示時間」と「実際の
/// アプリ初期化完了」の両方を待つ、という要求に対応する薄いゲート。
/// このアプリのHome初期表示(`QuestMemoryStore`等)は現時点ではすべて
/// 同期処理(モックデータ/ローカルファイルの同期読み込みのみ、
/// ネットワーク待ちは存在しない)であるため、`isReady()`は事実上
/// 即座に完了する。ここで構造だけ「両方待つ(async letで並行に走らせ、
/// 両方await)」形にしておくことで、将来Home初期化に本当に時間の掛かる
/// 非同期処理(例: 大量の実写真読み込み)が追加された場合も、
/// Opening側のコードを変更せずに「初期化が長ければその完了を待つ」
/// 挙動へ自然に拡張できる。
enum PictriLaunchReadiness {
    static func waitUntilAppIsReady() async {
        // 現時点では待つべき非同期初期化が存在しないため、1 tickだけ
        // Task schedulerへ制御を返す(Thread.sleep等でmain threadを
        // ブロックしない、というルールを形式的にも満たすための最小待機)。
        await Task.yield()
    }
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
            // 「最小表示時間」と「初期化完了」を並行に走らせ、両方が終わる
            // まで待つ(片方が終わったら即座に進む、というraceにはしない)。
            async let minimumDisplay: Void = { try? await Task.sleep(for: .seconds(totalDuration)) }()
            async let appReady: Void = PictriLaunchReadiness.waitUntilAppIsReady()
            _ = await (minimumDisplay, appReady)
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

    // v16 P1 LAUNCH DURATION FIX: 「Reduce Motionを理由に起動演出を0.5〜1秒へ
    // 短縮しない、最小表示時間はフル尺と同程度(約2.4〜2.6秒)を維持する」
    // という明示的な要求を受け、stillnessEnd/revealDuration/totalDurationを
    // フル尺(`pictriNoPeelStillnessEnd`/`pictriNoPeelRevealDuration`/
    // `pictriNoPeelTotalDuration`)と完全に同じ値へ揃えた(v6〜v10までの
    // 「Reduce Motionは控えめに短くする」方針から転換)。動きの大きい
    // scale/blurは使わず、下記bodyでも`.blur`を撤去してopacityのみの
    // 変化にした(3D回転・parallaxは元から使っていない)。
    private let assemblyBaseDelay = pictriNoPeelDarkness
    private let stillnessEnd = pictriNoPeelStillnessEnd
    private let revealDuration = pictriNoPeelRevealDuration
    private let totalDuration = pictriNoPeelTotalDuration

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
            let fragElapsed = max(0, elapsed - assemblyBaseDelay)
            let t = pictriNoPeelEase(min(max((elapsed - stillnessEnd) / revealDuration, 0), 1))
            let opacity = 1 - t * t * t
            ZStack {
                PictriDarkTheme.openingSurface.opacity(1 - t)
                // v16: 動きの大きいscale/blurを追加しない方針のため、
                // 旧`.blur(radius: 6.0 * t)`を撤去しopacityのみの変化にした。
                pictriTypographyFinalGold(elapsed: fragElapsed, fontSize: finalWordmarkFont)
                    .opacity(opacity)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            startDate = Date()
            async let minimumDisplay: Void = { try? await Task.sleep(for: .seconds(totalDuration)) }()
            async let appReady: Void = PictriLaunchReadiness.waitUntilAppIsReady()
            _ = await (minimumDisplay, appReady)
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
                // v10 HARD CUT FIX: 完了時点では数値上すでにveil/wordmarkの
                // opacityはほぼ0まで収束しているはずだが(reveal自体の
                // curveで消えている)、`isOpeningActive`をfalseにした瞬間
                // このView自体がZStackから即座に取り除かれる(=SwiftUIの
                // 通常の条件分岐は暗黙にはアニメーションしない)ため、
                // タイミングの微小なズレ(Task.sleepとTimelineViewの
                // clockのわずかな差等)があった場合に「パッと切り替わる」
                // hard cutとして体感されるリスクが残っていた。
                // `.transition(.opacity)` + `withAnimation`で除去自体を
                // 必ず滑らかなcross-fadeにし、curve側の精度に依存せず
                // 「別画面へ突然切り替わる」体感を構造的に防ぐ。
                opening {
                    withAnimation(.easeOut(duration: 0.35)) {
                        isOpeningActive = false
                    }
                }
                .zIndex(10)
                .transition(.opacity)
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
