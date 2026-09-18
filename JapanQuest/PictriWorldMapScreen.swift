import SwiftUI
import MapKit

// MARK: - MAP ROUND 2 — World Interactive Map
//
// Product Role Separation(spec):
// - Home Map = Collection Summary(47県Progress、static、Round 8のまま)
// - Map Tab  = World Explorer(実際に世界中をpan/zoomできるNative MapKit)
//
// 旧`PictriMapCollectionScreen`(Round 1、Japan Collection Map + 全国/地方で見る
// segment)はこのRoundでプロダクト方針が変わったため削除した。47県Progress
// coloringはHome/Album側に残り、Mapタブはこの画面から完全に切り離される
// (Home Mapはこのファイルを一切参照しない、Home Absolute Freeze継続)。
//
// MapKit: SwiftUI-native `Map(position:)`(iOS 17+、本プロジェクトのDeployment
// Target 26.4で利用可能)を使用。外部SDK・新規Package依存・API keyは追加しない。

struct PictriWorldMapScreen: View {
    let notificationBadgeCount: Int
    let onAccountTap: () -> Void
    let onHomeTap: () -> Void
    let onCameraTap: () -> Void
    let onAlbumTap: () -> Void
    @Binding var cameraPosition: MapCameraPosition
    /// MAP ROUND 4「CAMERA CONTEXT」: Spot DetailのCTAから既存のCamera導線へ
    /// 橋渡しするだけの薄いclosure。達成判定はCameraView側の既存GPS半径判定に
    /// 完全に委ねる(ここでは何も判定しない)。
    var onCaptureSpot: (QuestSpot) -> Void = { _ in }

    @EnvironmentObject var locationManager: QuestLocationManager
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedSpot: QuestSpot?
    /// MAP ROUND 4「SPOT DETAIL ARCHITECTURE」: compact Preview Cardとは別の
    /// 状態。Preview(`selectedSpot`)はmarker選択の軽量な表示のまま維持し、
    /// Detailはユーザーが明示的にCardをtapした時だけ開く2段階構造にする
    /// (大規模NavigationStack再設計はしない、単なる`.sheet(item:)`)。
    @State private var detailSpot: QuestSpot?

    // MARK: Round 3 — Search
    @StateObject private var searchCompleter = PictriMapSearchCompleter()
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool
    private var isSearchActive: Bool { isSearchFocused || !searchQuery.isEmpty }
    private var matchingSpots: [QuestSpot] { PictriMapSpotSearch.matches(for: searchQuery) }

    /// Density strategy(spec PART 3「SPOT VISIBILITY / CLUTTER」)。
    /// WORLD LEVEL(緯度/経度spanが広い)ではSpotを完全に隠す、COUNTRY LEVELでは
    /// 都道府県ごとに代表1件だけ、CITY/LOCAL LEVELでは可視領域内すべてを表示する。
    /// `mockQuestSpots`は現状54件程度のため事前indexは不要(将来数千件になっても、
    /// この関数自体はcamera regionでのO(n) filterのみで、World Level時は早期にnilを
    /// 返すため重い全件計算を避けられる)。
    private func visibleSpots(for region: MKCoordinateRegion) -> [QuestSpot] {
        let maxSpan = max(region.span.latitudeDelta, region.span.longitudeDelta)

        // WORLD LEVEL: 間引きではなく完全非表示(数十カ国分が同時に見える距離では
        // 個別Spotに意味が無く、密集して視認性を悪化させるだけのため)。
        guard maxSpan < 30 else { return [] }

        let candidates = mockQuestSpots.filter { spot in
            abs(spot.latitude - region.center.latitude) < region.span.latitudeDelta
                && abs(spot.longitude - region.center.longitude) < region.span.longitudeDelta
        }

        // COUNTRY LEVEL: 都道府県ごとに代表1件(gridIndexが最小=カタログ上の
        // 代表スポット)だけに間引く。
        guard maxSpan < 6 else {
            var seenPrefectures = Set<String>()
            return candidates
                .sorted { $0.gridIndex < $1.gridIndex }
                .filter { seenPrefectures.insert($0.prefectureId).inserted }
        }

        // CITY / LOCAL LEVEL: 可視領域内のRecommended Spotをすべて表示。
        return candidates
    }

    private var displayedSpots: [QuestSpot] {
        guard let visibleRegion else { return [] }
        return visibleSpots(for: visibleRegion)
    }

    var body: some View {
        GeometryReader { screen in
            ZStack(alignment: .top) {
                mapLayer
                    .ignoresSafeArea()

                // STEP 3「TOP CHROME」: 大きなheadingは無し。PicTri wordmark行の
                // 下にsoftなscrimを敷き、地図の内容に関わらずwordmark/pillの
                // 可読性を保つ(「大きなheader box」ではなく、透明→暗いgradientの
                // 薄い帯だけ)。
                LinearGradient(
                    colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 10) {
                    topChrome

                    searchBar

                    if isSearchActive {
                        PictriMapSearchResultsList(
                            spots: matchingSpots,
                            completions: searchCompleter.completions,
                            onSelectSpot: { selectSpotFromSearch($0) },
                            onSelectPlace: { selectPlaceFromSearch($0) }
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, PictriFinalTheme.screenPadding)
                .padding(.top, 8)

                if let selectedSpot, !isSearchActive {
                    VStack {
                        Spacer()
                        PictriMapSpotCard(
                            spot: selectedSpot,
                            distanceText: locationManager.currentLocation != nil ? locationManager.distanceText(to: selectedSpot) : nil,
                            representativeImage: memoryStore.image(for: selectedSpot),
                            onClose: { self.selectedSpot = nil },
                            onOpenDetail: { detailSpot = selectedSpot }
                        )
                        .padding(.horizontal, PictriFinalTheme.screenPadding)
                        .padding(.bottom, PictriHomeFloatingBarMetrics.reservedContentHeight(containerWidth: screen.size.width))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // STEP 8「CURRENT LOCATION」: 右下、Dockの少し上。Spot Cardが
                // 出ている時はその上まで避ける(spec「重ならないよう配置」)。
                if !isSearchActive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            PictriMapLocationButton(action: recenterOnUserLocation)
                        }
                    }
                    .padding(.trailing, PictriFinalTheme.screenPadding)
                    .padding(.bottom, currentLocationButtonBottomInset(containerWidth: screen.size.width))
                }

                PictriHomeControlDock(
                    containerWidth: screen.size.width,
                    onMapTap: {},
                    onCameraTap: onCameraTap,
                    onAlbumTap: onAlbumTap,
                    onHomeTap: onHomeTap,
                    currentScreen: .map
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, PictriHomeFloatingBarMetrics.bottomGap)
            }
        }
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.2), value: selectedSpot?.id)
        .animation(.easeInOut(duration: 0.18), value: isSearchActive)
        .onAppear {
            locationManager.requestPermission()
            applyDebugQAStateIfRequested()
        }
        // STEP 2「SPOT DETAIL ARCHITECTURE」/ STEP 15「MAP OCCLUSION」: 標準の
        // `.sheet`(medium/large detent)を使う。システム標準のcard-style
        // presentationは背後のMapを適度にdimして見せたまま縮小表示するため、
        // 「Mapが背景として意味を持つ」「full blurで真っ白/黒にしない」の両方を
        // 自然に満たす。閉じてもcameraPosition/selectedSpotはこのView自身の
        // stateのまま(sheetを閉じるだけでは一切リセットされない)。
        .sheet(item: $detailSpot) { spot in
            PictriSpotDetailSheet(
                spot: spot,
                prefectureName: prefectureName(for: spot.prefectureId),
                prefectureProgress: memoryStore.prefectureProgress(for: spot.prefectureId),
                hasMemory: memoryStore.hasMemory(for: spot),
                representativeImage: memoryStore.image(for: spot),
                eligibility: captureEligibility(for: spot),
                onCapture: { onCaptureSpot(spot) }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Spot Detail derivation (STEP 5/6/7/10/12)

    /// STEP 12「REGION / COUNTRY SCALABILITY」: 「都道府県」という文字列を
    /// architectureへ強制しない。既存の`mockQuestPrefectures`にあれば実データの
    /// 表示名(例:「東京都」)を、無ければ`questPrefectureShapes`から地名だけを、
    /// それも無ければid自体をfallbackとして返す(海外Spotが将来
    /// `prefectureId`に別の地域コードを持ってきても壊れない)。
    private func prefectureName(for prefectureId: String) -> String {
        mockQuestPrefectures.first(where: { $0.id == prefectureId })?.name
            ?? questPrefectureShapes.first(where: { $0.id == prefectureId })?.name
            ?? prefectureId
    }

    /// STEP 6「CAPTURE ELIGIBILITY」。既存の`hasMemory`(達成判定)・
    /// `isNear`(GPS半径判定)・`distanceText`をそのまま使うだけで、新しい
    /// 達成条件は一切追加しない。ユーザーがSpotをtapしただけでは
    /// `.completed`にならない(既存Memoryが無い限りここには絶対に来ない)。
    private func captureEligibility(for spot: QuestSpot) -> PictriSpotCaptureEligibility {
        if memoryStore.hasMemory(for: spot) {
            return .completed
        }
        guard locationManager.currentLocation != nil else {
            return .locationUnavailable
        }
        if locationManager.isNear(spot) {
            return .insideRange
        }
        return .outsideRange(distanceText: locationManager.distanceText(to: spot))
    }

    /// QA screenshot専用(DEBUG限定)。実際のtext入力/marker tapを
    /// Simulator上で自動化しにくいsearch候補表示・Spot選択状態を再現する。
    /// Production経路には一切影響しない。
    private func applyDebugQAStateIfRequested() {
        #if DEBUG
        if let query = PictriVisualReview.worldMapDebugSearchQuery {
            searchQuery = query
            searchCompleter.updateQuery(query, region: visibleRegion)
            isSearchFocused = true
        }
        if let spotId = PictriVisualReview.worldMapDebugSelectSpotId,
           let spot = mockQuestSpots.first(where: { $0.id == spotId }) {
            selectedSpot = spot
            if PictriVisualReview.worldMapDebugOpenDetail {
                detailSpot = spot
            }
        }
        #endif
    }

    /// Spot Cardが表示中は、Location buttonをCardの上まで押し上げて重なりを避ける。
    private func currentLocationButtonBottomInset(containerWidth: CGFloat) -> CGFloat {
        let dockInset = PictriHomeFloatingBarMetrics.reservedContentHeight(containerWidth: containerWidth)
        guard selectedSpot != nil else { return dockInset }
        return dockInset + 92
    }

    // MARK: - Search actions

    private func selectSpotFromSearch(_ spot: QuestSpot) {
        isSearchFocused = false
        searchQuery = ""
        searchCompleter.clear()
        selectedSpot = spot
        moveCamera(to: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude))
    }

    private func selectPlaceFromSearch(_ completion: MKLocalSearchCompletion) {
        isSearchFocused = false
        Task {
            guard let mapItem = await searchCompleter.resolve(completion) else { return }
            searchQuery = ""
            searchCompleter.clear()
            selectedSpot = nil
            moveCamera(to: mapItem.location.coordinate)
        }
    }

    /// STEP 13「SEARCH CAMERA TRANSITION」: instant jumpではなく落ち着いた
    /// animation(200〜450ms、Reduce Motion時は即時)。
    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.4)) {
            cameraPosition = .region(region)
        }
    }

    private func recenterOnUserLocation() {
        locationManager.requestPermission()
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.35)) {
            cameraPosition = .userLocation(fallback: .region(PictriWorldMapCamera.japanFallbackRegion))
        }
    }

    // MARK: - Map layer

    /// PART 6「MAP CHROME」: Interactive Mapを画面の主surfaceとして扱う
    /// (小さなrectangleへ閉じ込めない)。Top chromeやDockはこのレイヤーの上に
    /// 独立したoverlayとして重なるだけで、Map自体のframeを縮めない。
    private var mapLayer: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            UserAnnotation()

            ForEach(displayedSpots) { spot in
                Annotation(spot.name, coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                    PictriMapSpotMarker(isSelected: selectedSpot?.id == spot.id)
                        .onTapGesture {
                            selectedSpot = spot
                        }
                        .accessibilityLabel("\(spot.name)、おすすめスポット")
                        .accessibilityAddTraits(.isButton)
                }
                .annotationTitles(.hidden)
            }
        }
        // PART 3「NO PROGRESS COLORS ON INTERACTIVE MAP」: Collection色
        // (white/lavender/gold)は一切塗らない。標準mapStyleのまま
        // roads/city/country名が読める状態を維持する。PicTri Spotが
        // 大量のApple POI iconに埋もれないよう`.excludingAll`にする
        // (道路・地名・土地/水域の描画自体はmapTypeに含まれ、消えない)。
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        // Round 3: `MapUserLocationButton()`はSimulator/実機で条件により
        // 全く描画されない(位置情報の認可タイミングに依存し、fresh screenshotで
        // 不在を確認した)ことが判明したため、常に確実に見える自前の
        // `PictriMapLocationButton`(STEP 8)へ置き換えた。Compassは回転時のみ
        // system標準で自動表示されるため、そのまま残す(常設controlの追加ではない)。
        .mapControls {
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
    }

    // MARK: - Top chrome

    /// PART 6「HEADER」: 巨大headerにしない。PicTri wordmark行(Home/Album共有の
    /// `PictriTopBrandHeader`)だけを残す。Round 3で「旅の地図」pillは削除した
    /// (World Explorerとして「次はどこへ行くか」を探す画面になったため、
    /// Collection Summary由来のラベルは意味を持たなくなった。代わりに
    /// この位置は検索窓(`searchBar`)が担う)。
    private var topChrome: some View {
        PictriTopBrandHeader(badgeCount: notificationBadgeCount, onAccountTap: onAccountTap)
    }

    /// STEP 4/5「SEARCH ENTRY / SEARCH UI」。
    private var searchBar: some View {
        PictriMapSearchBar(
            query: $searchQuery,
            isActive: isSearchActive,
            isFocused: $isSearchFocused,
            onClear: {
                searchQuery = ""
                searchCompleter.clear()
            }
        )
        .onChange(of: searchQuery) { _, newValue in
            searchCompleter.updateQuery(newValue, region: visibleRegion)
        }
    }
}

// MARK: - Spot marker

/// PART 4「RECOMMENDED SPOTS」: small / recognizable / PicTri-specific。
/// 巨大pin・neon・gold(Goldはcompletion専用)・大量のglowは使わない。
private struct PictriMapSpotMarker: View {
    /// MARKER STATES: normalとselectedの2状態のみ。selected時は少し拡大+
    /// edge contrast増加+shadow増加程度に留める(pulse animation禁止、
    /// 100〜180ms程度の高速なanimationのみ許可)。
    var isSelected: Bool = false

    private var diameter: CGFloat { isSelected ? 18 : 15 }

    var body: some View {
        ZStack {
            Circle()
                .fill(PictriHomeBrandAccent.accent)
                .frame(width: diameter, height: diameter)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(isSelected ? 0.95 : 0.75), lineWidth: isSelected ? 2 : 1.5)
                }
            Image(systemName: "mappin")
                .font(.system(size: isSelected ? 8 : 7, weight: .bold))
                .foregroundStyle(PictriHomeBrandAccent.onAccent)
        }
        .shadow(color: Color.black.opacity(isSelected ? 0.45 : 0.35), radius: isSelected ? 5 : 3, y: isSelected ? 2 : 1)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Current location button

/// STEP 8「CURRENT LOCATION」: `MapUserLocationButton()`がSimulator/実機で
/// 条件により全く描画されないことをfresh screenshotで確認したため、確実に
/// 見える自前のcircular buttonへ置き換えた(spec「機能として利用してよい。
/// ただし見た目がPicTriから浮く場合は外側containerだけ整える」の範囲内の判断、
/// 詳細はFinal Reportへ記載)。
private struct PictriMapLocationButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PictriHomeBrandAccent.accent)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(PictriDarkTheme.surfaceOverlay.opacity(0.9))
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .accessibilityLabel("現在地へ移動")
    }
}

// MARK: - Spot selection card

/// PART「SPOT SELECTION」: Round 2は小さなcompact bottom cardまで。
/// Route/AI recommendation/hotel/full directionsへは進まない
/// (spot name / prefecture-area / 距離 / Recommended indicatorのみ)。
private struct PictriMapSpotCard: View {
    let spot: QuestSpot
    let distanceText: String?
    /// 「ここ、行ってみたい」と思わせるための代表写真(STEP 7)。既存の
    /// `QuestMemoryStore.image(for:)`が返す実データのみを使い、Spot自体に
    /// 写真assetを新設・捏造しない。未撮影のSpotではnilのまま
    /// (意図されたdark placeholderへfallbackする)。
    let representativeImage: UIImage?
    let onClose: () -> Void
    /// MAP ROUND 4: Card自体(写真+テキスト部分)をtapするとSpot Detailを開く。
    /// 閉じるボタンだけは独立したtap領域のまま維持する(誤ってDetailが開かず
    /// 閉じられるように)。
    let onOpenDetail: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpenDetail) {
                HStack(alignment: .top, spacing: 12) {
                    photoThumbnail

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PictriHomeBrandAccent.accent)
                            Text("おすすめスポット")
                                .font(PictriTypography.body(10.5, weight: .bold))
                                .foregroundStyle(PictriHomeBrandAccent.accent)
                        }

                        Text(spot.name)
                            .font(PictriTypography.display(17))
                            .foregroundStyle(PictriFinalTheme.ink)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(spot.areaName)
                                .font(PictriTypography.body(12, weight: .semibold))
                                .foregroundStyle(PictriDarkTheme.textFaint)
                            if let distanceText {
                                Text("・\(distanceText)")
                                    .font(PictriTypography.body(12, weight: .semibold))
                                    .foregroundStyle(PictriDarkTheme.textFaint)
                                    .monospacedDigit()
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(spot.name)の詳細を見る")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(spot.name)、\(spot.areaName)、おすすめスポット\(distanceText.map { "、\($0)" } ?? "")")
    }

    /// STEP 7「SPOT CARD DESIGN」: Photoがある場合はPhotoを一番強くする、
    /// 無い場合は意図されたdark placeholder(Round 6のHome Card placeholderと
    /// 同じ処方: 2色gradient + 中心寄りの控えめなsheen、単なる真っ黒にしない)。
    @ViewBuilder
    private var photoThumbnail: some View {
        ZStack {
            if let representativeImage {
                Image(uiImage: representativeImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [PictriHomeCardTheme.placeholderTop, PictriHomeCardTheme.placeholderBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.06), Color.clear],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: 2,
                    endRadius: 40
                )
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
    }
}

// MARK: - Initial camera

enum PictriWorldMapCamera {
    /// PART「INITIAL CAMERA」: 現在地が取得できればuser location周辺、
    /// 取得不能なら日本全体を見渡せるfallback。`.userLocation(fallback:)`は
    /// 権限が無い/取得できない間はfallbackのまま表示され、取得できた時点で
    /// 自動的にuser location付近へ遷移する標準MapKit挙動を利用する
    /// (独自のpermission分岐ロジックを重複実装しない)。
    static func initial() -> MapCameraPosition {
        #if DEBUG
        // `-pictriWorldMapDebugRegion`はQA screenshot専用。`.userLocation(fallback:)`は
        // tracking modeを持ち、生成後に`cameraPosition = .region(...)`で上書きしても
        // 直後の位置情報更新でuser locationへ引き戻される実機/Simulator挙動を確認した
        // (`onAppear`側での事後上書きは信頼できない)。そのため、指定がある場合は
        // 初期値そのものを`.region(...)`にすることで、tracking modeへ一切入らない
        // ようにする。指定が無い場合はProduction経路(現在地優先/日本全体fallback)の
        // まま、このフラグは一切影響しない。
        if let key = PictriVisualReview.worldMapDebugRegionKey,
           let region = debugRegion(for: key) {
            return .region(region)
        }
        #endif
        return .userLocation(fallback: .region(japanFallbackRegion))
    }

    static let japanFallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2, longitude: 138.25),
        span: MKCoordinateSpan(latitudeDelta: 16, longitudeDelta: 16)
    )

    #if DEBUG
    /// QA screenshot専用のcamera region preset(`-pictriWorldMapDebugRegion`)。
    /// Production経路には一切関与しない。
    static func debugRegion(for key: String) -> MKCoordinateRegion? {
        switch key {
        case "japan":
            return japanFallbackRegion
        case "korea":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.8),
                span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
            )
        case "asia":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 30.0, longitude: 115.0),
                span: MKCoordinateSpan(latitudeDelta: 55, longitudeDelta: 55)
            )
        case "world":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.0, longitude: 20.0),
                span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 140)
            )
        case "tokyo":
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
            )
        default:
            return nil
        }
    }
    #endif
}
