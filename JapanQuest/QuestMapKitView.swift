import SwiftUI
import MapKit

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

                // 訪問済みは白+グレーcheckmarkで統一。未訪問は自然カテゴリならmint系の葉アイコン、
                // それ以外はaccent(sky blue)のカメラアイコンで「撮影可能」を示す。
                if spotAnnotation.isCompleted {
                    markerView.markerTintColor = .white
                    markerView.glyphTintColor = UIColor(PictriLightTheme.textSecondary)
                    markerView.glyphImage = UIImage(systemName: "checkmark")
                } else if spotAnnotation.spot.category == .nature {
                    markerView.markerTintColor = UIColor(PictriLightTheme.mint)
                    markerView.glyphTintColor = .white
                    markerView.glyphImage = UIImage(systemName: "leaf.fill")
                } else {
                    markerView.markerTintColor = UIColor(PictriLightTheme.accent)
                    markerView.glyphTintColor = .white
                    markerView.glyphImage = UIImage(systemName: "camera.fill")
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
