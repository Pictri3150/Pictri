import SwiftUI

// MARK: - Opening Signature Lab(2026-08-23)— Block Typography + Fracture Reveal
//
// ユーザー評価により現行Opening(Exposure Print, v5)はCへ再評価された。
// 「文字そのものにダイナミックさが無い」「ロゴが出てくるだけ」という指摘に対し、
// 今回は
//   BUILD(断片が組み上がる)→ FOCUS(焦点が合う)→ TENSION(静止の緊張)→
//   FRACTURE(亀裂)→ REVEAL(Homeが覗く)→ MEMORY(記憶に残る)
// という一連のドラマを持つ4案を実装する。
//
// 4案はすべて共通のエンジン(このファイル)を土台に、パラメータと配色処理だけを
// 変えて差別化する(同じ仕組みを4回書き直すのではなく、1つの信頼できる仕組みの
// 上で"演出だけ"を変える。過剰な抽象化を避けつつ、無駄な重複も避けるための構成)。
//
// 技術選定: 各fragmentの複雑な個別タイミング(depth・delay・duration・easingが
// fragmentごとに異なる)を表現するため、SwiftUIの`withAnimation`による単一値の
// 補間ではなく、`TimelineView(.animation)`で実時間(elapsed)を取得し、
// fragmentごとに独自のcustom easing関数で手動補間する設計にしている
// (「Linear animation禁止、custom Cubic Bezier / keyframe的な制御」という要求に対応)。

// MARK: - 決定論的PRNG

enum PictriSignatureRNG {
    /// 固定seedから、常に同じ順序で同じ値を返すクロージャを作る。
    /// 「毎起動同じブランドモーション」を保証するため、Date/randomは一切使わない。
    static func makeGenerator(seed: UInt64) -> () -> Double {
        var state = seed
        return {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) & 0xFFFF) / Double(0xFFFF)
        }
    }
}

// MARK: - Custom Easing(linear/spring禁止に対応)

enum PictriSignatureEasing {
    /// fragment settle: fast-in slow-settle(序盤速く、終盤にゆっくり収まる)。
    static func fragmentSettle(_ t: Double) -> Double {
        let c = min(max(t, 0), 1)
        return 1 - pow(1 - c, 3)
    }

    /// crack propagation: 立ち上がりは非常に遅く、中盤で一気に進み、
    /// 終盤は柔らかく収まる、という3段階のpiecewise curve
    /// (外部ライブラリ無しで表現する、実質的なcustom bezier相当)。
    static func crackPropagation(_ t: Double) -> Double {
        let c = min(max(t, 0), 1)
        if c < 0.22 {
            let local = c / 0.22
            return 0.06 * local * local
        } else if c < 0.75 {
            let local = (c - 0.22) / 0.53
            return 0.06 + 0.82 * local
        } else {
            let local = (c - 0.75) / 0.25
            return 0.88 + 0.12 * (1 - pow(1 - local, 2))
        }
    }
}

// MARK: - Fragment仕様

struct SignatureFragmentSpec {
    let tileRect: CGRect
    let delay: Double
    let duration: Double
    let startOffset: CGSize
    let startScale: CGFloat
    let startBlur: CGFloat
    let startRotation: Double
}

/// 現在時刻(elapsed)から、fragmentの現在の見た目(offset/scale/blur/rotation/opacity)を導出する。
/// 全conceptがこの1つの計算式を共有する。
func signatureFragmentTransform(
    spec: SignatureFragmentSpec,
    elapsed: Double
) -> (offset: CGSize, scale: CGFloat, blur: CGFloat, rotation: Double, opacity: Double) {
    guard elapsed >= spec.delay else {
        return (spec.startOffset, spec.startScale, spec.startBlur, spec.startRotation, 0)
    }
    let local = spec.duration > 0 ? min(max((elapsed - spec.delay) / spec.duration, 0), 1) : 1
    let eased = PictriSignatureEasing.fragmentSettle(local)
    // opacityはdurationより短い0.14秒で先に立ち上がる(「気配が先に見え、その後
    // 焦点が合う」という写真的な感覚を出すため、透明度と収束を別カーブにする)。
    let appeared = min(1, (elapsed - spec.delay) / 0.14)

    let offset = CGSize(
        width: spec.startOffset.width * (1 - eased),
        height: spec.startOffset.height * (1 - eased)
    )
    let scale = spec.startScale + (1 - spec.startScale) * eased
    let blur = spec.startBlur * (1 - eased)
    let rotation = spec.startRotation * (1 - eased)
    return (offset, scale, blur, rotation, appeared)
}

/// fragment grid生成。cols×rows個のtileへ均等分割し、各tileへ決定論的パラメータを割り当てる。
func makeSignatureFragments(
    canvasSize: CGSize,
    cols: Int,
    rows: Int,
    seed: UInt64,
    maxDelay: Double,
    durationRange: ClosedRange<Double>,
    offsetMagnitude: CGFloat,
    offsetDirection: (_ tileCenter: CGPoint, _ canvasCenter: CGPoint) -> CGSize,
    blurRange: ClosedRange<CGFloat>,
    scaleRange: ClosedRange<CGFloat>,
    rotationRange: ClosedRange<Double>
) -> [SignatureFragmentSpec] {
    let next = PictriSignatureRNG.makeGenerator(seed: seed)
    var specs: [SignatureFragmentSpec] = []
    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

    // 行の高さ・各行内の列幅を均等グリッドから意図的に崩す(合計は
    // canvasSizeに正確に一致させ、隙間/重なりを作らない)。単純な格子に
    // 見えないよう、行ごとに列幅の乱れ方も変える(brick/masonry調の分割)。
    // 「四角く切っただけ」に見えないための土台。
    var rowWeights: [CGFloat] = (0..<rows).map { _ in 0.72 + CGFloat(next()) * 0.56 }
    let rowWeightSum = rowWeights.reduce(0, +)
    rowWeights = rowWeights.map { $0 / rowWeightSum }

    var rowY: CGFloat = 0
    for r in 0..<rows {
        let rowH = rowWeights[r] * canvasSize.height
        var colWeights: [CGFloat] = (0..<cols).map { _ in 0.68 + CGFloat(next()) * 0.64 }
        let colWeightSum = colWeights.reduce(0, +)
        colWeights = colWeights.map { $0 / colWeightSum }

        var colX: CGFloat = 0
        for c in 0..<cols {
            let colW = colWeights[c] * canvasSize.width
            let rect = CGRect(x: colX, y: rowY, width: colW, height: rowH)
            colX += colW
            let tileCenter = CGPoint(x: rect.midX, y: rect.midY)
            let delay = next() * maxDelay
            let duration = durationRange.lowerBound + next() * (durationRange.upperBound - durationRange.lowerBound)
            let dir = offsetDirection(tileCenter, center)
            let mag = offsetMagnitude * (0.55 + CGFloat(next()) * 0.9)
            let startOffset = CGSize(width: dir.width * mag, height: dir.height * mag)
            let blur = blurRange.lowerBound + CGFloat(next()) * (blurRange.upperBound - blurRange.lowerBound)
            let scale = scaleRange.lowerBound + CGFloat(next()) * (scaleRange.upperBound - scaleRange.lowerBound)
            let rotation = rotationRange.lowerBound + next() * (rotationRange.upperBound - rotationRange.lowerBound)
            specs.append(SignatureFragmentSpec(
                tileRect: rect,
                delay: delay,
                duration: duration,
                startOffset: startOffset,
                startScale: scale,
                startBlur: blur,
                startRotation: rotation
            ))
        }
        rowY += rowH
    }
    return specs
}

/// tileCenterがcanvasCenterから外側へ広がる方向の単位ベクトル(モノリスが外側から
/// 引き寄せられて組み上がる/圧力で内側へ押し込まれる、両方の土台として使う)。
func signatureOutwardDirection(tileCenter: CGPoint, canvasCenter: CGPoint) -> CGSize {
    let dx = tileCenter.x - canvasCenter.x
    let dy = tileCenter.y - canvasCenter.y
    let len = max(sqrt(dx * dx + dy * dy), 1)
    return CGSize(width: dx / len, height: dy / len)
}

// MARK: - 共有Fragment描画

/// 「PicTri」を1枚の巨大なcanvas上に描き、各fragmentはそのcanvasの一部分だけを
/// maskで切り出した"断片"として個別にoffset/scale/blur/rotationを持つ。
/// 全fragmentのoffsetが0(=eased=1)になった瞬間、元のレイアウトと完全に一致し、
/// 「PicTri」が1つの単語として読める(文字を分割して動かしているのではなく、
/// 同じ完成形のtile切り出しを個別に動かしている、という実装)。
struct SignatureAssemblyGlyph: View {
    let font: Font
    let textColor: Color
    let canvasSize: CGSize
    let fragments: [SignatureFragmentSpec]
    let elapsed: Double

    var body: some View {
        ZStack {
            ForEach(Array(fragments.enumerated()), id: \.offset) { _, spec in
                let t = signatureFragmentTransform(spec: spec, elapsed: elapsed)
                Text("PicTri")
                    .font(font)
                    .foregroundStyle(textColor)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .mask(
                        Rectangle()
                            .frame(width: max(spec.tileRect.width - 0.5, 1), height: max(spec.tileRect.height - 0.5, 1))
                            .position(x: spec.tileRect.midX, y: spec.tileRect.midY)
                    )
                    .blur(radius: t.blur)
                    .opacity(t.opacity)
                    .scaleEffect(t.scale)
                    .rotationEffect(.degrees(t.rotation))
                    .offset(t.offset)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

// MARK: - 決定論的Fracture(亀裂)

enum PictriFracture {
    /// 中心(origin)から指定した1方向へ伸びる、決定論的な分岐crack pathを生成する。
    /// random()を毎回使わず、固定seedにより「毎起動同じ形の亀裂」になる。
    private static func grow(next: () -> Double, from start: CGPoint, angle: Double, remaining: CGFloat, depth: Int, into path: inout Path) {
        guard depth > 0, remaining > 6 else { return }
        let segments = 5
        var current = start
        var currentAngle = angle
        path.move(to: current)
        for _ in 0..<segments {
            currentAngle += (next() - 0.5) * (30 * .pi / 180)
            let segLen = remaining / CGFloat(segments)
            let next2 = CGPoint(
                x: current.x + CGFloat(cos(currentAngle)) * Double(segLen),
                y: current.y + CGFloat(sin(currentAngle)) * Double(segLen)
            )
            path.addLine(to: next2)
            current = next2
        }
        if depth > 1, next() > 0.35 {
            grow(next: next, from: current, angle: currentAngle + (25 + next() * 25) * .pi / 180, remaining: remaining * 0.55, depth: depth - 1, into: &path)
        }
        if depth > 1, next() > 0.55 {
            grow(next: next, from: current, angle: currentAngle - (25 + next() * 25) * .pi / 180, remaining: remaining * 0.5, depth: depth - 1, into: &path)
        }
    }

    /// origin から primaryAngle 方向と、その逆方向(+π)へ、それぞれ独立した
    /// Pathとして亀裂を生成する。2本を別々のPathで返すのは、`.trim(from:to:)`が
    /// 単一Path内では"path構築順"でしか伸びを表現できず、片方向が伸び切るまで
    /// もう片方が全く動かない、という不自然な非対称性を避けるため
    /// (2本を同じtrim progressで同時にstrokeすれば、両方向が同時に伸びて見える)。
    /// (Lab記録用に維持。本番engineは`generateOrganic`を使用)
    static func generateBidirectional(
        seed: UInt64,
        origin: CGPoint,
        primaryAngle: Double,
        length: CGFloat,
        branchDepth: Int
    ) -> [Path] {
        let next = PictriSignatureRNG.makeGenerator(seed: seed)
        var pathA = Path()
        var pathB = Path()
        grow(next: next, from: origin, angle: primaryAngle, remaining: length, depth: branchDepth, into: &pathA)
        grow(next: next, from: origin, angle: primaryAngle + .pi, remaining: length, depth: branchDepth, into: &pathB)
        return [pathA, pathB]
    }

    /// 幹(primary)・枝(secondary)・小枝(micro)の3階層に分かれた応力伝播型crackを
    /// 個別のPathとして生成する(1本の連続Pathにまとめない)。各枝を別Pathで保持する
    /// ことで、`PictriFractureMask`側で階層ごとに異なるdelay/growthShare/太さを
    /// 与えられ、「幹はゆっくり始まり長く伸びる、枝は少し遅れて追従する、
    /// 小枝は瞬間的に現れる」という段階的な伝播を表現できる。
    /// 上下2方向は同一PRNGストリームの継続から生成されるため、長さ・分岐位置・
    /// 角度が完全な鏡像にならず、視覚的な上下対称性を避けられる。
    static func generateOrganic(
        seed: UInt64,
        origin: CGPoint,
        primaryAngle: Double,
        length: CGFloat,
        maxDepth: Int
    ) -> [PictriFractureBranch] {
        let next = PictriSignatureRNG.makeGenerator(seed: seed)
        var branches: [PictriFractureBranch] = []
        let upLength = length * (0.85 + next() * 0.35)
        growBranch(next: next, from: origin, angle: primaryAngle, remaining: upLength, depth: maxDepth, maxDepth: maxDepth, into: &branches)
        let downLength = length * (0.85 + next() * 0.35)
        growBranch(next: next, from: origin, angle: primaryAngle + .pi, remaining: downLength, depth: maxDepth, maxDepth: maxDepth, into: &branches)
        return branches
    }

    private static func growBranch(
        next: () -> Double,
        from start: CGPoint,
        angle: Double,
        remaining: CGFloat,
        depth: Int,
        maxDepth: Int,
        into branches: inout [PictriFractureBranch]
    ) {
        guard depth > 0, remaining > 5 else { return }
        let segments = 5
        var path = Path()
        var current = start
        var currentAngle = angle
        path.move(to: current)
        for _ in 0..<segments {
            currentAngle += (next() - 0.5) * (26 * .pi / 180)
            let segLen = remaining / CGFloat(segments)
            let nextPoint = CGPoint(
                x: current.x + CGFloat(cos(currentAngle)) * Double(segLen),
                y: current.y + CGFloat(sin(currentAngle)) * Double(segLen)
            )
            path.addLine(to: nextPoint)
            current = nextPoint
        }
        // tier 0 = 幹(primary)、1 = 枝(secondary)、2以上 = 小枝(micro)。
        let tier = maxDepth - depth
        branches.append(PictriFractureBranch(path: path, tier: tier))
        if depth > 1, next() > 0.32 {
            growBranch(next: next, from: current, angle: currentAngle + (24 + next() * 28) * .pi / 180, remaining: remaining * 0.54, depth: depth - 1, maxDepth: maxDepth, into: &branches)
        }
        if depth > 1, next() > 0.55 {
            growBranch(next: next, from: current, angle: currentAngle - (24 + next() * 28) * .pi / 180, remaining: remaining * 0.48, depth: depth - 1, maxDepth: maxDepth, into: &branches)
        }
    }
}

/// 3階層fractureの1本の枝。`tier`によって`PictriFractureMask`内での
/// 伝播タイミング(delay/growthShare)と太さが変わる。
struct PictriFractureBranch {
    let path: Path
    let tier: Int
}

/// crackPathsを「白い全面矩形からdestinationOutで刳り抜く」ことで、
/// crackの線に沿ってのみ透明(=下にあるHomeが覗く)になるmaskを作る。
/// 複数pathすべてに同じtrimEnd/lineWidthを適用することで、両方向が同時に
/// 伸びていくように見える。trimEndで亀裂の"伸び"を、lineWidthで亀裂の"広がり"を制御する。
/// (Lab記録用に維持。本番engineは`PictriOrganicFractureMask`を使用)
struct PictriFractureMask: View {
    let crackPaths: [Path]
    let trimEnd: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            context.blendMode = .destinationOut
            for path in crackPaths {
                let trimmed = path.trimmedPath(from: 0, to: trimEnd)
                context.stroke(
                    trimmed,
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

/// 3階層(幹/枝/小枝)それぞれに異なるdelay・growthShare・太さを与えて
/// destinationOutで刳り抜く、本番採用のfracture mask。`rawProgress`は
/// crack開始からの経過をcrackDurationで正規化した0...1の線形値(easingは
/// 内部でtierごとに`PictriSignatureEasing.crackPropagation`を適用する)。
struct PictriOrganicFractureMask: View {
    let branches: [PictriFractureBranch]
    let rawProgress: Double
    let maxLineWidth: CGFloat

    /// tierごとの(開始delay, 所要share, 幹に対する太さ比率)。
    /// 幹はcrack期間の大半を使ってゆっくり伸び切る。枝は少し遅れて追従し、
    /// 幹より細い。小枝はさらに遅れて瞬間的に現れ、もっとも細い
    /// (「幹はslow start、枝は少し遅れて追従、小枝は瞬間的」という要求に対応)。
    private func timing(for tier: Int) -> (delay: Double, share: Double, widthScale: CGFloat) {
        switch tier {
        case 0: return (0.0, 0.62, 1.0)
        case 1: return (0.16, 0.42, 0.7)
        default: return (0.38, 0.22, 0.48)
        }
    }

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            context.blendMode = .destinationOut
            for branch in branches {
                let t = timing(for: branch.tier)
                guard t.share > 0 else { continue }
                let local = min(max((rawProgress - t.delay) / t.share, 0), 1)
                guard local > 0 else { continue }
                let eased = PictriSignatureEasing.crackPropagation(local)
                let trimEnd = min(1, eased * 1.15)
                let widenT = max(0, (eased - 0.15) / 0.85)
                let lineWidth: CGFloat = 2 + maxLineWidth * t.widthScale * CGFloat(pow(widenT, 1.6))
                let trimmed = branch.path.trimmedPath(from: 0, to: trimEnd)
                context.stroke(
                    trimmed,
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

// MARK: - 共有 Reduced Motion Fallback
//
// Block assembly / fractureの複雑な個別モーションは行わず、短いcross dissolveで
// 組み上がり→細いseam→Home dissolveという最小構成にする(ブランドidentityは
// 残しつつ、depth・fracture展開は簡略化する、Accessibility要件への対応)。
struct PictriSignatureReducedFallback: View {
    var onComplete: () -> Void
    @State private var textOpacity: Double = 0
    @State private var seamOpacity: Double = 0
    @State private var wholeOpacity: Double = 1

    var body: some View {
        ZStack {
            PictriDarkTheme.openingSurface.ignoresSafeArea()

            Text("PicTri")
                .font(PictriDarkTheme.display(52, weight: .regular))
                .foregroundStyle(PictriDarkTheme.openingTextPrimary)
                .opacity(textOpacity)

            Rectangle()
                .fill(PictriDarkTheme.openingTextPrimary.opacity(0.5))
                .frame(width: 1, height: 40)
                .opacity(seamOpacity)
        }
        .opacity(wholeOpacity)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeInOut(duration: 0.35)) { textOpacity = 1 }
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeIn(duration: 0.12)) { seamOpacity = 1 }
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeInOut(duration: 0.3)) {
                wholeOpacity = 0
                seamOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.3))
            onComplete()
        }
    }
}

// MARK: - 共有エンジン(4案共通の骨格。差分はパラメータと`extraOverlay`のみ)
//
// GeometryReaderで実画面サイズを取得 → TimelineViewで経過時間(elapsed)を取得 →
// fragment群とfracture maskをすべてelapsedの純関数として描画する。
// `.mask(...)`をcontent全体(背景含む)に掛けることで、亀裂の線に沿った部分だけが
// 透明になり、このView自身の"背後"(root ZStackで既に実描画されているHome)が
// そのまま覗く。Opening→黒→Homeという二段fadeを一切経由しない。
private struct SignatureOpeningEngine: View {
    var onComplete: () -> Void

    let fragments: [SignatureFragmentSpec]
    let canvasSize: CGSize
    let wordColor: Color
    let assemblyBaseDelay: Double

    let crackSeed: UInt64
    let crackAngle: Double
    let crackBranchDepth: Int
    let crackStart: Double
    let crackDuration: Double

    let totalDuration: Double

    /// elapsed → (brightness, saturation, contrast)。写真的な階調処理(例: ネガ→ポジ)を
    /// 掛けたいconceptだけ非デフォルト値を返す。既定は無処理(0, 1, 1)。
    var glyphTone: (Double) -> (brightness: Double, saturation: Double, contrast: Double) = { _ in (0, 1, 1) }
    /// elapsed → 任意の追加オーバーレイ(トーニング/フレームライン等)。既定は何も描画しない。
    var extraOverlay: (Double) -> AnyView = { _ in AnyView(EmptyView()) }

    @State private var hasStarted = false
    // 起動直後、実際にこのViewが可視化されるまでの間(dyldロード/ContentView初期化等)に
    // 経過する時間をアニメーションのelapsedへ混入させないため、@Stateの初期値としてでは
    // なく`.task`が実際に走り出した瞬間に`Date()`を取得する(nilの間は最初のフレーム=黒として扱う)。
    @State private var startDate: Date?
    @State private var cachedBranches: [PictriFractureBranch] = []
    @State private var cachedSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
                let fragElapsed = max(0, elapsed - assemblyBaseDelay)
                let tone = glyphTone(fragElapsed)
                ZStack {
                    PictriDarkTheme.openingSurface
                    extraOverlay(elapsed)
                    SignatureAssemblyGlyph(
                        font: PictriDarkTheme.display(52, weight: .regular),
                        textColor: wordColor,
                        canvasSize: canvasSize,
                        fragments: fragments,
                        elapsed: fragElapsed
                    )
                    .brightness(tone.brightness)
                    .saturation(tone.saturation)
                    .contrast(tone.contrast)
                }
                .mask(fractureMask(elapsed: elapsed, size: geo.size))
            }
            .onAppear {
                guard cachedSize != geo.size else { return }
                cachedSize = geo.size
                let diag = sqrt(geo.size.width * geo.size.width + geo.size.height * geo.size.height)
                // originを画面中心から数pt(seed固定でdeterministic)ずらし、
                // 「幾何学的に完璧な中心対称」に見えないようにする。
                let jitterSeedGen = PictriSignatureRNG.makeGenerator(seed: crackSeed ^ 0x0FF5E7)
                let originJitterX = (CGFloat(jitterSeedGen()) - 0.5) * 10
                let originJitterY = (CGFloat(jitterSeedGen()) - 0.5) * 6
                cachedBranches = PictriFracture.generateOrganic(
                    seed: crackSeed,
                    origin: CGPoint(x: geo.size.width / 2 + originJitterX, y: geo.size.height / 2 + originJitterY),
                    primaryAngle: crackAngle,
                    length: diag * 0.62,
                    maxDepth: crackBranchDepth
                )
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

    private func fractureMask(elapsed: Double, size: CGSize) -> some View {
        let rawProgress = crackDuration > 0 ? min(max((elapsed - crackStart) / crackDuration, 0), 1) : 0
        return PictriOrganicFractureMask(branches: cachedBranches, rawProgress: rawProgress, maxLineWidth: 1800)
    }
}

private let signatureCanvasSize = CGSize(width: 300, height: 108)

// MARK: - Concept A: MONOLITH ASSEMBLY
//
// 断片が外側からゆっくり引き寄せられ「PicTri」が1つの塊として組み上がる →
// 静止 → 画面中央から垂直方向に亀裂 → Homeが覗く。4案の中でもっとも直球の
// 「BUILD → TENSION → FRACTURE」構成。
struct PictriSignatureConceptA_MonolithAssembly: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PictriSignatureReducedFallback(onComplete: onComplete)
        } else {
            SignatureOpeningEngine(
                onComplete: onComplete,
                fragments: makeSignatureFragments(
                    canvasSize: signatureCanvasSize, cols: 6, rows: 3,
                    seed: 0xA11CE, maxDelay: 0.5, durationRange: 0.35...0.55,
                    offsetMagnitude: 22, offsetDirection: signatureOutwardDirection,
                    blurRange: 3...10, scaleRange: 0.92...1.05, rotationRange: -6...6
                ),
                canvasSize: signatureCanvasSize,
                wordColor: PictriDarkTheme.openingTextPrimary,
                assemblyBaseDelay: 0.15,
                crackSeed: 0xC7ACC, crackAngle: -.pi / 2, crackBranchDepth: 3,
                crackStart: 1.55, crackDuration: 0.5,
                totalDuration: 2.15
            )
        }
    }
}

// MARK: - Concept B: TYPE UNDER PRESSURE
//
// 断片は最初から強く外側へ押し出された(圧縮された)状態で、素早く・機械的に
// 内側へ収束する。組み上がり後、間を置かず内側から亀裂が始まる — 「圧力に
// 耐えきれず、内側から破れる」という因果を意識した配分(stillnessが短い)。
struct PictriSignatureConceptB_TypeUnderPressure: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PictriSignatureReducedFallback(onComplete: onComplete)
        } else {
            SignatureOpeningEngine(
                onComplete: onComplete,
                fragments: makeSignatureFragments(
                    canvasSize: signatureCanvasSize, cols: 6, rows: 3,
                    seed: 0xB2B2B2, maxDelay: 0.3, durationRange: 0.3...0.42,
                    offsetMagnitude: 34, offsetDirection: signatureOutwardDirection,
                    blurRange: 2...7, scaleRange: 1.15...1.35, rotationRange: -2...2
                ),
                canvasSize: signatureCanvasSize,
                wordColor: PictriDarkTheme.openingTextPrimary,
                assemblyBaseDelay: 0.12,
                crackSeed: 0xD3D3D3, crackAngle: 0, crackBranchDepth: 3,
                crackStart: 1.35, crackDuration: 0.45,
                totalDuration: 1.95
            )
        }
    }
}

// MARK: - Concept C: PHOTOGRAPHIC NEGATIVE
//
// 断片は最初、暗く・脱色された「ネガ」的な階調で現れ、組み上がりながら
// 通常の階調(ivory)へ移行する。暗示的な4:5印画紙面のヘアラインが薄く現れて消え、
// 亀裂はその面の長辺に沿って垂直に走る。
struct PictriSignatureConceptC_PhotographicNegative: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PictriSignatureReducedFallback(onComplete: onComplete)
        } else {
            SignatureOpeningEngine(
                onComplete: onComplete,
                fragments: makeSignatureFragments(
                    canvasSize: signatureCanvasSize, cols: 6, rows: 3,
                    seed: 0xC0FFEE, maxDelay: 0.5, durationRange: 0.35...0.55,
                    offsetMagnitude: 20, offsetDirection: signatureOutwardDirection,
                    blurRange: 3...9, scaleRange: 0.92...1.04, rotationRange: -5...5
                ),
                canvasSize: signatureCanvasSize,
                wordColor: PictriDarkTheme.openingTextPrimary,
                assemblyBaseDelay: 0.15,
                crackSeed: 0xE5E5E5, crackAngle: -.pi / 2, crackBranchDepth: 3,
                crackStart: 1.6, crackDuration: 0.5,
                totalDuration: 2.2,
                glyphTone: { elapsed in
                    // 0.0–1.0秒でネガ的な階調(暗く・低彩度・高contrast)から
                    // 通常階調(0,1,1)へ非線形に移行する(「現像」ではなく「露光の反転」)。
                    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 1.0, 0), 1))
                    let brightness = -0.4 * (1 - t)
                    let saturation = 0.15 + 0.85 * t
                    let contrast = 1.3 - 0.3 * t
                    return (brightness, saturation, contrast)
                },
                extraOverlay: { elapsed in
                    let frameOpacity = elapsed < 0.9
                        ? min(0.12, elapsed * 0.15)
                        : max(0, 0.12 - (elapsed - 0.9) * 0.2)
                    return AnyView(
                        Rectangle()
                            .stroke(PictriDarkTheme.openingTextPrimary.opacity(frameOpacity), lineWidth: 1)
                            .frame(width: 216, height: 270)
                    )
                }
            )
        }
    }
}

// MARK: - Concept D: DIRECTOR'S CUT
//
// 開始直後は「PicTri」のごく一部の断片が極端に拡大・被写界深度外(強いblur)の
// 状態で存在するのみ。各断片が個別のタイミングでscaleを1.0へ戻していくことで、
// カメラズームではなく"断片そのものの変化"だけで全体像が現れる。組み上がり後は
// 短い静止のあと、分岐の少ない鋭い一撃のような亀裂で断ち切られる。
struct PictriSignatureConceptD_DirectorsCut: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PictriSignatureReducedFallback(onComplete: onComplete)
        } else {
            SignatureOpeningEngine(
                onComplete: onComplete,
                fragments: makeSignatureFragments(
                    canvasSize: signatureCanvasSize, cols: 6, rows: 3,
                    seed: 0xD12EC7, maxDelay: 0.45, durationRange: 0.4...0.65,
                    offsetMagnitude: 6, offsetDirection: signatureOutwardDirection,
                    blurRange: 10...22, scaleRange: 2.4...4.2, rotationRange: -3...3
                ),
                canvasSize: signatureCanvasSize,
                wordColor: PictriDarkTheme.openingTextPrimary,
                assemblyBaseDelay: 0.15,
                crackSeed: 0xF00D, crackAngle: -.pi / 2, crackBranchDepth: 1,
                crackStart: 1.5, crackDuration: 0.3,
                totalDuration: 2.0,
                extraOverlay: { _ in
                    AnyView(
                        RadialGradient(
                            colors: [Color.black.opacity(0), Color.black.opacity(0.35)],
                            center: .center, startRadius: 140, endRadius: 340
                        )
                        .allowsHitTesting(false)
                    )
                }
            )
        }
    }
}

// MARK: - Signature Concept E: LATENT IMAGE(Hybrid v2)
//
// 4案採点(/tmp/pictri_opening_signature_lab/scoring.md)の結果、最高点はC
// (Photographic Negative, 79/100)。85点未満のため単独採用はせず、2位タイの
// A/DのうちCinematic・Dynamic・Originalityで最高評価だったD(Director's Cut)と
// 融合する。
//
// 「潜像(latent image)」— 露光直後、まだ目に見えない像がフィルムの中に
// 既に存在している状態 — という写真用語をモチーフにする。Dの大胆な
// 「巨大にボケた断片から急速に収束する」開幕(ただし抽象状態の長さはDより
// 短縮し、ブランド認知の立ち上がりを改善)に、Cのネガ→ポジ階調変化と
// 暗示的な4:5印画紙フレーム、印画紙面の長辺に沿った垂直crackを組み合わせる。
struct PictriSignatureConceptE_LatentImage: View {
    var onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            PictriSignatureReducedFallback(onComplete: onComplete)
        } else {
            SignatureOpeningEngine(
                onComplete: onComplete,
                fragments: makeSignatureFragments(
                    canvasSize: signatureCanvasSize, cols: 6, rows: 4,
                    seed: 0xE17E17, maxDelay: 0.35, durationRange: 0.35...0.5,
                    offsetMagnitude: 10, offsetDirection: signatureOutwardDirection,
                    blurRange: 8...16, scaleRange: 1.8...2.8, rotationRange: -3...3
                ),
                canvasSize: signatureCanvasSize,
                wordColor: PictriDarkTheme.openingTextPrimary,
                assemblyBaseDelay: 0.12,
                crackSeed: 0x1A7E27, crackAngle: -.pi / 2, crackBranchDepth: 3,
                crackStart: 1.32, crackDuration: 0.48,
                totalDuration: 1.95,
                glyphTone: { elapsed in
                    let t = PictriSignatureEasing.fragmentSettle(min(max(elapsed / 0.85, 0), 1))
                    let brightness = -0.35 * (1 - t)
                    let saturation = 0.2 + 0.8 * t
                    var contrast = 1.25 - 0.25 * t
                    // Glyph Lock: 断片が組み上がりきった瞬間(elapsed≈0.85-1.0)に、
                    // 視線が完全にwordmarkへ固定される感覚を与えるための、
                    // ごく短い山形のcontrast/brightnessパルス(フラッシュにならない
                    // 極小量に抑える。画面全体ではなくglyphのみへ適用)。
                    let lockLocal = min(max((elapsed - 0.82) / 0.22, 0), 1)
                    let lockPulse = sin(lockLocal * .pi)
                    contrast += 0.10 * lockPulse
                    let brightnessWithLock = brightness + 0.05 * lockPulse
                    return (brightnessWithLock, saturation, contrast)
                },
                extraOverlay: { elapsed in
                    // Simplicity改善: vignette/frameは両方とも最大値をさらに抑え、
                    // 「盛りすぎ」に見えないよう最小限の気配だけ残す。
                    let frameOpacity = elapsed < 0.8
                        ? min(0.07, elapsed * 0.10)
                        : max(0, 0.07 - (elapsed - 0.8) * 0.13)
                    return AnyView(
                        ZStack {
                            RadialGradient(
                                colors: [Color.black.opacity(0), Color.black.opacity(0.16)],
                                center: .center, startRadius: 130, endRadius: 320
                            )
                            .allowsHitTesting(false)
                            Rectangle()
                                .stroke(PictriDarkTheme.openingTextPrimary.opacity(frameOpacity), lineWidth: 1)
                                .frame(width: 216, height: 270)
                        }
                    )
                }
            )
        }
    }
}
