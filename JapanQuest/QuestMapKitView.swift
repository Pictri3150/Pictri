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
    let spots: [QuestSpot]
    let completedSpotIds: Set<String>
    @Binding var zoomLevel: QuestMapZoomLevel

    let onSpotSelected: (QuestSpot) -> Void

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
        mapView.overrideUserInterfaceStyle = .light

        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: 35.38,
                longitude: 139.36
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 1.05,
                longitudeDelta: 1.05
            )
        )

        mapView.setRegion(initialRegion, animated: false)

        context.coordinator.parent = self
        context.coordinator.renderAnnotations(
            on: mapView,
            level: .prefecture,
            force: true
        )

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
                        title: "神奈川",
                        subtitle: "\(parent.completedSpotIds.count) / 24 spots",
                        coordinate: CLLocationCoordinate2D(
                            latitude: 35.38,
                            longitude: 139.36
                        )
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
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
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
