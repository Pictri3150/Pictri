import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var userLocation: CLLocation?
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
        if CLLocationManager.locationServicesEnabled() {
            manager.startUpdatingLocation()
        } else {
            errorMessage = "位置情報サービスがオフです。"
        }
    }

    func distance(to spot: Spot) -> CLLocationDistance? {
        guard let userLocation else {
            return nil
        }

        let spotLocation = CLLocation(
            latitude: spot.latitude,
            longitude: spot.longitude
        )

        return userLocation.distance(from: spotLocation)
    }

    func isNear(_ spot: Spot) -> Bool {
        guard let distance = distance(to: spot) else {
            return false
        }

        return distance <= spot.unlockRadiusMeters
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
        userLocation = locations.last
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        errorMessage = error.localizedDescription
    }
}
