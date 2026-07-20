import SwiftUI
import UIKit
import Combine
import Foundation

final class QuestMemoryStore: ObservableObject {
    @Published var memoryPhotos: [QuestMemoryPhoto] = []
    @Published var feedPosts: [QuestFeedPost] = []

    private let memoryPhotosKey = "quest_memory_photos"
    private let feedPostsKey = "quest_feed_posts"

    init() {
        load()
        purgeExpiredFeedPosts()
        #if DEBUG
        debugSeedVisitedFromLaunchArgsIfNeeded()
        #endif
    }

    #if DEBUG
    /// DEBUG限定・目視QA専用。`-pictriSeedVisitedSpot`/`-pictriSeedVisitedSpots`で指定された
    /// spotIdを、実際のCamera撮影を経ずに「保存済み」として表示上のmemoryPhotos/feedPostsに
    /// 追加する。verificationStatusは常に.developer("DEV MODE"表示)にして実撮影と区別できる
    /// ようにする。UserDefaultsへは一切保存しない(save()を呼ばない)ため、プロセス終了と
    /// 同時に消える表示専用の上乗せで、実ユーザーの保存データを一切破壊しない。
    private func debugSeedVisitedFromLaunchArgsIfNeeded() {
        let spotIds = PictriVisualReview.seedVisitedSpotIds
        guard !spotIds.isEmpty else { return }

        for spotId in spotIds {
            guard let spot = mockQuestSpots.first(where: { $0.id == spotId }) else { continue }
            guard !memoryPhotos.contains(where: { $0.spotId == spotId }) else { continue }

            memoryPhotos.insert(
                QuestMemoryPhoto(
                    id: "debug_seed_\(spotId)",
                    spotId: spot.id,
                    prefectureId: spot.prefectureId,
                    imageName: nil,
                    createdAtText: currentDateTimeText(),
                    verificationStatus: QuestVerificationStatus.developer.rawValue,
                    verifiedDistanceMeters: nil
                ),
                at: 0
            )

            feedPosts.insert(
                QuestFeedPost(
                    id: "debug_seed_feed_\(spotId)",
                    userId: "user_keita",
                    username: "you",
                    spotId: spot.id,
                    prefectureId: spot.prefectureId,
                    createdAt: Date(),
                    expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                    displayDate: currentDateText(),
                    displayPlace: spot.englishName.lowercased(),
                    isMine: true,
                    imageName: nil,
                    verificationStatus: QuestVerificationStatus.developer.rawValue,
                    verifiedDistanceMeters: nil
                ),
                at: 0
            )
        }
    }
    #endif

    // MARK: - Public

    func hasMemory(for spot: QuestSpot) -> Bool {
        memoryPhotos.contains { $0.spotId == spot.id }
    }

    func memoryPhoto(for spot: QuestSpot) -> QuestMemoryPhoto? {
        memoryPhotos.first { $0.spotId == spot.id }
    }

    func image(for spot: QuestSpot) -> UIImage? {
        guard let memory = memoryPhoto(for: spot),
              let imageName = memory.imageName else {
            return nil
        }

        return loadImage(fileName: imageName)
    }

    func image(for post: QuestFeedPost) -> UIImage? {
        if let imageName = post.imageName {
            return loadImage(fileName: imageName)
        }

        if let memory = memoryPhotos.first(where: { $0.spotId == post.spotId }),
           let imageName = memory.imageName {
            return loadImage(fileName: imageName)
        }

        return nil
    }

    func visibleFeedPosts() -> [QuestFeedPost] {
        let now = Date()

        return feedPosts
            .filter { $0.expiresAt > now }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(
        image: UIImage,
        for spot: QuestSpot,
        verificationStatus: QuestVerificationStatus = .unverified,
        verifiedDistanceMeters: Double? = nil
    ) {
        guard let fileName = saveImageToDocuments(image: image) else {
            return
        }

        saveMemoryPhoto(
            for: spot,
            imageName: fileName,
            verificationStatus: verificationStatus,
            verifiedDistanceMeters: verifiedDistanceMeters
        )

        createFeedPost(
            for: spot,
            imageName: fileName,
            verificationStatus: verificationStatus,
            verifiedDistanceMeters: verifiedDistanceMeters
        )

        save()
    }

    func completedCount(prefectureId: String) -> Int {
        let spotIds = memoryPhotos
            .filter { $0.prefectureId == prefectureId }
            .map { $0.spotId }

        return Set(spotIds).count
    }

    func purgeExpiredFeedPosts() {
        let now = Date()
        let beforeCount = feedPosts.count

        feedPosts.removeAll { $0.expiresAt <= now }

        if feedPosts.count != beforeCount {
            save()
        }
    }

    // MARK: - Memory

    private func saveMemoryPhoto(
        for spot: QuestSpot,
        imageName: String,
        verificationStatus: QuestVerificationStatus,
        verifiedDistanceMeters: Double?
    ) {
        if let index = memoryPhotos.firstIndex(where: { $0.spotId == spot.id }) {
            memoryPhotos[index] = QuestMemoryPhoto(
                id: memoryPhotos[index].id,
                spotId: spot.id,
                prefectureId: spot.prefectureId,
                imageName: imageName,
                createdAtText: currentDateTimeText(),
                verificationStatus: verificationStatus.rawValue,
                verifiedDistanceMeters: verifiedDistanceMeters
            )
        } else {
            let newPhoto = QuestMemoryPhoto(
                id: UUID().uuidString,
                spotId: spot.id,
                prefectureId: spot.prefectureId,
                imageName: imageName,
                createdAtText: currentDateTimeText(),
                verificationStatus: verificationStatus.rawValue,
                verifiedDistanceMeters: verifiedDistanceMeters
            )

            memoryPhotos.insert(newPhoto, at: 0)
        }
    }

    private func createFeedPost(
        for spot: QuestSpot,
        imageName: String,
        verificationStatus: QuestVerificationStatus,
        verifiedDistanceMeters: Double?
    ) {
        let post = QuestFeedPost(
            id: UUID().uuidString,
            userId: "user_keita",
            username: "you",
            spotId: spot.id,
            prefectureId: spot.prefectureId,
            createdAt: Date(),
            expiresAt: Calendar.current.date(
                byAdding: .day,
                value: 7,
                to: Date()
            ) ?? Date(),
            displayDate: currentDateText(),
            displayPlace: spot.englishName.lowercased(),
            isMine: true,
            imageName: imageName,
            verificationStatus: verificationStatus.rawValue,
            verifiedDistanceMeters: verifiedDistanceMeters
        )

        feedPosts.insert(post, at: 0)
    }

    // MARK: - Save / Load Metadata

    private func save() {
        do {
            let memoryData = try JSONEncoder().encode(memoryPhotos)
            UserDefaults.standard.set(memoryData, forKey: memoryPhotosKey)

            let feedData = try JSONEncoder().encode(feedPosts)
            UserDefaults.standard.set(feedData, forKey: feedPostsKey)
        } catch {
            print("Failed to save metadata:", error.localizedDescription)
        }
    }

    private func load() {
        let loadedMemories = loadMemoryPhotos()
        let loadedFeeds = loadFeedPosts()

        if loadedMemories.isEmpty {
            memoryPhotos = mockQuestMemoryPhotos
        } else {
            memoryPhotos = loadedMemories
        }

        if loadedFeeds.isEmpty {
            feedPosts = mockQuestFeedPosts
        } else {
            feedPosts = loadedFeeds
        }
    }

    private func loadMemoryPhotos() -> [QuestMemoryPhoto] {
        guard let data = UserDefaults.standard.data(forKey: memoryPhotosKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([QuestMemoryPhoto].self, from: data)
        } catch {
            print("Failed to load memories:", error.localizedDescription)
            return []
        }
    }

    private func loadFeedPosts() -> [QuestFeedPost] {
        guard let data = UserDefaults.standard.data(forKey: feedPostsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([QuestFeedPost].self, from: data)
        } catch {
            print("Failed to load feed posts:", error.localizedDescription)
            return []
        }
    }

    // MARK: - Image File

    private func saveImageToDocuments(image: UIImage) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        let url = documentsDirectory().appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.88) else {
            return nil
        }

        do {
            try data.write(to: url)
            return fileName
        } catch {
            print("Failed to save image:", error.localizedDescription)
            return nil
        }
    }

    private func loadImage(fileName: String) -> UIImage? {
        let url = documentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    // MARK: - Date

    private func currentDateText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: Date())
    }

    private func currentDateTimeText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: Date())
    }
}
