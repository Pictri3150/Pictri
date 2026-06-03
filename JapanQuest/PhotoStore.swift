import SwiftUI
import UIKit
import Combine

struct QuestPhoto: Identifiable, Codable, Hashable {
    let id: String
    let spotId: String
    let spotName: String
    let createdAt: Date
    let fileName: String
}

final class PhotoStore: ObservableObject {
    @Published private(set) var photos: [QuestPhoto] = []

    private let metadataKey = "quest_photos_metadata"

    init() {
        loadMetadata()
    }

    func save(image: UIImage, spot: Spot) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return
        }

        let id = UUID().uuidString
        let fileName = "\(id).jpg"
        let url = documentsDirectory().appendingPathComponent(fileName)

        do {
            try data.write(to: url)

            let photo = QuestPhoto(
                id: id,
                spotId: spot.id,
                spotName: spot.name,
                createdAt: Date(),
                fileName: fileName
            )

            photos.insert(photo, at: 0)
            saveMetadata()
        } catch {
            print("Failed to save image:", error.localizedDescription)
        }
    }

    func image(for photo: QuestPhoto) -> UIImage? {
        let url = documentsDirectory().appendingPathComponent(photo.fileName)
        return UIImage(contentsOfFile: url.path)
    }

    func delete(_ photo: QuestPhoto) {
        let url = documentsDirectory().appendingPathComponent(photo.fileName)

        try? FileManager.default.removeItem(at: url)

        photos.removeAll { $0.id == photo.id }
        saveMetadata()
    }

    private func saveMetadata() {
        do {
            let data = try JSONEncoder().encode(photos)
            UserDefaults.standard.set(data, forKey: metadataKey)
        } catch {
            print("Failed to save metadata:", error.localizedDescription)
        }
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey) else {
            return
        }

        do {
            photos = try JSONDecoder().decode([QuestPhoto].self, from: data)
        } catch {
            photos = []
        }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }
}
