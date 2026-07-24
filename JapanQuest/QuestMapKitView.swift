import SwiftUI
import MapKit

/// カテゴリチップ(エリア探索の絞り込み)とMapKitピンの色を一致させるための共有マッピング。
/// 自然=mint、フォトジェニック=lavender、名所=amber、カフェ=coralで統一する。
enum QuestSpotCategoryColor {
    static func tone(for category: QuestSpotCategory) -> Color {
        switch category {
        case .nature: return PictriLightTheme.mint
        case .photogenic: return PictriLightTheme.lavender
        case .landmark: return PictriLightTheme.amber
        case .cafe: return PictriLightTheme.coral
        }
    }
}

enum QuestMapZoomLevel: String, Equatable {
    case prefecture
    case majorSpots
    case allSpots

    var label: String {
        switch self {
        case .prefecture:
            return "都道府県"
        case .majorSpots, .allSpots:
            return "スポット"
        }
    }

    static func level(
        for latitudeDelta: CLLocationDegrees,
        hasEnteredSpotMode: Bool
    ) -> QuestMapZoomLevel {
        // 一度スポット表示に入ったら、少しズームアウトしただけでは県ピンに戻さない
        if hasEnteredSpotMode {
            if latitudeDelta > 1.75 {
                return .prefecture
            } else {
                return .allSpots
            }
        }

        // 初期状態では、少し拡大したら県内スポットを全部出す
        if latitudeDelta > 0.95 {
            return .prefecture
        } else {
            return .allSpots
        }
    }
}

struct QuestMapKitView: UIViewRepresentable {
    let prefecture: QuestPrefecture
    let spots: [QuestSpot]
    let completedSpotIds: Set<String>
    /// DEBUG検証用(`-pictriMapSelectedSpot`)に、タップなしで特定ピンを強調表示するための
    /// 選択中spotId。通常操作では常にnil(ピンタップは即SpotDetailへ遷移するため)。
    let selectedSpotId: String?
    @Binding var zoomLevel: QuestMapZoomLevel

    let onSpotSelected: (QuestSpot) -> Void

    /// 神奈川固定ではなく、渡されたspotsの重心を初期中心にする。
    /// spotsが空の場合(理論上は呼ばれない: hasRealSpotDataでガードされている)は
    /// 日本のおおよその中心にフォールバックする。
    private var initialCenter: CLLocationCoordinate2D {
        guard !spots.isEmpty else {
            return CLLocationCoordinate2D(latitude: 36.2, longitude: 138.25)
        }
        let latitude = spots.map(\.latitude).reduce(0, +) / Double(spots.count)
        let longitude = spots.map(\.longitude).reduce(0, +) / Double(spots.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.showsBuildings = false
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false
        // ピンチでの拡大・縮小、指1本でのパンをどちらも許可する
        // (このMapは画面の主役として全面表示されるため、外側のScrollViewと競合しない)。
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.overrideUserInterfaceStyle = .light

        let initialRegion = MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(
                latitudeDelta: 1.05,
                longitudeDelta: 1.05
            )
        )

        mapView.setRegion(initialRegion, animated: false)

        context.coordinator.parent = self
        context.coordinator.renderAnnotations(
            on: mapView,
            level: zoomLevel,
            force: true
        )
        // DEBUG検証用に`zoomLevel`がprefecture以外から始まる場合(-pictriMapAreaLevel)、
        // ピンチズームを経由していないので、実際にズームした時と同じ状態
        // (hasEnteredSpotMode=true・region fit済み)を直接作る。
        context.coordinator.applyInitialZoomLevelIfNeeded(on: mapView, level: zoomLevel)

        return mapView
    }

    func updateUIView(
        _ mapView: MKMapView,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.refreshCompletedStateIfNeeded(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: QuestMapKitView

        private var renderedZoomLevel: QuestMapZoomLevel?
        private var renderedCompletedSpotIds: Set<String> = []
        private var hasEnteredSpotMode = false
        private var hasFittedAllSpots = false
        private var isProgrammaticFit = false

        init(parent: QuestMapKitView) {
            self.parent = parent
        }

        func mapView(
            _ mapView: MKMapView,
            regionDidChangeAnimated animated: Bool
        ) {
            guard !isProgrammaticFit else {
                return
            }

            let newLevel = QuestMapZoomLevel.level(
                for: mapView.region.span.latitudeDelta,
                hasEnteredSpotMode: hasEnteredSpotMode
            )

            if newLevel == .allSpots {
                hasEnteredSpotMode = true
            }

            DispatchQueue.main.async {
                if self.parent.zoomLevel != newLevel {
                    self.parent.zoomLevel = newLevel
                }
            }

            renderAnnotations(
                on: mapView,
                level: newLevel,
                force: false
            )

            if newLevel == .allSpots, !hasFittedAllSpots {
                fitAllSpotsOnce(on: mapView)
            }
        }

        func mapView(
            _ mapView: MKMapView,
            didSelect view: MKAnnotationView
        ) {
            if let clusterAnnotation = view.annotation as? MKClusterAnnotation {
                var rect = MKMapRect.null

                for member in clusterAnnotation.memberAnnotations {
                    let point = MKMapPoint(member.coordinate)
                    rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
                }

                // クラスタの中身が2件だけ・近接している場合、rectがほぼ点になり
                // 極端に寄りすぎたズームになってしまう。周辺の街並みが見える最低限まで広げる。
                let clusterCenter = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
                let minSpan = 1400 * MKMapPointsPerMeterAtLatitude(clusterCenter.latitude)
                if rect.width < minSpan {
                    rect = rect.insetBy(dx: -(minSpan - rect.width) / 2, dy: 0)
                }
                if rect.height < minSpan {
                    rect = rect.insetBy(dx: 0, dy: -(minSpan - rect.height) / 2)
                }

                isProgrammaticFit = true
                mapView.setVisibleMapRect(
                    rect,
                    edgePadding: UIEdgeInsets(top: 88, left: 54, bottom: 128, right: 54),
                    animated: true
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    self.isProgrammaticFit = false
                }

                mapView.deselectAnnotation(clusterAnnotation, animated: true)
                return
            }

            if let prefectureAnnotation = view.annotation as? QuestPrefectureAnnotation {
                hasEnteredSpotMode = true
                hasFittedAllSpots = false

                DispatchQueue.main.async {
                    self.parent.zoomLevel = .allSpots
                }

                renderAnnotations(
                    on: mapView,
                    level: .allSpots,
                    force: true
                )

                fitAllSpotsOnce(on: mapView)

                mapView.deselectAnnotation(
                    prefectureAnnotation,
                    animated: true
                )
                return
            }

            if let spotAnnotation = view.annotation as? QuestSpotAnnotation {
                parent.onSpotSelected(spotAnnotation.spot)

                mapView.deselectAnnotation(
                    spotAnnotation,
                    animated: true
                )
            }
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            if let clusterAnnotation = annotation as? MKClusterAnnotation {
                let identifier = "QuestAreaExploreCluster"

                let markerView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )

                markerView.annotation = annotation
                markerView.canShowCallout = false
                markerView.animatesWhenAdded = true
                markerView.displayPriority = .required
                markerView.transform = .identity
                markerView.layer.shadowOpacity = 0

                // クラスタの中身が全て訪問済みならwhite+checkmark、それ以外は
                // 個別ピンと同じカテゴリ色(混在時はグレー)で「まだ何か残っている」ことを伝える。
                let memberSpots = clusterAnnotation.memberAnnotations.compactMap { $0 as? QuestSpotAnnotation }
                let allCompleted = !memberSpots.isEmpty && memberSpots.allSatisfy { $0.isCompleted }

                if allCompleted {
                    markerView.markerTintColor = .white
                    markerView.glyphTintColor = UIColor(PictriLightTheme.textSecondary)
                } else if let category = memberSpots.first(where: { !$0.isCompleted })?.spot.category {
                    markerView.markerTintColor = UIColor(QuestSpotCategoryColor.tone(for: category))
                    markerView.glyphTintColor = .white
                } else {
                    markerView.markerTintColor = UIColor(PictriLightTheme.textSecondary)
                    markerView.glyphTintColor = .white
                }

                markerView.glyphText = "\(clusterAnnotation.memberAnnotations.count)"

                return markerView
            }

            if let spotAnnotation = annotation as? QuestSpotAnnotation {
                let identifier = "QuestSpotAnnotation"

                let markerView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )

                markerView.annotation = annotation
                markerView.canShowCallout = true
                markerView.animatesWhenAdded = true

                // 訪問済みは白+グレーcheckmarkで統一。未訪問はカテゴリチップと同じ配色
                // (自然=mint、フォトジェニック=lavender、名所=amber、カフェ=coral)にする。
                if spotAnnotation.isCompleted {
                    markerView.markerTintColor = .white
                    markerView.glyphTintColor = UIColor(PictriLightTheme.textSecondary)
                    markerView.glyphImage = UIImage(systemName: "checkmark")
                } else {
                    let tone = QuestSpotCategoryColor.tone(for: spotAnnotation.spot.category)
                    markerView.markerTintColor = UIColor(tone)
                    markerView.glyphTintColor = .white
                    markerView.glyphImage = UIImage(systemName: spotAnnotation.spot.category.systemImage)
                }

                markerView.titleVisibility = .adaptive
                markerView.subtitleVisibility = .hidden

                // 密集ピン対策としてクラスタリングを有効化する。ただしDEBUG検証中の
                // 選択中ピン(-pictriMapSelectedSpot)だけはクラスタに吸収されると
                // 見失ってしまうため、常に個別表示させる(clusteringIdentifier=nil)。
                let isSelected = spotAnnotation.spot.id == parent.selectedSpotId
                if isSelected {
                    markerView.clusteringIdentifier = nil
                    markerView.zPriority = .max
                    markerView.displayPriority = .required
                    markerView.transform = CGAffineTransform(scaleX: 1.28, y: 1.28)
                    markerView.layer.shadowColor = UIColor.white.cgColor
                    markerView.layer.shadowRadius = 6
                    markerView.layer.shadowOpacity = 0.9
                    markerView.layer.shadowOffset = .zero
                } else {
                    markerView.clusteringIdentifier = spotAnnotation.isCompleted
                        ? "questAreaCompleted"
                        : "questAreaCategory_\(spotAnnotation.spot.category.rawValue)"
                    markerView.zPriority = .defaultUnselected
                    markerView.transform = .identity
                    markerView.layer.shadowOpacity = 0
                }

                return markerView
            }

            if annotation is QuestPrefectureAnnotation {
                let identifier = "QuestPrefectureAnnotation"

                let markerView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )

                markerView.annotation = annotation
                markerView.canShowCallout = true
                markerView.animatesWhenAdded = true
                markerView.markerTintColor = UIColor(PictriLightTheme.accent)
                markerView.glyphTintColor = .white
                markerView.glyphImage = UIImage(systemName: "flag.fill")
                markerView.titleVisibility = .visible
                markerView.subtitleVisibility = .visible

                return markerView
            }

            return nil
        }

        /// DEBUG検証用: 初期zoomLevelがprefecture以外の場合、実際にズームした時と
        /// 同じ状態(hasEnteredSpotMode=true・全スポットをfitした region)を直接作る。
        func applyInitialZoomLevelIfNeeded(on mapView: MKMapView, level: QuestMapZoomLevel) {
            guard level != .prefecture else { return }
            hasEnteredSpotMode = true
            fitAllSpotsOnce(on: mapView)
        }

        func refreshCompletedStateIfNeeded(on mapView: MKMapView) {
            guard renderedCompletedSpotIds != parent.completedSpotIds else {
                return
            }

            let currentLevel = renderedZoomLevel ?? .prefecture

            renderAnnotations(
                on: mapView,
                level: currentLevel,
                force: true
            )
        }

        func renderAnnotations(
            on mapView: MKMapView,
            level: QuestMapZoomLevel,
            force: Bool
        ) {
            let completedChanged = renderedCompletedSpotIds != parent.completedSpotIds
            let zoomChanged = renderedZoomLevel != level

            guard force || completedChanged || zoomChanged else {
                return
            }

            renderedZoomLevel = level
            renderedCompletedSpotIds = parent.completedSpotIds

            let oldAnnotations = mapView.annotations.filter {
                !($0 is MKUserLocation)
            }

            mapView.removeAnnotations(oldAnnotations)

            let newAnnotations = annotations(for: level)
            mapView.addAnnotations(newAnnotations)
        }

        private func annotations(for level: QuestMapZoomLevel) -> [MKAnnotation] {
            switch level {
            case .prefecture:
                return [
                    QuestPrefectureAnnotation(
                        title: parent.prefecture.name,
                        subtitle: "\(parent.completedSpotIds.count) / \(parent.prefecture.totalSpotCount) spots",
                        coordinate: parent.initialCenter
                    )
                ]

            case .majorSpots, .allSpots:
                return parent.spots.map { spot in
                    QuestSpotAnnotation(
                        spot: spot,
                        isCompleted: parent.completedSpotIds.contains(spot.id)
                    )
                }
            }
        }

        private func fitAllSpotsOnce(on mapView: MKMapView) {
            guard !hasFittedAllSpots else {
                return
            }

            guard !parent.spots.isEmpty else {
                return
            }

            hasFittedAllSpots = true
            isProgrammaticFit = true

            var rect = MKMapRect.null

            for spot in parent.spots {
                let coordinate = CLLocationCoordinate2D(
                    latitude: spot.latitude,
                    longitude: spot.longitude
                )

                let point = MKMapPoint(coordinate)

                let pointRect = MKMapRect(
                    x: point.x,
                    y: point.y,
                    width: 1,
                    height: 1
                )

                rect = rect.union(pointRect)
            }

            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(
                    top: 88,
                    left: 54,
                    bottom: 128,
                    right: 54
                ),
                animated: true
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.isProgrammaticFit = false
            }
        }
    }
}

final class QuestSpotAnnotation: NSObject, MKAnnotation {
    let spot: QuestSpot
    let isCompleted: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: spot.latitude,
            longitude: spot.longitude
        )
    }

    var title: String? {
        spot.name
    }

    var subtitle: String? {
        spot.areaName
    }

    init(
        spot: QuestSpot,
        isCompleted: Bool
    ) {
        self.spot = spot
        self.isCompleted = isCompleted
    }
}

final class QuestPrefectureAnnotation: NSObject, MKAnnotation {
    let titleText: String
    let subtitleText: String
    let coordinateValue: CLLocationCoordinate2D

    var coordinate: CLLocationCoordinate2D {
        coordinateValue
    }

    var title: String? {
        titleText
    }

    var subtitle: String? {
        subtitleText
    }

    init(
        title: String,
        subtitle: String,
        coordinate: CLLocationCoordinate2D
    ) {
        self.titleText = title
        self.subtitleText = subtitle
        self.coordinateValue = coordinate
    }
}

// MARK: - Prefecture Overview Map (県詳細カード用)

/// 都道府県詳細カードで使う、実在のMapKit地図に基づいた軽量プレビュー。
/// 以前はQuestMapGeoData(簡略化した自作ポリゴン)を拡大表示していたが、
/// 県単位まで拡大すると簡略化の粗さが目立ち「地図として信用できない」という
/// 指摘を受けたため、実スポット座標が収まるregionを持つ本物の地図に置き換えた。
/// エリア探索(QuestMapKitView)と違い、ズームレベル切り替えは持たない固定表示で、
/// ScrollView内に置かれるためpan/pinchジェスチャーを無効化し、外側のスクロールと
/// 競合しないreadonly風のカードにしている(タップでのピン選択は引き続き機能する)。
/// ピンが密集した場合はMapKit標準のクラスタリングでまとめ、訪問済み/カテゴリの
/// 意味が混ざらないよう完了状態・カテゴリごとに別クラスタとして扱う。
/// 神奈川専用の判定は持たず、渡されたspotsが1件でもあれば東京・京都・北海道等
/// どの県でもそのまま使える(呼び出し側でspotデータの有無を判定して切り替える)。
struct QuestPrefectureOverviewMapView: UIViewRepresentable {
    let spots: [QuestSpot]
    let completedSpotIds: Set<String>
    let onSpotSelected: (QuestSpot) -> Void
    /// ピンが密集してクラスタ化された時のタップ用。このカードはpan/pinchができない固定表示のため、
    /// クラスタをその場でズームしても抜け出せない。代わりにエリア探索(拡大縮小できる本物の地図)へ誘導する。
    let onClusterSelected: () -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.showsBuildings = false
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        // 縦のScrollView内に置かれる固定プレビューのため、指1本のパンは無効のまま
        // (外側のスクロールと競合する)。ピンチ(2本指)のズームだけは独立したジェスチャーなので
        // 有効化しても外側のスクロールを妨げない。
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = true
        mapView.overrideUserInterfaceStyle = .light

        mapView.addAnnotations(annotations())
        fitRegion(on: mapView, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        guard context.coordinator.renderedCompletedSpotIds != completedSpotIds else {
            return
        }
        context.coordinator.renderedCompletedSpotIds = completedSpotIds

        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.addAnnotations(annotations())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func annotations() -> [QuestSpotAnnotation] {
        spots.map { spot in
            QuestSpotAnnotation(spot: spot, isCompleted: completedSpotIds.contains(spot.id))
        }
    }

    private func fitRegion(on mapView: MKMapView, animated: Bool) {
        guard !spots.isEmpty else {
            return
        }

        var rect = MKMapRect.null

        for spot in spots {
            let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }

        // スポットが1件だけ、または互いに近接している場合はrectがほぼ点になり、
        // 極端に寄りすぎた(周辺の地形が全く見えない)regionになってしまう。
        // 最低でも周辺の街並みが分かる距離まで広げる安全弁。
        let centerCoordinate = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
        let minSpan = 1400 * MKMapPointsPerMeterAtLatitude(centerCoordinate.latitude)
        if rect.width < minSpan {
            rect = rect.insetBy(dx: -(minSpan - rect.width) / 2, dy: 0)
        }
        if rect.height < minSpan {
            rect = rect.insetBy(dx: 0, dy: -(minSpan - rect.height) / 2)
        }

        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 40, left: 32, bottom: 40, right: 32),
            animated: animated
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: QuestPrefectureOverviewMapView
        var renderedCompletedSpotIds: Set<String>

        init(parent: QuestPrefectureOverviewMapView) {
            self.parent = parent
            self.renderedCompletedSpotIds = parent.completedSpotIds
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let clusterAnnotation = annotation as? MKClusterAnnotation {
                let identifier = "QuestPrefectureOverviewCluster"

                let markerView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )

                markerView.annotation = annotation
                markerView.canShowCallout = false
                markerView.animatesWhenAdded = true
                markerView.displayPriority = .required

                // クラスタの中身が全て訪問済みならwhite+checkmark、それ以外は
                // 個別ピンと同じカテゴリ色(混在時はグレー)で「まだ何か残っている」ことを伝える。
                let memberSpots = clusterAnnotation.memberAnnotations.compactMap { $0 as? QuestSpotAnnotation }
                let allCompleted = !memberSpots.isEmpty && memberSpots.allSatisfy { $0.isCompleted }

                if allCompleted {
                    markerView.markerTintColor = .white
                    markerView.glyphTintColor = UIColor(PictriLightTheme.textSecondary)
                } else if let category = memberSpots.first(where: { !$0.isCompleted })?.spot.category {
                    markerView.markerTintColor = UIColor(QuestSpotCategoryColor.tone(for: category))
                    markerView.glyphTintColor = .white
                } else {
                    markerView.markerTintColor = UIColor(PictriLightTheme.textSecondary)
                    markerView.glyphTintColor = .white
                }

                markerView.glyphText = "\(clusterAnnotation.memberAnnotations.count)"

                return markerView
            }

            guard let spotAnnotation = annotation as? QuestSpotAnnotation else {
                return nil
            }

            let identifier = "QuestPrefectureOverviewSpotAnnotation"

            let markerView = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                annotation: annotation,
                reuseIdentifier: identifier
            )

            markerView.annotation = annotation
            markerView.canShowCallout = true
            markerView.animatesWhenAdded = true

            if spotAnnotation.isCompleted {
                markerView.markerTintColor = .white
                markerView.glyphTintColor = UIColor(PictriLightTheme.textSecondary)
                markerView.glyphImage = UIImage(systemName: "checkmark")
                markerView.clusteringIdentifier = "questOverviewCompleted"
            } else {
                let tone = QuestSpotCategoryColor.tone(for: spotAnnotation.spot.category)
                markerView.markerTintColor = UIColor(tone)
                markerView.glyphTintColor = .white
                markerView.glyphImage = UIImage(systemName: spotAnnotation.spot.category.systemImage)
                markerView.clusteringIdentifier = "questOverviewCategory_\(spotAnnotation.spot.category.rawValue)"
            }

            markerView.titleVisibility = .adaptive
            markerView.subtitleVisibility = .hidden

            return markerView
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if view.annotation is MKClusterAnnotation {
                parent.onClusterSelected()
                mapView.deselectAnnotation(view.annotation, animated: true)
                return
            }

            guard let spotAnnotation = view.annotation as? QuestSpotAnnotation else {
                return
            }

            parent.onSpotSelected(spotAnnotation.spot)
            mapView.deselectAnnotation(spotAnnotation, animated: true)
        }
    }
}

// MARK: - Japan Overview Map (日本全体Map)

/// 都道府県ごとの「だいたいの県庁所在地」に基づいた、実在のMapKit地図。
/// 以前はQuestMapGeoData(簡略化した自作ポリゴン)で日本全体を塗り絵表示していたが、
/// 拡大して見ると形の粗さが「地図として信用できない」という指摘を受けたため、
/// 実座標のMapKit上に都道府県バッジを重ねる表現へ置き換えた。バッジの位置はあくまで
/// 「その県のだいたいの場所」を示す目安であり、行政境界を正確に表すものではない
/// (県境そのものは描画しない)。訪問済みはteal/mint/lavenderのバッジ+チェックマーク、
/// 未訪問は控えめなグレーの小さいバッジで表す。QuestMapGeoData.swiftの簡略ポリゴンは
/// 削除せず、スポットデータがまだ無い県の準備中カード(QuestPrefectureSubMapView)専用として
/// 引き続き使う。
struct QuestJapanOverviewMapView: UIViewRepresentable {
    let visitedPrefectureIds: Set<String>
    let onSelect: (QuestPrefecture) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.showsBuildings = false
        mapView.showsUserLocation = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        // ピンチでの拡大・縮小、指1本でのパンをどちらも許可する。
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.overrideUserInterfaceStyle = .light

        mapView.addAnnotations(annotations())
        fitMainlandRegion(on: mapView, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        guard context.coordinator.renderedVisitedIds != visitedPrefectureIds else {
            return
        }
        context.coordinator.renderedVisitedIds = visitedPrefectureIds

        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.addAnnotations(annotations())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func annotations() -> [QuestPrefectureOverviewAnnotation] {
        QuestPrefectureGeoCenters.all.map { entry in
            QuestPrefectureOverviewAnnotation(
                prefectureId: entry.id,
                name: entry.name,
                coordinate: entry.coordinate,
                isVisited: visitedPrefectureIds.contains(entry.id)
            )
        }
    }

    /// 沖縄は本州から大きく離れているため、初期表示は北海道〜九州が収まる範囲に合わせる
    /// (実際の地図アプリで日本全体を見た時と同じ振る舞い)。沖縄はピンチアウト/スクロールで見える。
    private func fitMainlandRegion(on mapView: MKMapView, animated: Bool) {
        var rect = MKMapRect.null

        for entry in QuestPrefectureGeoCenters.all where entry.id != "okinawa" {
            let point = MKMapPoint(entry.coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }

        guard !rect.isNull else { return }

        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 36, left: 28, bottom: 36, right: 28),
            animated: animated
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: QuestJapanOverviewMapView
        var renderedVisitedIds: Set<String>

        /// 未訪問バッジ用の、控えめなslate gray(訪問済みのteal/mint/lavenderと明確に区別する)。
        private static let unvisitedBadgeColor = UIColor(red: 0.62, green: 0.65, blue: 0.70, alpha: 1)

        init(parent: QuestJapanOverviewMapView) {
            self.parent = parent
            self.renderedVisitedIds = parent.visitedPrefectureIds
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let clusterAnnotation = annotation as? MKClusterAnnotation {
                let identifier = "QuestPrefectureOverviewClusterBadge"

                let markerView = mapView.dequeueReusableAnnotationView(
                    withIdentifier: identifier
                ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )

                markerView.annotation = annotation
                markerView.canShowCallout = false
                markerView.animatesWhenAdded = true
                markerView.displayPriority = .required
                markerView.transform = .identity
                markerView.glyphImage = nil
                markerView.glyphText = "\(clusterAnnotation.memberAnnotations.count)"
                markerView.glyphTintColor = .white

                // 全員訪問済みならteal、1人でも訪問済みがいれば「ここに進捗がある」ことを
                // 伝えるmint、全員未訪問ならslate grayで統一する(単体バッジと同じ3配色)。
                let members = clusterAnnotation.memberAnnotations.compactMap { $0 as? QuestPrefectureOverviewAnnotation }
                let allVisited = !members.isEmpty && members.allSatisfy { $0.isVisited }
                let anyVisited = members.contains { $0.isVisited }

                if allVisited {
                    markerView.markerTintColor = UIColor(PictriLightTheme.teal)
                } else if anyVisited {
                    markerView.markerTintColor = UIColor(PictriLightTheme.mint)
                } else {
                    markerView.markerTintColor = Self.unvisitedBadgeColor
                }

                return markerView
            }

            guard let prefAnnotation = annotation as? QuestPrefectureOverviewAnnotation else {
                return nil
            }

            let identifier = "QuestPrefectureOverviewBadge"

            let markerView = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
                annotation: annotation,
                reuseIdentifier: identifier
            )

            markerView.annotation = annotation
            markerView.canShowCallout = true
            markerView.animatesWhenAdded = true
            markerView.titleVisibility = .adaptive
            markerView.subtitleVisibility = .hidden
            markerView.clusteringIdentifier = "questJapanOverviewBadge"

            if prefAnnotation.isVisited {
                markerView.markerTintColor = UIColor(PictriLightTheme.visitedPrefectureColor(id: prefAnnotation.prefectureId))
                markerView.glyphTintColor = .white
                markerView.glyphImage = UIImage(systemName: "checkmark")
                markerView.displayPriority = .required
                markerView.transform = .identity
            } else {
                markerView.markerTintColor = Self.unvisitedBadgeColor
                markerView.glyphTintColor = .white
                markerView.glyphImage = nil
                markerView.displayPriority = .defaultLow
                markerView.transform = CGAffineTransform(scaleX: 0.72, y: 0.72)
            }

            return markerView
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                zoomIntoCluster(cluster, on: mapView)
                return
            }

            guard let prefAnnotation = view.annotation as? QuestPrefectureOverviewAnnotation else {
                return
            }

            selectPrefecture(id: prefAnnotation.prefectureId)
            mapView.deselectAnnotation(prefAnnotation, animated: true)
        }

        /// クラスタタップでは(スポットの県内クラスタと違い)特定の県へいきなり遷移せず、
        /// まずズームインして個々の県バッジへ分離させる(隣接県を間違って選んでしまうのを防ぐ)。
        private func zoomIntoCluster(_ cluster: MKClusterAnnotation, on mapView: MKMapView) {
            var rect = MKMapRect.null

            for member in cluster.memberAnnotations {
                let point = MKMapPoint(member.coordinate)
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
            }

            let clusterCenter = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
            let minSpan = 120_000 * MKMapPointsPerMeterAtLatitude(clusterCenter.latitude)
            if rect.width < minSpan {
                rect = rect.insetBy(dx: -(minSpan - rect.width) / 2, dy: 0)
            }
            if rect.height < minSpan {
                rect = rect.insetBy(dx: 0, dy: -(minSpan - rect.height) / 2)
            }

            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 40, left: 32, bottom: 40, right: 32),
                animated: true
            )
            mapView.deselectAnnotation(cluster, animated: true)
        }

        private func selectPrefecture(id: String) {
            let prefecture = mockQuestPrefectures.first(where: { $0.id == id })
                ?? questPrefectureShapes.first(where: { $0.id == id }).map {
                    QuestPrefecture(id: $0.id, name: $0.name, englishName: $0.id, totalSpotCount: 0)
                }

            guard let prefecture else { return }
            parent.onSelect(prefecture)
        }
    }
}

final class QuestPrefectureOverviewAnnotation: NSObject, MKAnnotation {
    let prefectureId: String
    let nameText: String
    let coordinate: CLLocationCoordinate2D
    let isVisited: Bool

    var title: String? { nameText }
    var subtitle: String? { nil }

    init(prefectureId: String, name: String, coordinate: CLLocationCoordinate2D, isVisited: Bool) {
        self.prefectureId = prefectureId
        self.nameText = name
        self.coordinate = coordinate
        self.isVisited = isVisited
    }
}

// MARK: - Prefecture Geo Centers (実座標)

/// 47都道府県の「だいたいの県庁所在地」に基づく実世界の緯度経度。QuestMapGeoData.swiftの
/// 簡略ポリゴン(共有キャンバス座標・行政境界の簡易近似)とは別物で、こちらは日本全体Map
/// (MapKitベース)のバッジ配置専用。行政境界の正確な表現ではなく、あくまで
/// 「その県のだいたいの位置」を示す目安値。
enum QuestPrefectureGeoCenters {
    struct Entry {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    static let all: [Entry] = [
        Entry(id: "hokkaido", name: "北海道", coordinate: .init(latitude: 43.0642, longitude: 141.3469)),
        Entry(id: "aomori", name: "青森", coordinate: .init(latitude: 40.8244, longitude: 140.7400)),
        Entry(id: "iwate", name: "岩手", coordinate: .init(latitude: 39.7036, longitude: 141.1527)),
        Entry(id: "miyagi", name: "宮城", coordinate: .init(latitude: 38.2682, longitude: 140.8694)),
        Entry(id: "akita", name: "秋田", coordinate: .init(latitude: 39.7186, longitude: 140.1024)),
        Entry(id: "yamagata", name: "山形", coordinate: .init(latitude: 38.2404, longitude: 140.3633)),
        Entry(id: "fukushima", name: "福島", coordinate: .init(latitude: 37.7500, longitude: 140.4677)),
        Entry(id: "ibaraki", name: "茨城", coordinate: .init(latitude: 36.3418, longitude: 140.4468)),
        Entry(id: "tochigi", name: "栃木", coordinate: .init(latitude: 36.5658, longitude: 139.8836)),
        Entry(id: "gunma", name: "群馬", coordinate: .init(latitude: 36.3906, longitude: 139.0608)),
        Entry(id: "saitama", name: "埼玉", coordinate: .init(latitude: 35.8617, longitude: 139.6455)),
        Entry(id: "chiba", name: "千葉", coordinate: .init(latitude: 35.6074, longitude: 140.1065)),
        Entry(id: "tokyo", name: "東京", coordinate: .init(latitude: 35.6762, longitude: 139.6503)),
        Entry(id: "kanagawa", name: "神奈川", coordinate: .init(latitude: 35.4437, longitude: 139.6380)),
        Entry(id: "niigata", name: "新潟", coordinate: .init(latitude: 37.9026, longitude: 139.0232)),
        Entry(id: "toyama", name: "富山", coordinate: .init(latitude: 36.6953, longitude: 137.2113)),
        Entry(id: "ishikawa", name: "石川", coordinate: .init(latitude: 36.5613, longitude: 136.6562)),
        Entry(id: "fukui", name: "福井", coordinate: .init(latitude: 36.0652, longitude: 136.2216)),
        Entry(id: "yamanashi", name: "山梨", coordinate: .init(latitude: 35.6642, longitude: 138.5686)),
        Entry(id: "nagano", name: "長野", coordinate: .init(latitude: 36.6513, longitude: 138.1810)),
        Entry(id: "gifu", name: "岐阜", coordinate: .init(latitude: 35.3912, longitude: 136.7223)),
        Entry(id: "shizuoka", name: "静岡", coordinate: .init(latitude: 34.9769, longitude: 138.3831)),
        Entry(id: "aichi", name: "愛知", coordinate: .init(latitude: 35.1815, longitude: 136.9066)),
        Entry(id: "mie", name: "三重", coordinate: .init(latitude: 34.7303, longitude: 136.5086)),
        Entry(id: "shiga", name: "滋賀", coordinate: .init(latitude: 35.0045, longitude: 135.8686)),
        Entry(id: "kyoto", name: "京都", coordinate: .init(latitude: 35.0116, longitude: 135.7681)),
        Entry(id: "osaka", name: "大阪", coordinate: .init(latitude: 34.6937, longitude: 135.5023)),
        Entry(id: "hyogo", name: "兵庫", coordinate: .init(latitude: 34.6901, longitude: 135.1955)),
        Entry(id: "nara", name: "奈良", coordinate: .init(latitude: 34.6851, longitude: 135.8048)),
        Entry(id: "wakayama", name: "和歌山", coordinate: .init(latitude: 34.2260, longitude: 135.1675)),
        Entry(id: "tottori", name: "鳥取", coordinate: .init(latitude: 35.5039, longitude: 134.2381)),
        Entry(id: "shimane", name: "島根", coordinate: .init(latitude: 35.4723, longitude: 133.0505)),
        Entry(id: "okayama", name: "岡山", coordinate: .init(latitude: 34.6551, longitude: 133.9195)),
        Entry(id: "hiroshima", name: "広島", coordinate: .init(latitude: 34.3853, longitude: 132.4553)),
        Entry(id: "yamaguchi", name: "山口", coordinate: .init(latitude: 34.1859, longitude: 131.4714)),
        Entry(id: "tokushima", name: "徳島", coordinate: .init(latitude: 34.0658, longitude: 134.5593)),
        Entry(id: "kagawa", name: "香川", coordinate: .init(latitude: 34.3401, longitude: 134.0434)),
        Entry(id: "ehime", name: "愛媛", coordinate: .init(latitude: 33.8416, longitude: 132.7657)),
        Entry(id: "kochi", name: "高知", coordinate: .init(latitude: 33.5597, longitude: 133.5311)),
        Entry(id: "fukuoka", name: "福岡", coordinate: .init(latitude: 33.5904, longitude: 130.4017)),
        Entry(id: "saga", name: "佐賀", coordinate: .init(latitude: 33.2494, longitude: 130.2989)),
        Entry(id: "nagasaki", name: "長崎", coordinate: .init(latitude: 32.7448, longitude: 129.8737)),
        Entry(id: "kumamoto", name: "熊本", coordinate: .init(latitude: 32.7898, longitude: 130.7417)),
        Entry(id: "oita", name: "大分", coordinate: .init(latitude: 33.2382, longitude: 131.6126)),
        Entry(id: "miyazaki", name: "宮崎", coordinate: .init(latitude: 31.9111, longitude: 131.4239)),
        Entry(id: "kagoshima", name: "鹿児島", coordinate: .init(latitude: 31.5602, longitude: 130.5581)),
        Entry(id: "okinawa", name: "沖縄", coordinate: .init(latitude: 26.2124, longitude: 127.6809)),
    ]
}
