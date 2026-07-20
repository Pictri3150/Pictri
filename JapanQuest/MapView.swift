import SwiftUI

// MARK: - Navigation Routes
//
// NavigationPathは型ごとにdestinationを振り分けるため、県詳細とエリア探索を
// 同じQuestPrefectureのまま2回pushすると区別できない。専用のRoute型で包むことで、
// 「県詳細へ行く」と「エリア探索へ行く」を別の画面として積めるようにしている。

struct PrefectureDetailRoute: Hashable {
    let prefecture: QuestPrefecture
}

struct AreaExploreRoute: Hashable {
    let prefecture: QuestPrefecture
}

// MARK: - Map Root

struct QuestMapView: View {
    @Binding var selectedTab: AppTab
    @Binding var activeCameraSpotId: String

    @EnvironmentObject var memoryStore: QuestMemoryStore

    @State private var path = NavigationPath()

    /// 訪問済み都道府県は「実際にメモリーが1枚でもある県」を基準にする。
    /// スポットデータ(mockQuestSpots)の有無とは別の軸: 東京・京都・北海道に
    /// スポットを追加しても、実際に写真を保存するまでは訪問済みにならない。
    /// DEBUG限定でプレビュー用に追加の県を「訪問済みに見せる」ことができる
    /// (memoryStoreへは一切書き込まない、表示専用の上乗せ)。
    private var visitedPrefectureIds: Set<String> {
        var ids = Set(memoryStore.memoryPhotos.map { $0.prefectureId })
        #if DEBUG
        if let preview = PictriVisualReview.mapPreviewVisitedPrefectureIds {
            ids.formUnion(preview)
        }
        #endif
        return ids
    }

    var body: some View {
        NavigationStack(path: $path) {
            QuestJapanOverviewScreen(
                visitedPrefectureIds: visitedPrefectureIds,
                onSelectPrefecture: { prefecture in
                    path.append(PrefectureDetailRoute(prefecture: prefecture))
                }
            )
            .onAppear {
                openDebugSpotIfRequested()
            }
            .navigationDestination(for: PrefectureDetailRoute.self) { route in
                QuestPrefectureDetailScreen(
                    prefecture: route.prefecture,
                    isVisited: visitedPrefectureIds.contains(route.prefecture.id),
                    path: $path
                )
            }
            .navigationDestination(for: AreaExploreRoute.self) { route in
                QuestAreaExploreScreen(
                    prefecture: route.prefecture,
                    path: $path
                )
            }
            .navigationDestination(for: QuestSpot.self) { spot in
                QuestSpotDetailView(
                    spot: spot,
                    selectedTab: $selectedTab,
                    activeCameraSpotId: $activeCameraSpotId
                )
            }
        }
    }

    /// `-pictriMapSpot <spotId>` / `-pictriMapArea <prefectureId>` / `-pictriMapPrefecture <prefectureId>`
    /// で、日本全体Map→県詳細→エリア探索→スポット詳細のうち任意の深さを直接スクショ確認できるようにする。
    /// DEBUG限定。実際の導線と同じ積み上がり方のnavigation stackを再現する
    /// (戻るボタンの挙動も本番と同じにするため、途中の階層を必ず経由してpushする)。
    private func openDebugSpotIfRequested() {
        #if DEBUG
        guard path.isEmpty else { return }

        func prefecture(for id: String) -> QuestPrefecture? {
            mockQuestPrefectures.first { $0.id == id }
        }

        if let spotId = PictriVisualReview.mapSpotId,
           let spot = mockQuestSpots.first(where: { $0.id == spotId }),
           let matchedPrefecture = prefecture(for: spot.prefectureId) {
            path.append(PrefectureDetailRoute(prefecture: matchedPrefecture))
            path.append(AreaExploreRoute(prefecture: matchedPrefecture))
            path.append(spot)
            return
        }

        if let prefectureId = PictriVisualReview.mapAreaPrefectureId,
           let matchedPrefecture = prefecture(for: prefectureId) {
            path.append(PrefectureDetailRoute(prefecture: matchedPrefecture))
            path.append(AreaExploreRoute(prefecture: matchedPrefecture))
            return
        }

        if let prefectureId = PictriVisualReview.mapPrefectureId,
           let matchedPrefecture = prefecture(for: prefectureId) {
            path.append(PrefectureDetailRoute(prefecture: matchedPrefecture))
            return
        }
        #endif
    }
}

// MARK: - Shared shape rendering

/// questPrefectureShapesの座標(共有キャンバス基準の絶対値)を、任意のscale/offsetで
/// 変換してから描画するPath。日本全体Mapと県詳細のズームしたサブMapの両方で使う。
private struct QuestScaledShapePath: Shape {
    let points: [CGPoint]
    var scale: CGFloat
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        func transformed(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
        }

        path.move(to: transformed(first))
        for point in points.dropFirst() {
            path.addLine(to: transformed(point))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Japan Overview Screen (日本全体Map)

private struct QuestJapanOverviewScreen: View {
    let visitedPrefectureIds: Set<String>
    let onSelectPrefecture: (QuestPrefecture) -> Void

    @State private var showRegionList = false

    private var visitedCount: Int { visitedPrefectureIds.count }

    var body: some View {
        ZStack {
            PictriLightTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    PictriLightProgressCard(
                        icon: "mappin.circle.fill",
                        label: "訪れた都道府県",
                        current: visitedCount,
                        total: 47
                    )

                    japanMapPanel

                    PictriLightShareCard(
                        shareText: "PicTriで訪れた都道府県 \(visitedCount)/47 を記録中!"
                    )

                    Spacer(minLength: JQUI.bottomBarReserve)
                }
                .padding(.horizontal, JQUI.sidePadding)
                .padding(.top, 14)
            }
        }
        .sheet(isPresented: $showRegionList) {
            QuestRegionListSheet(
                visitedPrefectureIds: visitedPrefectureIds,
                onSelect: { prefecture in
                    showRegionList = false
                    onSelectPrefecture(prefecture)
                }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse.circle.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(PictriLightTheme.accent)

            Text("PicTri")
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(PictriLightTheme.textPrimary)

            Spacer()
        }
    }

    private var japanMapPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            QuestJapanMapView(
                visitedPrefectureIds: visitedPrefectureIds,
                onSelect: onSelectPrefecture
            )
            .padding(.vertical, 10)

            Button {
                showRegionList = true
            } label: {
                PictriLightFloatingPill(text: "地域一覧", systemImage: "list.bullet")
            }
            .padding(16)
        }
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 18, x: 0, y: 8)
    }
}

/// 47都道府県を1枚の日本地図として描画する。訪問済みは淡いteal/mint/sky blue、
/// 未訪問はlight grayで塗り分け、タップで県詳細へ遷移する。
private struct QuestJapanMapView: View {
    let visitedPrefectureIds: Set<String>
    let onSelect: (QuestPrefecture) -> Void

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / QuestJapanMapMetrics.canvasWidth

            ZStack(alignment: .topLeading) {
                decorations(scale: scale)

                ForEach(questPrefectureShapes) { shape in
                    let isVisited = visitedPrefectureIds.contains(shape.id)
                    let fillColor = isVisited
                        ? PictriLightTheme.visitedPrefectureColor(id: shape.id)
                        : PictriLightTheme.unvisitedFill

                    ZStack {
                        QuestScaledShapePath(points: shape.points, scale: scale)
                            .fill(fillColor)

                        QuestScaledShapePath(points: shape.points, scale: scale)
                            .stroke(PictriLightTheme.unvisitedStroke, lineWidth: 1)
                    }
                    .contentShape(QuestScaledShapePath(points: shape.points, scale: scale))
                    .onTapGesture {
                        let prefecture = mockQuestPrefectures.first(where: { $0.id == shape.id })
                            ?? QuestPrefecture(id: shape.id, name: shape.name, englishName: shape.id, totalSpotCount: 0)
                        onSelect(prefecture)
                    }
                    .accessibilityLabel("\(shape.name)、\(isVisited ? "訪問済み" : "未訪問")")
                }
            }
            .frame(width: proxy.size.width, height: QuestJapanMapMetrics.canvasHeight * scale)
        }
        .aspectRatio(QuestJapanMapMetrics.canvasWidth / QuestJapanMapMetrics.canvasHeight, contentMode: .fit)
    }

    /// 海や余白に控えめに置く木・波のモチーフ。以前Cameraのプレースホルダーで
    /// 「灰色の矩形が壊れて見える」問題が起きた反省から、極薄い不透明度に留めている。
    private func decorations(scale: CGFloat) -> some View {
        ZStack {
            PictriPineTreeMotif().position(x: 34 * scale, y: 96 * scale)
            PictriPineTreeMotif().position(x: 50 * scale, y: 132 * scale)
            PictriWaveMotif(width: 30).position(x: 290 * scale, y: 160 * scale)
            PictriWaveMotif(width: 26).position(x: 290 * scale, y: 260 * scale)
            PictriWaveMotif(width: 22).position(x: 232 * scale, y: 355 * scale)
        }
        .opacity(0.32)
        .allowsHitTesting(false)
    }
}

/// 「地域一覧」から一括で都道府県を見て選べる、日本地図の代替となるリスト表示。
private struct QuestRegionListSheet: View {
    let visitedPrefectureIds: Set<String>
    let onSelect: (QuestPrefecture) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(questPrefectureShapes) { shape in
                let isVisited = visitedPrefectureIds.contains(shape.id)

                Button {
                    let prefecture = mockQuestPrefectures.first(where: { $0.id == shape.id })
                        ?? QuestPrefecture(id: shape.id, name: shape.name, englishName: shape.id, totalSpotCount: 0)
                    onSelect(prefecture)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(isVisited ? PictriLightTheme.visitedPrefectureColor(id: shape.id) : PictriLightTheme.unvisitedFill)
                            .frame(width: 10, height: 10)

                        Text(shape.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PictriLightTheme.textPrimary)

                        Spacer()

                        if isVisited {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(PictriLightTheme.teal)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("地域一覧")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(PictriLightTheme.accent)
                }
            }
        }
    }
}

// MARK: - Prefecture Detail Screen (都道府県詳細)

private struct QuestPrefectureDetailScreen: View {
    let prefecture: QuestPrefecture
    let isVisited: Bool
    @Binding var path: NavigationPath

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.dismiss) private var dismiss

    /// 神奈川固定ではなく、実際にmockQuestSpotsへその県のスポットが1件でもあるかで判定する。
    /// スポットが無い県は形と訪問可否だけ見せ、「準備中」として無理にデータを捏造しない。
    /// 将来、東京・京都・北海道などへ実スポットを追加すれば、この判定は自動的に切り替わる。
    private var hasRealSpotData: Bool {
        !spots.isEmpty
    }

    private var spots: [QuestSpot] {
        mockQuestSpots
            .filter { $0.prefectureId == prefecture.id }
            .sorted { $0.gridIndex < $1.gridIndex }
    }

    private var completedSpotIds: Set<String> {
        Set(
            memoryStore.memoryPhotos
                .filter { $0.prefectureId == prefecture.id }
                .map { $0.spotId }
        )
    }

    private var completedCount: Int {
        #if DEBUG
        if let override = PictriVisualReview.prefectureCountOverride(for: prefecture.id) {
            return override
        }
        #endif
        return completedSpotIds.count
    }

    private var totalCount: Int {
        max(prefecture.totalSpotCount, spots.count)
    }

    private var achievementRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private var nextSpots: [QuestSpot] {
        Array(spots.filter { !completedSpotIds.contains($0.id) }.prefix(4))
    }

    private var shape: QuestPrefectureShape? {
        questPrefectureShapes.first { $0.id == prefecture.id }
    }

    var body: some View {
        ZStack {
            PictriLightTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    backLink
                    titleRow

                    if hasRealSpotData {
                        PictriLightProgressCard(
                            icon: "camera.fill",
                            label: "訪問スポット",
                            current: completedCount,
                            total: totalCount
                        )
                    } else {
                        comingSoonCard
                    }

                    if let shape {
                        prefectureSubMap(shape: shape)
                    }

                    if hasRealSpotData, completedCount > 0, achievementRatio < 1 {
                        PictriLightNudgeCard(
                            title: "あと少しで達成!",
                            detail: "\(prefecture.name)の訪問率 \(Int((achievementRatio * 100).rounded()))%",
                            accentColor: PictriLightTheme.teal
                        )
                    } else if hasRealSpotData, completedCount == 0 {
                        PictriLightNudgeCard(
                            title: "ここから色づいていきます",
                            detail: "\(prefecture.name)で最初の一枚を残しに行こう",
                            systemImage: "sparkles",
                            accentColor: PictriLightTheme.sand
                        )
                    }

                    if hasRealSpotData, !nextSpots.isEmpty {
                        nextSpotsSection
                    }

                    collectionCTACard

                    Spacer(minLength: JQUI.bottomBarReserve)
                }
                .padding(.horizontal, JQUI.sidePadding)
                .padding(.top, 14)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var backLink: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("都道府県一覧に戻る")
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(PictriLightTheme.textSecondary)
        }
        .accessibilityLabel("都道府県一覧に戻る")
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prefecture.name)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(PictriLightTheme.textPrimary)

            if hasRealSpotData {
                Button {
                    path.append(AreaExploreRoute(prefecture: prefecture))
                } label: {
                    Label("エリアを探索する", systemImage: "map.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PictriLightTheme.mint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PictriLightTheme.mintSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var comingSoonCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PictriLightTheme.textSecondary)
                .frame(width: 40, height: 40)
                .background(PictriLightTheme.sandSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("この県のスポットは準備中です")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("ここも、これから色づいていきます")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(PictriLightTheme.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 12, x: 0, y: 4)
    }

    /// 実スポットデータがある県(拡大表示され、精度が厳しく見られる)は実在のMapKit地図を、
    /// データが無い県(準備中カードのみで、拡大して精査される場面が無い)は従来の
    /// 簡略シルエットを使う。粗いポリゴンを「拡大しても信頼できる地図」として
    /// 見せることはしない、という今回の方針をそのまま反映している。
    private func prefectureSubMap(shape: QuestPrefectureShape) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if hasRealSpotData {
                QuestPrefectureOverviewMapView(
                    spots: spots,
                    completedSpotIds: completedSpotIds,
                    onSpotSelected: { spot in
                        path.append(spot)
                    },
                    onClusterSelected: {
                        path.append(AreaExploreRoute(prefecture: prefecture))
                    }
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 10)
            } else {
                QuestPrefectureSubMapView(
                    shape: shape,
                    isVisited: isVisited
                )
                .frame(height: 300)
            }

            if hasRealSpotData {
                Button {
                    path.append(AreaExploreRoute(prefecture: prefecture))
                } label: {
                    PictriLightFloatingPill(text: "エリア一覧", systemImage: "list.bullet")
                }
                .padding(16)
            }
        }
        .padding(.vertical, 10)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 18, x: 0, y: 8)
    }

    private var nextSpotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("次に行きたい場所")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PictriLightTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(nextSpots) { spot in
                        Button {
                            path.append(AreaExploreRoute(prefecture: prefecture))
                        } label: {
                            PictriLightSpotCard(
                                title: spot.name,
                                subtitle: spot.areaName,
                                isVisited: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(spot.name)、\(spot.areaName)")
                    }
                }
            }
        }
    }

    private var collectionCTACard: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PictriLightTheme.teal)
                .frame(width: 40, height: 40)
                .background(PictriLightTheme.teal.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("思い出をコレクションしよう")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("訪れた場所の写真を記録して、あなただけの地図を完成させよう。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PictriLightTheme.textFaint)
        }
        .padding(16)
        .background(PictriLightTheme.teal.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// 実スポットデータがまだ無い県の、簡略シルエットだけのプレビュー。
/// 拡大して精査される場面が無い(準備中カードのみで詳細情報が無い)ため、
/// QuestMapGeoDataの簡略ポリゴンで「どの県か」を示す用途に限定している。
/// 実スポットがある県はQuestPrefectureOverviewMapView(実在のMapKit地図)を使う。
private struct QuestPrefectureSubMapView: View {
    let shape: QuestPrefectureShape
    let isVisited: Bool

    private var bounds: (minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) {
        let xs = shape.points.map { $0.x }
        let ys = shape.points.map { $0.y }
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        let width = max((xs.max() ?? 1) - minX, 1)
        let height = max((ys.max() ?? 1) - minY, 1)
        return (minX, minY, width, height)
    }

    var body: some View {
        GeometryReader { proxy in
            let box = bounds
            let pad: CGFloat = 26
            let scale = min(
                (proxy.size.width - pad * 2) / box.width,
                (proxy.size.height - pad * 2) / box.height
            )
            let offsetX = (proxy.size.width - box.width * scale) / 2 - box.minX * scale
            let offsetY = (proxy.size.height - box.height * scale) / 2 - box.minY * scale
            let fillColor = isVisited ? PictriLightTheme.visitedPrefectureColor(id: shape.id) : PictriLightTheme.unvisitedFill

            ZStack {
                QuestScaledShapePath(points: shape.points, scale: scale, offsetX: offsetX, offsetY: offsetY)
                    .fill(fillColor)

                QuestScaledShapePath(points: shape.points, scale: scale, offsetX: offsetX, offsetY: offsetY)
                    .stroke(.white, lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Area Explore Screen (エリア/スポット探索)

private struct QuestAreaExploreScreen: View {
    let prefecture: QuestPrefecture
    @Binding var path: NavigationPath

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var mapZoomLevel: QuestMapZoomLevel = QuestAreaExploreScreen.resolveInitialZoomLevel()
    @State private var selectedCategory: QuestSpotCategory? = QuestAreaExploreScreen.resolveInitialCategory()

    private static let filterCategories: [QuestSpotCategory] = [.nature, .photogenic, .landmark, .cafe]

    /// `-pictriMapAreaLevel prefecture|area|spots` でズーム段階を直接指定する。DEBUG限定。
    /// 自動ピンチズームが難しい環境でも、ズーム後の表示をスクショ確認できるようにする。
    private static func resolveInitialZoomLevel() -> QuestMapZoomLevel {
        #if DEBUG
        return PictriVisualReview.mapAreaLevel ?? .prefecture
        #else
        return .prefecture
        #endif
    }

    /// `-pictriMapCategory nature|photogenic|landmark|cafe` でフィルタ状態を直接指定する。DEBUG限定。
    private static func resolveInitialCategory() -> QuestSpotCategory? {
        #if DEBUG
        return PictriVisualReview.mapCategory
        #else
        return nil
        #endif
    }

    private var allSpots: [QuestSpot] {
        mockQuestSpots
            .filter { $0.prefectureId == prefecture.id }
            .sorted { $0.gridIndex < $1.gridIndex }
    }

    private var filteredSpots: [QuestSpot] {
        guard let selectedCategory else { return allSpots }
        return allSpots.filter { $0.category == selectedCategory }
    }

    private var completedSpotIds: Set<String> {
        Set(
            memoryStore.memoryPhotos
                .filter { $0.prefectureId == prefecture.id }
                .map { $0.spotId }
        )
    }

    private var nearbySpots: [QuestSpot] {
        Array(filteredSpots.prefix(6))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PictriLightTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterRow

                QuestMapKitView(
                    prefecture: prefecture,
                    spots: filteredSpots,
                    completedSpotIds: completedSpotIds,
                    zoomLevel: $mapZoomLevel
                ) { spot in
                    path.append(spot)
                }
            }

            nearbySpotsCard
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("戻る")

            Text("\(prefecture.name)周辺")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PictriLightTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, JQUI.sidePadding)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(PictriLightTheme.background)
    }

    /// カテゴリごとに自然な差し色を与える。全部同じ色(青)になると
    /// フィルタの意味が伝わらず、生成テンプレのように見えてしまうため。
    private func tone(for category: QuestSpotCategory) -> PictriLightTone {
        switch category {
        case .nature: return .mint
        case .photogenic: return .lavender
        case .landmark: return .amber
        case .cafe: return .coral
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategory = nil
                } label: {
                    PictriLightFilterChip(text: "すべて", isSelected: selectedCategory == nil, tone: .neutral)
                }
                .buttonStyle(.plain)

                ForEach(Self.filterCategories, id: \.self) { category in
                    Button {
                        selectedCategory = (selectedCategory == category) ? nil : category
                    } label: {
                        PictriLightFilterChip(
                            text: category.label,
                            systemImage: category.systemImage,
                            isSelected: selectedCategory == category,
                            tone: tone(for: category)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, JQUI.sidePadding)
        }
        .padding(.bottom, 10)
        .background(PictriLightTheme.background)
    }

    private var nearbySpotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近くのスポット")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(PictriLightTheme.textPrimary)

            if nearbySpots.isEmpty {
                Text("このカテゴリのスポットはまだありません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(nearbySpots) { spot in
                            Button {
                                path.append(spot)
                            } label: {
                                PictriLightSpotCard(
                                    title: spot.name,
                                    subtitle: spot.areaName,
                                    isVisited: completedSpotIds.contains(spot.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(spot.name)、\(spot.areaName)。スポット詳細を開く")
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 20, x: 0, y: -4)
        .padding(.horizontal, 12)
        .padding(.bottom, JQUI.bottomBarReserve - 26)
    }
}

// MARK: - Spot Detail (Cameraへの入口。既存の黒基調UIを維持)

struct QuestSpotDetailView: View {
    let spot: QuestSpot
    @Binding var selectedTab: AppTab
    @Binding var activeCameraSpotId: String

    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var locationManager: QuestLocationManager

    @AppStorage("developerUnlockMode") private var developerUnlockMode = false

    private var isCompleted: Bool {
        memoryStore.hasMemory(for: spot)
    }

    private var isUnlocked: Bool {
        developerUnlockMode || locationManager.isNear(spot)
    }

    private var statusText: String {
        if developerUnlockMode {
            return "開発モードで撮影できます"
        }

        if isUnlocked {
            return "現地で撮影できます"
        }

        return "現地に近づくと撮影できます"
    }

    // MARK: - SpotDetail theme colors
    private var cardBackground: Color { PictriTheme.surface }
    private var primaryText: Color { .white }
    private var secondaryText: Color { .white.opacity(0.48) }
    private var dividerColor: Color { .white.opacity(0.10) }

    var body: some View {
        ZStack {
            // Cameraへの入口の画面なので、純黒ではなくCameraと同じdeep indigoに揃える。
            PictriLightTheme.photoDepth.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    statusCard
                    actionButton
                    memoryPreview
                    Spacer(minLength: JQUI.bottomBarReserve)
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34)
                .fill(MemoryVisualStyle.gradient(for: spot))
                .frame(height: 360)

            LinearGradient(
                colors: [
                    .black.opacity(0),
                    .black.opacity(0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 34))

            VStack(alignment: .leading, spacing: 8) {
                Text(spot.areaName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(spot.name)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text(spot.englishName.lowercased())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.16))
                        .clipShape(Capsule())

                    heroStatusChip
                }
                .foregroundStyle(.white)
            }
            .padding(24)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("撮影状態")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(secondaryText)

                    Text(statusText)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(primaryText)
                }

                Spacer()

                Image(systemName: isUnlocked ? "camera.fill" : "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle((isCompleted || isUnlocked) ? .black : .white.opacity(0.40))
                    .frame(width: 46, height: 46)
                    .background(statusIconColor)
                    .clipShape(Circle())
            }

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack {
                PictriCompactMetric(label: "現在地から", value: locationManager.distanceText(to: spot))

                Spacer()

                PictriCompactMetric(label: "メモリー", value: isCompleted ? "保存済み" : "未撮影")
            }

            Text("現地に着くと解放。正確な住所は表示されません。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondaryText)
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .animation(.easeInOut(duration: 0.3), value: isUnlocked)
    }

    /// teal=「記憶がある(isCompleted)」、accent=「今できる行動(isUnlocked)」で役割を分離する。
    /// 現在地に関わらず、一度でも撮ったスポットは常にtealのまま。
    /// 撮影可能だが未訪問のスポットをtealにすると「訪問済み」に見えてしまうため、
    /// その場合はaccentを使う(Memories側のteal=訪問済みという意味と衝突させない)。
    private var statusIconColor: Color {
        if isCompleted { return PictriTheme.teal }
        if isUnlocked { return PictriTheme.accent }
        return .white.opacity(0.10)
    }

    /// Cameraの2ステップ("景色→表情")を撮影前に予告する小さなプレビュー。
    /// SpotDetailが「地図の詳細ページ」ではなく「撮影の入口」だと視覚的につなげる役割。
    private var captureStepsPreview: some View {
        HStack(spacing: 8) {
            capturePreviewPill(label: "景色", systemImage: "mountain.2.fill")
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.28))
            capturePreviewPill(label: "表情", systemImage: "face.smiling.fill")
        }
        .opacity(isUnlocked ? 1 : 0.4)
    }

    private var capturePillForeground: Color {
        guard isUnlocked else { return .white.opacity(0.42) }
        return isCompleted ? PictriTheme.teal : PictriTheme.accent
    }

    private var capturePillBackground: Color {
        guard isUnlocked else { return .white.opacity(0.06) }
        return isCompleted ? PictriTheme.tealSoft : PictriTheme.accentSoft
    }

    private func capturePreviewPill(label: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(capturePillForeground)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(capturePillBackground)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var heroStatusChip: some View {
        if isCompleted {
            Label("撮影済み", systemImage: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())
        } else if isUnlocked {
            Label("撮影可能", systemImage: "camera.fill")
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(PictriTheme.accent)
                .foregroundStyle(.black)
                .clipShape(Capsule())
        } else {
            Label("未撮影", systemImage: "circle")
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.13))
                .foregroundStyle(.white.opacity(0.70))
                .clipShape(Capsule())
        }
    }

    /// 撮影済みスポットへ戻ってきた時は「もう一枚残す」、初めてのスポットは
    /// 「この場所で撮る」と分けることで、PicTriの「現地で残す」体験を強調する。
    private var actionButtonLabel: String {
        guard isUnlocked else { return "現地に行くと撮れます" }
        return isCompleted ? "もう一枚、ここで残す" : "この場所で撮る"
    }

    /// 訪問済み(teal)でもう一枚残す場合は「記憶(teal)→次の一枚(accent)」のグラデーションのまま。
    /// 初めて訪れる場所は記憶がまだ無いので、teal無しの単色accentにする
    /// (accentだけの単色でも「訪問済みに見える」ほど強い印象を残さないため)。
    private var actionButtonBackground: AnyShapeStyle {
        guard isUnlocked else { return AnyShapeStyle(.white.opacity(0.10)) }
        guard isCompleted else { return AnyShapeStyle(PictriTheme.accent) }
        return AnyShapeStyle(
            LinearGradient(
                colors: [PictriTheme.teal, PictriTheme.accent],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var actionButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            captureStepsPreview

            Button {
                guard isUnlocked else {
                    return
                }

                activeCameraSpotId = spot.id
                selectedTab = .camera
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isUnlocked ? "camera.fill" : "location.fill")
                    Text(actionButtonLabel)
                }
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(actionButtonBackground)
                .foregroundStyle(isUnlocked ? .black : .white.opacity(0.38))
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .disabled(!isUnlocked)
            .accessibilityLabel(isUnlocked ? "\(spot.name)でカメラを起動" : "\(spot.name)は現地に行くと撮影できます")
            .animation(.easeInOut(duration: 0.3), value: isUnlocked)
        }
    }

    private var memoryPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メモリー")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(primaryText)

            if let image = memoryStore.image(for: spot) {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 24))

                    PictriGlassPill(text: spot.englishName.lowercased(), tone: .muted)
                        .padding(14)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(cardBackground)
                        .frame(height: 220)

                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.white.opacity(0.28))

                        Text("ここで最初の一枚を残そう")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
    }

}
