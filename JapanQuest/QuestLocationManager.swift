import Foundation
import CoreLocation
import Combine

final class QuestLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func distance(to spot: QuestSpot) -> CLLocationDistance? {
        guard let currentLocation else {
            return nil
        }

        let spotLocation = CLLocation(
            latitude: spot.latitude,
            longitude: spot.longitude
        )

        return currentLocation.distance(from: spotLocation)
    }

    func isNear(_ spot: QuestSpot) -> Bool {
        guard let distance = distance(to: spot) else {
            return false
        }

        return distance <= spot.unlockRadiusMeters
    }

    func distanceText(to spot: QuestSpot) -> String {
        guard let distance = distance(to: spot) else {
            return "現在地を取得中"
        }

        if distance >= 1000 {
            return String(format: "%.1fkm", distance / 1000)
        } else {
            return "\(Int(distance))m"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()

        case .denied, .restricted:
            errorMessage = "位置情報の使用が許可されていません。設定から許可してください。"

        case .notDetermined:
            break

        @unknown default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        currentLocation = locations.last
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        errorMessage = error.localizedDescription
    }
}
