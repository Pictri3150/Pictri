import SwiftUI

// MARK: - Pictri Japan Collection Map
//
// Claude Design Final Handoff(/Users/takakikeita/Desktop/PictriDesignHandoffFinal/handoff/)を
// Visual Source of Truthとして実装した、日本全体Mapの正式なコレクションマップ。
// PICTRI_DO_NOT_DEGRADE.md #4「No Apple Maps / MapKit as the map. The Japan collection
// map is the product.」およびPICTRI_SWIFTUI_HANDOFF.md「Map: a shape-per-prefecture
// drawn from the vector data...hit-tested per shape. Never MapKit.」に従い、実MapKit
// を経由せず、questPrefectureShapes(本番の実データ、QuestMapGeoData.swift)から
// 都道府県ポリゴンを直接描画・判定する。
//
// 訪問状態の判定は既存のvisitedPrefectureIds(呼び出し元のQuestMapView側で
// QuestMemoryStore.visitedPrefectureIdsから導出)をそのまま受け取るだけで、
// このView自身は新しいSource of Truthを一切持たない。
//
// 色・spacing等のtokenはPictriFinalTheme(PictriDesignSystem.swift)を参照する。
//
// ## Geometry fidelity についての既知の制約(3回目の監査で判明)
// questPrefectureShapesは1県あたり平均30点(最小21点、最大34点)の簡略化ポリゴンで、
// 拡大表示すると頂点間が直線でつながる「手描き感」が出る。より高精度な都道府県境界
// データへの置き換えを検討したが、今回のセッション内で確認できた候補
// (dataofjapan/land、国土数値情報N03、出所不明のprefectures.geojson)は
// いずれもライセンス上の懸念が残るため見送った(詳細は最終報告に記載)。
// 代替として、既存の頂点データはそのまま(=新しい地理情報を捏造しない)、
// 頂点間の接続を「辺制約つきの角丸め」(PictriCollectionPrefecturePath、下部定義)に
// 変更し、「多角形の角ばった手描き感」を軽減する。半島のような、そもそも頂点間隔より
// 細かい地形の再現は今回のデータでは引き続き不可能であり、これは正直に限界として
// 報告する。
//
// ### 曲線方式の変遷(4回目の監査で判明・修正)
// 当初はCatmull-Rom→Bezier変換(隣接2頂点先の座標まで参照して接線を作る)を採用したが、
// 47都道府県全件を独立検証した結果、京都・大阪で曲線の自己交差が実際に発生することが
// 判明した(短辺が連続する箇所で制御点が隣接辺の外側へovershootするため)。
// 「京都・大阪だけtensionを調整する」対応はせず、47県全件で構造的に安全な
// 「辺制約つき角丸め」方式に置き換えた。制御点を頂点自身にした2次Bezierで、
// 入口点・出口点を両隣の辺長でclampして置くため、曲線が(entry, vertex, exit)の
// 三角形の外へ出ることが構造的にない。
//
// ### 5回目の監査: 三重・福岡は「丸め処理を避けるfallback」では未解決だった
// 47県全件を丸めた結果、京都・大阪を含む45県は自己交差ゼロになったが、三重・福岡の
// 2県だけは丸め処理の問題ではなく、簡略化前の頂点データ自体(questPrefectureShapes)に
// 既に極小(1〜3pt程度)の自己交差が存在していた。前回はこの2県だけ丸めずに直線
// ポリゴンのまま描画するfallbackにしたが、直線ポリゴン自体も自己交差したままであり、
// 「fallbackしたからOK」ではなく元データの位相(topology)そのものが壊れていた。
// 新しい座標を捏造せず、既存頂点だけを使ってこれを解消するため、
// `QuestPrefectureGeometry.sanitizedPointsById`で47都道府県全件に同一の
// 2-opt polygon untangling(非隣接edgeが交差していたら、交差する2辺の間の頂点列を
// reverseする。triangle inequalityにより1回のreverseで多角形の周長が必ず短くなるため
// 有限回で収束し、self-intersectionが残らない状態に到達することが保証されている)を
// 適用してから丸め処理へ渡す。三重・福岡はそれぞれ隣接2頂点の並び順が1回だけ
// 入れ替わるだけで解消し(座標値は一切変更していない)、他45県は交差が無いため
// no-opで元の並び順のまま返る。県ごとの個別コードは無い。
// 描画(PictriCollectionPrefecturePath)・hit testing(polygonHit)・外接矩形
// (screenBounds)・重心(centroid)・accessibility marker・Prefecture Detail
// (MapView.swift, QuestPrefectureSubMapView)は全てこのsanitized pointsだけを参照する
// 一方向構造(source points → sanitize → safe points → rounded rendering / hit
// testing)にしており、表示用geometryとhit-test用geometryが食い違う状態を作らない。
//
// ## Hit testing
// 47個の個別onTapGestureではなく、Map全体に1つだけのタップ判定を持たせる。
// タップ位置をキャンバス座標へ変換した上で、
//   1. まず各県の実ポリゴン(PictriCollectionPrefecturePath、角丸め版)に対し
//      Path.contains(_:)で真の内外判定を行う。
//   2. どのポリゴンにも当たらなかった場合のみ、最も近い県の外接矩形までの距離を測り、
//      一定距離以内ならその県を選ぶ(取りこぼし対策、静的重複領域は作らない)。
//
// ## Pinch Zoom / Pan(今回追加)
// 表示は`.scaleEffect`/`.offset`をタップ判定を持つ外側コンテナではなく、内側の
// 描画専用コンテンツにのみ適用する。タップ判定は常に「変形前」の外側コンテナの
// local座標で受け取り、そこから明示的な逆変換(中心を軸にscaleを除算、offsetを
// 差し引く)でcanonical座標(fitScale基準)へ戻してからpolygon hit testを行う。
// これにより「見えている県=選択される県」がズーム後も常に成立する。
//
// Accessibility(VoiceOver)はタッチのhit testingと完全に分離する。各県ごとに
// 視覚的には何も描画しない小さなaccessibility専用要素を配置し、.accessibilityAction
// で直接onSelectを呼ぶ(座標ベースの奪い合いが起きない、ズーム状態にも依存しない)。

// MARK: - Sanitized geometry (single source of truth)

/// questPrefectureShapes.pointsを一度だけ2-opt polygon untanglingにかけ、47都道府県
/// すべてについて自己交差の無い頂点列を得るための唯一の入口。表示(丸め描画)・
/// hit testing・外接矩形・重心・accessibility markerなど、県の輪郭を必要とする箇所は
/// 必ずここを経由し、`QuestPrefectureShape.points`を直接参照しない
/// (source points → sanitize → safe points → rounded rendering / hit testing、の
/// 一方向構造を保つため)。
enum QuestPrefectureGeometry {
    /// 47都道府県ぶんまとめて1度だけ計算し、以降はキャッシュを返す(アプリのプロセス
    /// 生存期間中は不変のstatic let。Swiftのstatic let初期化はスレッドセーフに1回だけ
    /// 実行される)。
    static let sanitizedPointsById: [String: [CGPoint]] = {
        var result: [String: [CGPoint]] = [:]
        for shape in questPrefectureShapes {
            let sanitized = twoOptUntangle(shape.points)
            assert(!hasSelfIntersection(sanitized), "2-opt untangle did not converge for \(shape.id)")
            result[shape.id] = sanitized
        }
        return result
    }()

    static func points(for shape: QuestPrefectureShape) -> [CGPoint] {
        sanitizedPointsById[shape.id] ?? shape.points
    }

    /// 非隣接edge(A,B)と(C,D)が交差している場合、AとDの間の頂点列(B..C)をreverseして
    /// 交差を解消する古典的な2-opt untangling。新しい座標は一切生成せず、既存頂点の
    /// 並び順だけを変える。三角不等式より、交差する対角線2本は交差を解消した後の
    /// 2本より必ず長い(=1回のreverseで多角形の周長が必ず短くなる)ため、有限回で
    /// 収束し自己交差の無い状態(simple polygon)に到達することが保証されている。
    /// 交差が無いポリゴンにはno-op(元の並び順のまま)。
    static func twoOptUntangle(_ points: [CGPoint], maxIterations: Int = 200) -> [CGPoint] {
        var poly = points
        let n = poly.count
        guard n >= 4 else { return poly }
        for _ in 0..<maxIterations {
            guard let (i, j) = firstCrossing(poly) else { break }
            var lo = i + 1
            var hi = j
            while lo < hi {
                poly.swapAt(lo, hi)
                lo += 1
                hi -= 1
            }
        }
        return poly
    }

    private static func firstCrossing(_ poly: [CGPoint]) -> (Int, Int)? {
        let n = poly.count
        for i in 0..<n {
            let a1 = poly[i]
            let a2 = poly[(i + 1) % n]
            var j = i + 2
            while j < n {
                if !(i == 0 && j == n - 1) {
                    let b1 = poly[j]
                    let b2 = poly[(j + 1) % n]
                    if segmentsIntersect(a1, a2, b1, b2) {
                        return (i, j)
                    }
                }
                j += 1
            }
        }
        return nil
    }

    static func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> Bool {
        func ccw(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            (c.y - a.y) * (b.x - a.x) - (b.y - a.y) * (c.x - a.x)
        }
        let d1 = ccw(p3, p4, p1), d2 = ccw(p3, p4, p2)
        let d3 = ccw(p1, p2, p3), d4 = ccw(p1, p2, p4)
        return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
    }

    static func hasSelfIntersection(_ poly: [CGPoint]) -> Bool {
        let n = poly.count
        guard n >= 4 else { return false }
        for i in 0..<n {
            let a1 = poly[i]
            let a2 = poly[(i + 1) % n]
            var j = i + 2
            while j < n {
                if !(i == 0 && j == n - 1) {
                    let b1 = poly[j]
                    let b2 = poly[(j + 1) % n]
                    if segmentsIntersect(a1, a2, b1, b2) { return true }
                }
                j += 1
            }
        }
        return false
    }
}

/// Run B(Map Dark化)で追加。地図本体の配色だけを差し替え可能にするための
/// パレット。geometry・hit testing・visited解決ロジックには一切関与しない
/// (このstructは色を運ぶだけ)。既定値`.light`は既存のPictriFinalTheme参照と
/// 完全に同じ値のため、この引数を渡さない既存呼び出し元(MapView.swift、
/// 今回は不可触)の見た目は一切変わらない。
struct PictriJapanCollectionMapPalette {
    let background: Color
    let dormantFill: Color
    let dormantStroke: Color
    let visitedStroke: Color
    let centroidDot: Color
    let memoryColor: (String) -> Color

    // Visual Reality Check Phase: 元は`static let`だったため、PictriFinalTheme側の
    // 各tokenがmode-aware(computed var)化された後も、このpaletteは最初にアクセスされた
    // 時点のColorを永久にキャッシュしたままになり、Appearance設定をLive切替しても
    // Mapの配色(背景・未訪問塗り・線・訪問済み輪郭)だけ追従しないバグがあった。
    // `static var`(computed)に変え、参照のたびに現在のmodeを反映させる。
    // 未訪問の塗り/線は、カード用に調整されたPictriFinalTheme.dormant/dormantDotだと
    // Light modeで背景とほぼ同化してしまう問題が判明したため、Map専用に分離した
    // PictriDarkTheme.mapUnvisitedFill/mapUnvisitedStrokeを使う。
    //
    // 旧`.dark`固定パレット(brown-castなハードコードhexを含む、当時未接続の死にコード)は
    // このPhaseで削除した。現在の`.light`(既定かつ唯一の呼び出し経路)自体が
    // mode-awareになったため、別パレットを切り替える設計はもう不要。
    static var light: PictriJapanCollectionMapPalette {
        PictriJapanCollectionMapPalette(
            background: PictriFinalTheme.paper,
            dormantFill: PictriDarkTheme.mapUnvisitedFill,
            dormantStroke: PictriDarkTheme.mapUnvisitedStroke,
            visitedStroke: PictriFinalTheme.ink,
            centroidDot: PictriFinalTheme.paper,
            memoryColor: { PictriFinalTheme.memoryColor(for: $0) }
        )
    }
}

struct PictriJapanCollectionMap: View {
    let visitedPrefectureIds: Set<String>
    let onSelect: (QuestPrefecture) -> Void
    var palette: PictriJapanCollectionMapPalette = .light

    /// ポリゴンのどこにも当たらなかった場合に、最寄りの県を採用する許容距離(canonical space, pt)。
    private static let missToleranceRadius: CGFloat = 22
    private static let minScale: CGFloat = 1.0
    private static let maxScale: CGFloat = 2.8

    @State private var baseScale: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var baseOffset: CGSize = .zero
    @GestureState private var panTranslation: CGSize = .zero

    private var currentScale: CGFloat {
        (baseScale * pinchScale).clamped(to: Self.minScale...Self.maxScale)
    }

    private var currentOffset: CGSize {
        CGSize(
            width: baseOffset.width + panTranslation.width,
            height: baseOffset.height + panTranslation.height
        )
    }

    private func isVisited(_ id: String) -> Bool {
        visitedPrefectureIds.contains(id)
    }

    var body: some View {
        GeometryReader { proxy in
            let fitScale = min(
                proxy.size.width / QuestJapanMapMetrics.canvasWidth,
                proxy.size.height / QuestJapanMapMetrics.canvasHeight
            )
            let offsetX = (proxy.size.width - QuestJapanMapMetrics.canvasWidth * fitScale) / 2
            let offsetY = (proxy.size.height - QuestJapanMapMetrics.canvasHeight * fitScale) / 2

            ZStack {
                mapContent(fitScale: fitScale, offsetX: offsetX, offsetY: offsetY)
                    .scaleEffect(currentScale, anchor: .center)
                    .offset(currentOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(panGesture(containerSize: proxy.size))
            .simultaneousGesture(magnifyGesture(containerSize: proxy.size))
            .onTapGesture(coordinateSpace: .local) { rawLocation in
                let canonical = inverseTransform(rawLocation, containerSize: proxy.size)
                handleTap(at: canonical, scale: fitScale, offsetX: offsetX, offsetY: offsetY)
            }
            .onAppear {
                applyDebugZoomIfRequested(containerSize: proxy.size, fitScale: fitScale, offsetX: offsetX, offsetY: offsetY)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// `-pictriMapDebugScale` / `-pictriMapDebugFocus` をDEBUG限定で再現する。
    /// 通常起動(引数無し)ではbaseScale/baseOffsetは初期値(1.0 / .zero)のまま変化せず、
    /// Production初期状態を一切変更しない。
    private func applyDebugZoomIfRequested(containerSize: CGSize, fitScale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        #if DEBUG
        guard let requestedScale = PictriVisualReview.mapDebugScale else { return }
        let scale = requestedScale.clamped(to: Self.minScale...Self.maxScale)
        baseScale = scale

        guard let focusId = PictriVisualReview.mapDebugFocusPrefectureId,
              let shape = questPrefectureShapes.first(where: { $0.id == focusId }) else {
            baseOffset = clampedOffset(baseOffset, scale: scale, containerSize: containerSize)
            return
        }

        let points = QuestPrefectureGeometry.points(for: shape)
        guard !points.isEmpty else { return }
        let avgX = points.reduce(0) { $0 + $1.x } / CGFloat(points.count)
        let avgY = points.reduce(0) { $0 + $1.y } / CGFloat(points.count)
        let canonicalCentroid = CGPoint(x: avgX * fitScale + offsetX, y: avgY * fitScale + offsetY)
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let proposed = CGSize(
            width: (center.x - canonicalCentroid.x) * scale,
            height: (center.y - canonicalCentroid.y) * scale
        )
        baseOffset = clampedOffset(proposed, scale: scale, containerSize: containerSize)
        #endif
    }

    private func mapContent(fitScale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        ZStack {
            palette.background

            ForEach(questPrefectureShapes) { shape in
                prefectureVisual(shape, scale: fitScale, offsetX: offsetX, offsetY: offsetY)
            }

            // Accessibility専用レイヤー。視覚的な塗り・線は一切持たず、VoiceOverの
            // フォーカス順・.accessibilityActionだけでonSelectを起動する
            // (ズーム状態に関わらず常に正しい県を選択できる)。
            ForEach(questPrefectureShapes) { shape in
                accessibilityMarker(shape, scale: fitScale, offsetX: offsetX, offsetY: offsetY)
            }
        }
    }

    // MARK: - Gestures

    /// 2本指ピンチ。中心を軸にscaleを更新し、min/maxへclampする。
    private func magnifyGesture(containerSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .updating($pinchScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let proposed = baseScale * value.magnification
                baseScale = proposed.clamped(to: Self.minScale...Self.maxScale)
                baseOffset = clampedOffset(baseOffset, scale: baseScale, containerSize: containerSize)
            }
    }

    /// 1本指パン。最小移動量を設けることでシンプルなtapとの競合を避ける。
    private func panGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($panTranslation) { value, state, _ in
                guard currentScale > Self.minScale + 0.01 else { return }
                state = value.translation
            }
            .onEnded { value in
                guard currentScale > Self.minScale + 0.01 else { return }
                let proposed = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
                baseOffset = clampedOffset(proposed, scale: baseScale, containerSize: containerSize)
            }
    }

    /// ズームで生まれた余白の範囲内だけpanを許可する(scale=1では0に固定)。
    private func clampedOffset(_ offset: CGSize, scale: CGFloat, containerSize: CGSize) -> CGSize {
        let maxX = max(0, (scale - 1) * containerSize.width / 2)
        let maxY = max(0, (scale - 1) * containerSize.height / 2)
        return CGSize(
            width: offset.width.clamped(to: -maxX...maxX),
            height: offset.height.clamped(to: -maxY...maxY)
        )
    }

    /// 画面上のタップ位置(変形前コンテナのlocal座標)を、現在のscale/offsetの逆変換で
    /// canonical(fitScale基準)座標へ戻す。中心を軸にscaleEffectしているため、
    /// 「中心からの距離をscaleで割り戻す」形になる。
    private func inverseTransform(_ point: CGPoint, containerSize: CGSize) -> CGPoint {
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let unOffset = CGPoint(x: point.x - currentOffset.width, y: point.y - currentOffset.height)
        let unScaled = CGPoint(
            x: center.x + (unOffset.x - center.x) / currentScale,
            y: center.y + (unOffset.y - center.y) / currentScale
        )
        return unScaled
    }

    // MARK: - Hit testing

    private func handleTap(at location: CGPoint, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        if let shape = polygonHit(at: location, scale: scale, offsetX: offsetX, offsetY: offsetY) {
            onSelect(prefecture(for: shape))
            return
        }
        if let shape = nearestShapeWithinTolerance(to: location, scale: scale, offsetX: offsetX, offsetY: offsetY) {
            onSelect(prefecture(for: shape))
        }
    }

    private func polygonHit(at location: CGPoint, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> QuestPrefectureShape? {
        for shape in questPrefectureShapes {
            let path = PictriCollectionPrefecturePath(points: QuestPrefectureGeometry.points(for: shape), scale: scale, offsetX: offsetX, offsetY: offsetY)
            if path.path(in: .zero).contains(location) {
                return shape
            }
        }
        return nil
    }

    private func nearestShapeWithinTolerance(
        to location: CGPoint,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> QuestPrefectureShape? {
        var nearestShape: QuestPrefectureShape?
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for shape in questPrefectureShapes {
            let bounds = screenBounds(for: QuestPrefectureGeometry.points(for: shape), scale: scale, offsetX: offsetX, offsetY: offsetY)
            let dx = max(bounds.minX - location.x, 0, location.x - bounds.maxX)
            let dy = max(bounds.minY - location.y, 0, location.y - bounds.maxY)
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < nearestDistance {
                nearestDistance = distance
                nearestShape = shape
            }
        }

        guard let nearestShape, nearestDistance <= Self.missToleranceRadius else { return nil }
        return nearestShape
    }

    // MARK: - Visual layer (hit testing disabled; handled centrally above)

    @ViewBuilder
    private func prefectureVisual(
        _ shape: QuestPrefectureShape,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        let visited = isVisited(shape.id)
        let path = PictriCollectionPrefecturePath(points: QuestPrefectureGeometry.points(for: shape), scale: scale, offsetX: offsetX, offsetY: offsetY)
        let fillColor = visited ? palette.memoryColor(shape.id) : palette.dormantFill

        path
            .fill(fillColor)
            .overlay {
                if visited {
                    path.stroke(palette.visitedStroke, lineWidth: 1.4)
                } else {
                    path.stroke(palette.dormantStroke, style: StrokeStyle(lineWidth: 1, dash: [2.5, 2]))
                }
            }
            .overlay {
                if visited {
                    let centroid = centroid(of: QuestPrefectureGeometry.points(for: shape), scale: scale, offsetX: offsetX, offsetY: offsetY)
                    Circle()
                        .fill(palette.centroidDot)
                        .frame(width: 4, height: 4)
                        .position(centroid)
                }
            }
            .allowsHitTesting(false)
    }

    // MARK: - Accessibility layer (separated from touch hit testing)

    @ViewBuilder
    private func accessibilityMarker(
        _ shape: QuestPrefectureShape,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        let visited = isVisited(shape.id)
        let bounds = screenBounds(for: QuestPrefectureGeometry.points(for: shape), scale: scale, offsetX: offsetX, offsetY: offsetY)

        Color.clear
            .frame(width: max(bounds.width, 1), height: max(bounds.height, 1))
            .contentShape(Rectangle())
            .position(x: bounds.midX, y: bounds.midY)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(shape.name)・\(visited ? "いろづいた" : "まだ")")
            .accessibilityAction {
                onSelect(prefecture(for: shape))
            }
    }

    // MARK: - Shared helpers

    private func prefecture(for shape: QuestPrefectureShape) -> QuestPrefecture {
        mockQuestPrefectures.first(where: { $0.id == shape.id })
            ?? QuestPrefecture(id: shape.id, name: shape.name, englishName: shape.id, totalSpotCount: 0)
    }

    private func screenBounds(for points: [CGPoint], scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGRect {
        let xs = points.map { $0.x * scale + offsetX }
        let ys = points.map { $0.y * scale + offsetY }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func centroid(of points: [CGPoint], scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let avgX = sumX / CGFloat(points.count)
        let avgY = sumY / CGFloat(points.count)
        return CGPoint(x: avgX * scale + offsetX, y: avgY * scale + offsetY)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// questPrefectureShapesの共有キャンバス座標(QuestJapanMapMetrics基準)を、渡された
/// scale/offsetで変換した上で、頂点間をCatmull-Rom→Bezier変換した滑らかな閉曲線として
/// 描画するShape。直線でつなぐ場合に比べ「多角形の角ばった手描き感」を軽減する
/// (新しい地理情報を追加するものではなく、既存頂点の接続方法のみを変更している)。
/// 描画とhit testingの両方がこの同じpathを参照するため、
/// 「見た目の県境」と「タップ判定の境界」が常に一致する。
///
/// Prefecture Detail(MapView.swift, QuestPrefectureSubMapView)でも同じ丸め描画を
/// 再利用するため、`private`ではなくファイル外から参照可能にしている
/// (直線ポリゴンで別々に描くと、日本全体Mapと県詳細で県の見た目が食い違ってしまうため)。
///
/// 「辺制約つきの角丸め」: 各頂点について、
///   entry point = 頂点から入口辺(incoming edge)方向へ半径rだけ戻った点
///   exit point  = 頂点から出口辺(outgoing edge)方向へ半径rだけ進んだ点
/// を置き、entryまではline、entry→exitは頂点自身を制御点にした2次Bezierで結ぶ。
/// 半径rは固定値ではなく
///   r = min(desiredRadius, incomingEdgeLength × edgeSafety, outgoingEdgeLength × edgeSafety)
/// で必ず両隣の辺長にclampする。edgeSafety=0.35なので、1つの辺の両端の頂点が
/// それぞれ丸めを消費しても合計0.7×辺長までしか使わず、entry/exit点同士が
/// 重なったり交差したりしない。かつ2次Bezierは常にentry/vertex/exitの三角形の
/// 内側にしか曲がれないため、Catmull-Rom(隣接2頂点先まで参照する接線)のように
/// 隣接辺の外側へovershootすることが構造的にない。
struct PictriCollectionPrefecturePath: Shape {
    /// 呼び出し側は必ず`QuestPrefectureGeometry.points(for:)`(2-opt untangling済み、
    /// 自己交差の無い頂点列)を渡す。このShape自体はもう自己交差の検出・fallback判定を
    /// 持たない(47県全件が丸め前提で安全になったため、fallback機構自体が不要になった)。
    let points: [CGPoint]
    var scale: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat

    static let desiredRadius: CGFloat = 3.0
    static let edgeSafety: CGFloat = 0.35

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let n = points.count
        guard n >= 3 else {
            guard let first = points.first else { return path }
            path.move(to: transformed(first))
            for point in points.dropFirst() {
                path.addLine(to: transformed(point))
            }
            path.closeSubpath()
            return path
        }

        func point(at index: Int) -> CGPoint {
            points[((index % n) + n) % n]
        }

        var isFirst = true
        for i in 0..<n {
            let p0 = point(at: i - 1)
            let p1 = point(at: i)
            let p2 = point(at: i + 1)
            let lIn = hypot(p1.x - p0.x, p1.y - p0.y)
            let lOut = hypot(p2.x - p1.x, p2.y - p1.y)

            guard lIn > 0.0001, lOut > 0.0001 else {
                if isFirst {
                    path.move(to: transformed(p1))
                    isFirst = false
                } else {
                    path.addLine(to: transformed(p1))
                }
                continue
            }

            let r = min(Self.desiredRadius, lIn * Self.edgeSafety, lOut * Self.edgeSafety)
            let uxIn = (p1.x - p0.x) / lIn, uyIn = (p1.y - p0.y) / lIn
            let uxOut = (p2.x - p1.x) / lOut, uyOut = (p2.y - p1.y) / lOut
            let entry = CGPoint(x: p1.x - uxIn * r, y: p1.y - uyIn * r)
            let exit = CGPoint(x: p1.x + uxOut * r, y: p1.y + uyOut * r)

            if isFirst {
                path.move(to: transformed(entry))
                isFirst = false
            } else {
                path.addLine(to: transformed(entry))
            }
            path.addQuadCurve(to: transformed(exit), control: transformed(p1))
        }
        path.closeSubpath()
        return path
    }

    private func transformed(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
    }
}

#Preview("Pictri Japan Collection Map - Unvisited") {
    PictriJapanCollectionMap(visitedPrefectureIds: [], onSelect: { _ in })
        .frame(height: 420)
        .padding(20)
}

#Preview("Pictri Japan Collection Map - Some Visited") {
    PictriJapanCollectionMap(
        visitedPrefectureIds: ["kanagawa", "tokyo", "hokkaido", "kyoto"],
        onSelect: { _ in }
    )
    .frame(height: 420)
    .padding(20)
}
