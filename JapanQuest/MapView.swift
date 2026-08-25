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
    /// 導出の実体はQuestMemoryStore.visitedPrefectureIds(正式なSource of Truth)を
    /// そのまま使い、ここでは重複計算しない。DEBUG限定でプレビュー用に追加の県を
    /// 「訪問済みに見せる」上乗せだけをView側で行う(memoryStoreへは一切書き込まない、
    /// 表示専用)。
    private var visitedPrefectureIds: Set<String> {
        var ids = memoryStore.visitedPrefectureIds
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

        // mockQuestPrefecturesに登録されていない県(埼玉・千葉・大阪など、まだ実スポット
        // データを持たない43県)は、以前この関数だとnilを返して何も起きなかった
        // (DEBUG hookが実質未登録県に対応していなかった)。実際のMapタップ導線
        // (PictriJapanCollectionMap.prefecture(for shape:))は、mockQuestPrefecturesに
        // 無ければquestPrefectureShapesの名前からその場でQuestPrefecture(totalSpotCount: 0)を
        // 合成しており、これと全く同じ合成ロジックをここでも使うことで、DEBUG launch arg
        // (`-pictriMapPrefecture <id>`)から実タップと同じPrefecture Detail(準備中表示)へ
        // 到達できるようにする。mockQuestPrefectures・QuestPrefectureモデル・本番の
        // タップ導線は一切変更していない。
        func prefecture(for id: String) -> QuestPrefecture? {
            if let registered = mockQuestPrefectures.first(where: { $0.id == id }) {
                return registered
            }
            guard let shape = questPrefectureShapes.first(where: { $0.id == id }) else { return nil }
            return QuestPrefecture(id: shape.id, name: shape.name, englishName: shape.id, totalSpotCount: 0)
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

    /// Home(topBar)・Memories(memoriesHeader)と同じ「30pt太字タイトル + 13pt subtitle」の
    /// 型に揃える。以前はここだけ21pt・subtitleなしの軽い見出しで、Mapだけ他の画面より
    /// 情報量の少ない/違うヘッダーに見えていた。
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PicTri")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("行けた場所が、地図に残る")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            Spacer()
        }
    }

    /// Claude Design Final Handoff(PICTRI_DO_NOT_DEGRADE.md #4 / PICTRI_SWIFTUI_HANDOFF.md
    /// 「Map: ...Never MapKit.」)をVisual Source of Truthとして、実MapKit版の
    /// QuestJapanOverviewMapViewから、questPrefectureShapesを直接描画する
    /// PictriJapanCollectionMapへ置き換えた。ピンチズームchromeは仕様上持たない
    /// (「no zoom/pan chrome」)。タップで従来通り県詳細へ遷移する導線(onSelectPrefecture)
    /// は完全に維持している。マップ自体は白カードで囲わない
    /// (PICTRI_DO_NOT_DEGRADE.md #1「No generic white rounded cards」)。
    private var japanMapPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                PictriJapanCollectionMap(
                    visitedPrefectureIds: visitedPrefectureIds,
                    onSelect: onSelectPrefecture
                )
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: PictriLightTheme.heroCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PictriLightTheme.heroCornerRadius, style: .continuous)
                        .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
                }

                Button {
                    showRegionList = true
                } label: {
                    PictriLightFloatingPill(text: "地域一覧", systemImage: "list.bullet")
                }
                .padding(16)
            }

            Text("タップで都道府県へ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PictriLightTheme.textFaint)
                .padding(.horizontal, 4)
        }
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
        .pictriLightCard(cornerRadius: PictriLightTheme.rowCornerRadius, fill: PictriLightTheme.warmWhite, shadowRadius: 12)
    }

    /// 実スポットデータの有無にかかわらず、Prefecture Detailの「コレクション体験」としての
    /// 県shapeパネルは同じ見た目(QuestPrefectureSubMapView、日本全体Mapと同じ曲線shape+
    /// paper/ink)に統一する。
    ///
    /// ## MapKit監査(6回目の監査で判明)
    /// 以前は実スポットがある県(神奈川・東京・京都・北海道)だけ、ここに実在の
    /// `QuestPrefectureOverviewMapView`(MKMapView、Apple Mapsのタイル・道路・標準ピンを
    /// 表示)を使っていた。これはPICTRI_DO_NOT_DEGRADE.md #4「No Apple Maps / MapKit as
    /// the map. The Japan collection map is the product.」に明確に違反しており、
    /// 「準備中」の県(paper+shape)と「訪問対象」の県(Apple Maps)とで別アプリのように
    /// 見た目が分断していた。この widget が担っていた機能を洗い出した結果:
    ///   - スポットpin単体タップ→スポット詳細への直接遷移(実際の緯度経度を使用)
    ///   - クラスタタップ→エリア探索(AreaExploreRoute)への遷移
    ///   - 「エリア一覧」pill → エリア探索への遷移
    /// のうち、後の2つは既にこの下の「エリア一覧」ボタン(MapKitではない、ただのボタン)
    /// が担っている。スポットpin単体タップの直接遷移だけがこのwidget固有の機能だった。
    /// 県shapeの簡略キャンバス座標(questPrefectureShapes)には、スポットの実緯度経度を
    /// 正確に投影する座標変換テーブルが存在しない(QuestMapGeoData.swiftのコメント通り、
    /// 神奈川用の投影テーブルは実MapKit採用時に廃止済み)。それらしい位置にpinを
    /// 置くこと(fake coordinate)は禁止されているため、スポットpinをこのpanelへ
    /// 復元することはしない。「次に行きたい場所」セクション・「エリアを探索する」
    /// ボタン・「エリア一覧」ボタンが、実際のスポットへの導線を引き続き担保する
    /// (エリア探索画面は本物のpan/zoom可能なMapKit実装のままで、今回変更していない
    /// 。地図としてのCollection体験からのみApple Maps visualを排除した)。
    @ViewBuilder
    private func prefectureSubMap(shape: QuestPrefectureShape) -> some View {
        ZStack(alignment: .bottomTrailing) {
            QuestPrefectureSubMapView(
                shape: shape,
                isVisited: isVisited
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous)
                    .stroke(PictriFinalTheme.line, lineWidth: 1)
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

/// Prefecture Detailの県shapeプレビュー。実スポットデータの有無を問わず
/// (準備中の県も、実スポットがある県も)共通で使う。以前は実スポットがある県だけ
/// `QuestPrefectureOverviewMapView`(実在のMapKit地図、Apple Mapsタイル・道路・標準ピン)を
/// 使っていたが、DO_NOT_DEGRADE #4「No Apple Maps / MapKit as the map」に反していたため、
/// Collection体験としてのこのpanelからはMapKitを廃止した(スポット単位のpan/zoom地図は
/// エリア探索画面(QuestMapKitView)にそのまま残っている、削除していない)。
///
/// 描画は直線ポリゴンではなく、日本全体Map(PictriJapanCollectionMap)と同じ
/// 辺制約つき角丸めshape(PictriCollectionPrefecturePath)・同じ配色ルール
/// (paper/dormant/memoryColor/ink)を再利用する。県詳細だけ別の描き方・別の配色にすると、
/// 拡大されるぶん「日本全体Mapと違う県の形」に見えてしまうため。
private struct QuestPrefectureSubMapView: View {
    let shape: QuestPrefectureShape
    let isVisited: Bool

    /// PictriJapanCollectionMap.swiftのQuestPrefectureGeometryが一度だけ計算する
    /// sanitized points(2-opt untangling済み、自己交差ゼロ)をそのまま参照する。
    /// 日本全体Mapとhit-test/表示geometryの出所を分けない(単一のsource of truth)。
    private var sanitizedPoints: [CGPoint] {
        QuestPrefectureGeometry.points(for: shape)
    }

    private var bounds: (minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) {
        let xs = sanitizedPoints.map { $0.x }
        let ys = sanitizedPoints.map { $0.y }
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        let width = max((xs.max() ?? 1) - minX, 1)
        let height = max((ys.max() ?? 1) - minY, 1)
        return (minX, minY, width, height)
    }

    var body: some View {
        GeometryReader { proxy in
            let box = bounds
            let pad: CGFloat = 30
            let scale = min(
                (proxy.size.width - pad * 2) / box.width,
                (proxy.size.height - pad * 2) / box.height
            )
            let offsetX = (proxy.size.width - box.width * scale) / 2 - box.minX * scale
            let offsetY = (proxy.size.height - box.height * scale) / 2 - box.minY * scale
            let path = PictriCollectionPrefecturePath(points: sanitizedPoints, scale: scale, offsetX: offsetX, offsetY: offsetY)
            let fillColor = isVisited ? PictriFinalTheme.memoryColor(for: shape.id) : PictriFinalTheme.dormant

            ZStack {
                PictriFinalTheme.paper

                path
                    .fill(fillColor)
                    .overlay {
                        if isVisited {
                            path.stroke(PictriFinalTheme.ink, lineWidth: 1.4)
                        } else {
                            path.stroke(PictriFinalTheme.dormantDot, style: StrokeStyle(lineWidth: 1, dash: [2.5, 2]))
                        }
                    }
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
    @State private var debugSelectedSpotId: String? = QuestAreaExploreScreen.resolveInitialSelectedSpotId()

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

    /// `-pictriMapSelectedSpot <spotId>` で選択中スポットの見た目(ピン強調・カード強調)を
    /// タップなしで直接指定する。DEBUG限定。整合性チェックは`effectiveSelectedSpotId`側で行う。
    private static func resolveInitialSelectedSpotId() -> String? {
        #if DEBUG
        return PictriVisualReview.mapSelectedSpotId
        #else
        return nil
        #endif
    }

    /// 指定spotIdが現在のフィルタ結果に含まれない場合は無視する(推奨方針A: フィルタ優先)。
    /// 存在しないspotId・別の県のspotId・フィルタで除外されたカテゴリのspotIdは、
    /// すべてこのガードで自動的に「選択なし」として扱われる。
    private var effectiveSelectedSpotId: String? {
        guard let debugSelectedSpotId else { return nil }
        guard filteredSpots.contains(where: { $0.id == debugSelectedSpotId }) else { return nil }
        return debugSelectedSpotId
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
                    selectedSpotId: effectiveSelectedSpotId,
                    zoomLevel: $mapZoomLevel
                ) { spot in
                    path.append(spot)
                }
                .accessibilityIdentifier("pictri_area_map")
            }

            nearbySpotsCard
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("pictri_map_area_screen")
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
                .accessibilityIdentifier("pictri_filter_all")

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
                    .accessibilityIdentifier("pictri_filter_\(category.rawValue)")
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
                // 冷たいグレーのText一行だけではなく、Memories未訪問セルと同じsandトーンで
                // 「まだ無い」を軽く伝える(PictriEmptyStateほど大きくないため専用の簡易版)。
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PictriLightTheme.sand)

                    Text("このカテゴリのスポットはまだありません")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PictriLightTheme.textSecondary)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(PictriLightTheme.sandSoft)
                .clipShape(RoundedRectangle(cornerRadius: PictriLightTheme.rowCornerRadius, style: .continuous))
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
                                    isVisited: completedSpotIds.contains(spot.id),
                                    accentColor: QuestSpotCategoryColor.tone(for: spot.category),
                                    isSelected: spot.id == effectiveSelectedSpotId
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(spot.name)、\(spot.areaName)。スポット詳細を開く")
                            .accessibilityIdentifier("pictri_spot_card_\(spot.id)")
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(PictriLightTheme.surface)
        // Home/Memoriesの標準カードと同じcardCornerRadius(24)+borderに揃える。
        // ただし地図に浮かぶ下部シートのため、shadowだけは上向き(y: -4)のまま維持する
        // (通常カードの下向きshadowをそのまま使うと、地図側に影が落ちて不自然になる)。
        .clipShape(RoundedRectangle(cornerRadius: PictriLightTheme.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PictriLightTheme.cardCornerRadius, style: .continuous)
                .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
        }
        .shadow(color: PictriLightTheme.shadow, radius: 20, x: 0, y: -4)
        .padding(.horizontal, 12)
        .padding(.bottom, JQUI.bottomBarReserve - PictriLightTheme.cardCornerRadius)
    }
}

// MARK: - Spot Detail
//
// Secondary Experience Finalization Phase: 以前はこの画面だけ.white/.blackの
// ハードコード配色+旧PictriTheme/PictriLightTheme.photoDepthのままで、Appearance
// (Dark/Light)に一切追従していなかった。PictriFinalTheme/PictriDarkTheme(mode-aware)
// ベースへ全面的に作り直す。
//
// Product Role: Map=場所を探す、SpotDetail=その場所を知る、Camera=そこでMemoryを残す。
// SpotDetail = PLACE + MEMORY POSSIBILITY + UNLOCK STATE。スタンプラリー画面にはしない
// (ロック/チェックマークバッジ・「景色→表情」ステップ予告・gaming wordingを廃止)。
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

    /// Product Decision「Camera Unlock → Spot Unlock」。Cameraはどこでも使える
    /// (Anywhere Capture)ため、この状態はCamera自体をgateする意味を持たない、
    /// あくまで「このSpotとしての記録が今このタイミングで成立するか」を静かに伝えるだけ。
    /// 「ロック解除」「チャレンジ」のようなgaming wordingは使わない。
    private var stateText: String {
        if isCompleted { return "ここでの記憶がある" }
        if isUnlocked { return "ここで残せます" }
        return "まだ残していない場所"
    }

    private var stateIcon: String {
        if isCompleted { return "checkmark" }
        if isUnlocked { return "mappin" }
        return "circle"
    }

    private var stateIconColor: Color {
        if isCompleted { return PictriFinalTheme.accent }
        if isUnlocked { return PictriFinalTheme.inkSoft }
        return PictriFinalTheme.inkFaint
    }

    /// 撮影済みスポットへ戻ってきた時は「もう一枚残す」、初めてのスポットは
    /// 「この場所で残す」。Anywhere Captureのため、CTAは状態にかかわらず常に押せる
    /// (未unlockでも「カメラを開く」として機能し、Camera自体をgateしない)。
    private var actionTitle: String {
        guard isUnlocked else { return "カメラを開く" }
        return isCompleted ? "もう一枚、ここで残す" : "この場所で残す"
    }

    var body: some View {
        ZStack {
            PictriFinalTheme.paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    identity
                    stateRow
                    actionButton

                    if let image = memoryStore.image(for: spot) {
                        memoryPrint(image)
                    }

                    Spacer(minLength: JQUI.bottomBarReserve)
                }
                .padding(.horizontal, PictriFinalTheme.screenPadding)
                .padding(.top, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pictri_spot_detail_\(spot.id)")
    }

    /// 場所のidentity。公式Spot写真がProductionに存在しないため、写真Heroの代わりに
    /// Mapと同じ県shape(小さく・色付き、日本地図全体は再掲しない)+タイポグラフィだけで
    /// 場所らしさを成立させる(AI生成画像は追加しない、Design Spec 13章)。
    private var identity: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                prefectureShapeGlyph
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prefectureName)
                        .font(PictriTypography.mono(11, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(PictriFinalTheme.inkFaint)
                    Text(spot.areaName)
                        .font(PictriTypography.body(12, weight: .semibold))
                        .foregroundStyle(PictriFinalTheme.inkSoft)
                }
            }

            Text(spot.name)
                .font(PictriTypography.display(34))
                .foregroundStyle(PictriFinalTheme.ink)
        }
    }

    private var prefectureName: String {
        mockQuestPrefectures.first(where: { $0.id == spot.prefectureId })?.name
            ?? questPrefectureShapes.first(where: { $0.id == spot.prefectureId })?.name
            ?? spot.prefectureId
    }

    private var prefectureShapeGlyph: some View {
        GeometryReader { proxy in
            if let shape = questPrefectureShapes.first(where: { $0.id == spot.prefectureId }) {
                let points = QuestPrefectureGeometry.points(for: shape)
                let xs = points.map(\.x)
                let ys = points.map(\.y)
                let minX = xs.min() ?? 0
                let minY = ys.min() ?? 0
                let width = max((xs.max() ?? 1) - minX, 1)
                let height = max((ys.max() ?? 1) - minY, 1)
                let pad: CGFloat = 2
                let scale = min((proxy.size.width - pad * 2) / width, (proxy.size.height - pad * 2) / height)
                let offsetX = (proxy.size.width - width * scale) / 2 - minX * scale
                let offsetY = (proxy.size.height - height * scale) / 2 - minY * scale

                PictriCollectionPrefecturePath(points: points, scale: scale, offsetX: offsetX, offsetY: offsetY)
                    .fill(PictriFinalTheme.memoryColor(for: spot.prefectureId))
            }
        }
    }

    /// unlock状態+距離は1行の静かなテキストのみ。距離は位置情報が取れている時だけ
    /// 補助情報として添える(取得できない時に0m等のfake distanceは出さない)。
    private var stateRow: some View {
        HStack(spacing: 8) {
            Image(systemName: stateIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(stateIconColor)

            Text(stateText)
                .font(PictriTypography.body(13, weight: .semibold))
                .foregroundStyle(PictriFinalTheme.inkSoft)

            if locationManager.distance(to: spot) != nil {
                Text("・\(locationManager.distanceText(to: spot))")
                    .font(PictriTypography.mono(12, weight: .regular))
                    .foregroundStyle(PictriFinalTheme.inkFaint)
            }
        }
        .accessibilityElement(children: .combine)
        .animation(.easeInOut(duration: 0.3), value: isUnlocked)
    }

    private var actionButton: some View {
        Button {
            // Product Decision「Camera Unlock → Spot Unlock」。isUnlocked(このSpot
            // radius内か)にかかわらず、Cameraは常に開ける(Anywhere Capture)。
            // このSpotとしての記録・unlockが成立するかは、Camera側が保存時点の
            // 現在地で改めて判定する(CameraView.currentCaptureTarget参照)。
            activeCameraSpotId = spot.id
            selectedTab = .camera
        } label: {
            Text(actionTitle)
                .font(PictriTypography.body(15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(PictriFinalTheme.accent)
                .foregroundStyle(PictriFinalTheme.onAccent)
                .clipShape(RoundedRectangle(cornerRadius: PictriFinalTheme.radiusControl, style: .continuous))
        }
        .accessibilityLabel(isUnlocked ? "\(spot.name)でカメラを起動" : "カメラを起動、近づくと\(spot.name)の記録が残せます")
        .accessibilityIdentifier("pictri_spot_detail_camera_cta")
    }

    /// 既存Memoryがある場合のみ表示する(無ければ何も出さない。空の枠+説明文で
    /// 埋めない、上のCTAが既に撮影への導線を担っているため)。
    private func memoryPrint(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("この場所の記憶")
                .font(PictriTypography.mono(11, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(PictriFinalTheme.inkFaint)

            PictriPhotoPrint(rotationSeed: spot.id, aspectRatio: 4.0 / 5.0, padding: 7) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
    }
}
