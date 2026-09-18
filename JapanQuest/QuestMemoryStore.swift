import SwiftUI
import UIKit
import Combine
import Foundation

/// Anywhere Capture Phase「Spot Unlock Architecture」で追加。
/// Camera側が「curated QuestSpot(おすすめSpot)で撮った」のか「Spot外の
/// 現在地で撮った(QuestAreaResolverが解決した)」のかを区別せず、Store側は
/// この1つの値だけを見て保存すればよいようにするための橋渡し。
/// spotIdはcurated Spotならその実spot.id、Spot外ならcapture毎に新規生成した
/// 一意な文字列("freeform_<uuid>")──mockQuestSpotsの実在spot.idとは
/// 絶対に衝突しない──を持つ。これにより「同じcurated Spotへ再訪問したら
/// 上書き、Spot外は毎回新規」という既存のupsert-by-spotIdロジックを
/// そのまま流用できる(分岐を増やさない)。
struct QuestCaptureTarget {
    let spotId: String
    let prefectureId: String
    let areaName: String
    let displayPlace: String
    let latitude: Double?
    let longitude: Double?
    let countryCode: String?

    static func curatedSpot(_ spot: QuestSpot) -> QuestCaptureTarget {
        QuestCaptureTarget(
            spotId: spot.id,
            prefectureId: spot.prefectureId,
            areaName: spot.areaName,
            displayPlace: spot.englishName.lowercased(),
            latitude: spot.latitude,
            longitude: spot.longitude,
            countryCode: "JP"
        )
    }

    static func freeform(resolvedArea: QuestResolvedArea, latitude: Double?, longitude: Double?) -> QuestCaptureTarget {
        QuestCaptureTarget(
            spotId: "freeform_\(UUID().uuidString)",
            prefectureId: resolvedArea.prefectureId,
            areaName: resolvedArea.areaName,
            displayPlace: resolvedArea.areaName,
            latitude: latitude,
            longitude: longitude,
            countryCode: resolvedArea.countryCode
        )
    }
}

/// Round 8「Prefecture Progress System」。都道府県ごとの「おすすめSpot
/// コンプリート進捗」を表す値型。Viewが`memoryPhotos`配列を直接何度も
/// scanしないよう、この1つの構造体へ集約する(Progress Resolver抽象化)。
/// `completedRecommendedSpotIDs`はcurated QuestSpot(おすすめSpot)の
/// **ユニークなspotId**の集合であり、同じSpotで何枚撮っても1件のまま
/// (枚数ではなくSpot単位でカウントする、というRound 8の核心ルール)。
/// Anywhere capture(`freeform_<uuid>`のspotId)はこのSetに一切含めない。
struct PrefectureProgress {
    let prefectureID: String
    let hasVisited: Bool
    let completedRecommendedSpotIDs: Set<String>
    let totalRecommendedSpotCount: Int

    var completedCount: Int { completedRecommendedSpotIDs.count }

    /// v1は「1県あたりおすすめSpot ~5件」を前提にした6段階color mappingだが、
    /// 実データ(mockQuestSpots)は県によって件数がバラバラ(kanagawa=30〜
    /// 未整備=0)なため、固定の5分岐ではなく常にratio(completedCount /
    /// totalRecommendedSpotCount)で最も近い段階へ写像する。件数が変わっても
    /// 壊れない。
    enum CollectionLevel {
        /// 未訪問(県に一度もMemoryが無い)
        case unvisited
        /// 訪問済みだが、おすすめSpotのcurated登録が0件、またはまだ1件も
        /// コンプリートしていない
        case visitedNoSpots
        case level1
        case level2
        case level3
        case level4
        /// 全おすすめSpotをコンプリート。Goldはこの状態専用(他では絶対に使わない)。
        case complete
    }

    var collectionLevel: CollectionLevel {
        guard hasVisited else { return .unvisited }
        guard totalRecommendedSpotCount > 0, completedCount > 0 else { return .visitedNoSpots }
        if completedCount >= totalRecommendedSpotCount { return .complete }

        let ratio = Double(completedCount) / Double(totalRecommendedSpotCount)
        switch ratio {
        case ..<0.25: return .level1
        case ..<0.50: return .level2
        case ..<0.75: return .level3
        default: return .level4
        }
    }
}

/// MAP/ALBUM REFERENCE MIGRATION — Album screen専用のderived model。
/// Round 8の`PrefectureProgress`をそのまま内包し、Albumが必要とする追加情報
/// (代表Memory・思い出枚数・直近のRecommended Spot写真)だけを足す。Viewは
/// `memoryPhotos`を直接scanせず、必ず`QuestMemoryStore.albumSummaries()`
/// 経由でこの値を得る(Round 8のProgress Resolver抽象化と同じ方針)。
struct PrefectureAlbumSummary: Identifiable {
    let prefectureID: String
    var id: String { prefectureID }
    let prefectureName: String
    let memoryCount: Int
    let progress: PrefectureProgress
    /// 県Card左側の代表写真。優先順位(spec「REPRESENTATIVE MEMORY」通り):
    /// 1. 直近のRecommended Spot Memory(コンプリート後の最後の達成も、
    ///    進行中の最新達成も、どちらも「直近のRecommended Spot Memory」に
    ///    帰着するため同じロジックで表現できる)
    /// 2. Recommended Spot Memoryが無ければ、直近のAnywhere Memory
    /// 3. 写真が1枚も無ければnil(呼び出し側でintentional placeholderを描く)
    let representativeMemory: QuestMemoryPhoto?
    /// Card右側のRecommended Spot達成サムネイル行(最大4枚、直近優先)。
    let recentRecommendedMemories: [QuestMemoryPhoto]
}

extension QuestMemoryStore {
    /// 訪問済み県すべてのAlbum summaryを返す(訪問済み=`visitedPrefectureIds`)。
    func albumSummaries() -> [PrefectureAlbumSummary] {
        let visitedIds = visitedPrefectureIds
        return questPrefectureShapes
            .filter { visitedIds.contains($0.id) }
            .map { albumSummary(forPrefectureId: $0.id, fallbackName: $0.name) }
    }

    /// `memoryPhotos`は`saveMemoryPhoto`が常に`insert(at: 0)`するため、配列順が
    /// そのまま「新しい順」になっている(Source: QuestMemoryStore.saveMemoryPhoto)。
    /// ここでは新しい日付文字列をparseし直さず、この既存の並び順をそのまま利用する。
    func albumSummary(forPrefectureId prefectureId: String, fallbackName: String? = nil) -> PrefectureAlbumSummary {
        let photos = memoryPhotos.filter { $0.prefectureId == prefectureId }
        let recommendedPhotos = photos.filter { $0.isCuratedSpotMemory }
        let anywherePhotos = photos.filter { !$0.isCuratedSpotMemory }
        let representative = recommendedPhotos.first ?? anywherePhotos.first
        let name = mockQuestPrefectures.first(where: { $0.id == prefectureId })?.name
            ?? fallbackName
            ?? prefectureId

        return PrefectureAlbumSummary(
            prefectureID: prefectureId,
            prefectureName: name,
            memoryCount: photos.count,
            progress: prefectureProgress(for: prefectureId),
            representativeMemory: representative,
            recentRecommendedMemories: Array(recommendedPhotos.prefix(4))
        )
    }

    /// Album summary row「おすすめ達成 x/y」用。xは全訪問県のcompletedRecommendedSpotIDs
    /// の合計(重複spotなし、Round 8の一意カウントルールをそのまま継承)、yは
    /// `mockQuestSpots`の総数(現在データが揃っている県だけの実件数、47県×5の
    /// 捏造ではない)。
    var totalCompletedRecommendedSpotCount: Int {
        albumSummaries().reduce(0) { $0 + $1.progress.completedCount }
    }

    var totalRecommendedSpotCatalogCount: Int {
        mockQuestSpots.count
    }
}

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
        // QA向けの状態確認用。本番UIには一切出さない、コンソールログのみ。
        print("[PictriVisualReview] memoryMode=\(PictriVisualReview.memoryModeIsClean ? "clean" : "persisted") memoryPhotos=\(memoryPhotos.count) feedPosts=\(feedPosts.count)")
        Self.debugValidateSpotDataset()
        #endif
    }

    #if DEBUG
    /// Curated Spot Dataset拡張時のQA専用の軽い健全性チェック。新しい抽象化層は
    /// 作らず、起動時に1回コンソールへ警告を出すだけ(本番UIには一切出ない)。
    /// 1) id重複がないか 2) 同一県内の他Spotから極端に離れた座標(タイプミス等で
    /// 別の場所を指してしまっている可能性)がないかの2点だけを見る。
    private static func debugValidateSpotDataset() {
        var seenIds = Set<String>()
        for spot in mockQuestSpots {
            if !seenIds.insert(spot.id).inserted {
                print("[PictriSpotValidation] 重複id検出: \(spot.id)")
            }
        }

        let byPrefecture = Dictionary(grouping: mockQuestSpots, by: \.prefectureId)
        for (prefectureId, spots) in byPrefecture where spots.count > 1 {
            for spot in spots {
                let maxDistanceKm = spots
                    .filter { $0.id != spot.id }
                    .map { other -> Double in
                        let dLat = spot.latitude - other.latitude
                        let dLon = spot.longitude - other.longitude
                        // 精密な測地線距離ではなく、明らかな入力ミス検知だけが目的の
                        // 簡易近似(緯度1度・経度1度をともに約111kmとみなす)。
                        return ((dLat * 111.0).magnitude + (dLon * 111.0).magnitude)
                    }
                    .min() ?? 0
                if maxDistanceKm > 300 {
                    print("[PictriSpotValidation] \(prefectureId)の\(spot.id)は同県内の他Spotから300km以上離れています(座標ミスの可能性、要確認)")
                }
            }
        }
    }
    #endif

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

            var imageName: String? = nil
            var outerOnlyImageName: String? = nil
            var selfieImageName: String? = nil

            if PictriVisualReview.seedRealPhotos {
                let demoBack = QuestDemoPhotoMaker.makePhoto(spot: spot, isFrontCamera: false)
                let demoFront = QuestDemoPhotoMaker.makePhoto(spot: spot, isFrontCamera: true)
                let composite = QuestDualPhotoComposer.compose(
                    backImage: demoBack,
                    frontImage: demoFront,
                    spot: spot
                )
                imageName = saveImageToDocuments(image: composite)
                outerOnlyImageName = saveImageToDocuments(image: demoBack)
                selfieImageName = saveImageToDocuments(image: demoFront)
            }

            memoryPhotos.insert(
                QuestMemoryPhoto(
                    id: "debug_seed_\(spotId)",
                    spotId: spot.id,
                    prefectureId: spot.prefectureId,
                    imageName: imageName,
                    createdAtText: currentDateTimeText(),
                    verificationStatus: QuestVerificationStatus.developer.rawValue,
                    verifiedDistanceMeters: nil,
                    outerOnlyImageName: outerOnlyImageName,
                    selfieImageName: selfieImageName
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

    /// 外カメラ(場所)だけの生画像。新規Memoryのみ存在(QuestMemoryPhoto.outerOnlyImageName参照)。
    func outerOnlyImage(for spot: QuestSpot) -> UIImage? {
        guard let memory = memoryPhoto(for: spot),
              let outerOnlyImageName = memory.outerOnlyImageName else {
            return nil
        }

        return loadImage(fileName: outerOnlyImageName)
    }

    /// 内カメラ(そのときの自分)だけの生画像。新規Memoryのみ存在(QuestMemoryPhoto.selfieImageName参照)。
    func selfieImage(for spot: QuestSpot) -> UIImage? {
        guard let memory = memoryPhoto(for: spot),
              let selfieImageName = memory.selfieImageName else {
            return nil
        }

        return loadImage(fileName: selfieImageName)
    }

    /// spotId経由ではなくQuestMemoryPhoto自身から直接読む版。curated Spotに
    /// 属さないMemory(合成QuestSpotしか持たない)でも常に正しく画像を引けるように、
    /// Anywhere Capture Phaseで追加。既存のimage(for spot:)は無変更のまま残す。
    func image(for photo: QuestMemoryPhoto) -> UIImage? {
        guard let imageName = photo.imageName else { return nil }
        return loadImage(fileName: imageName)
    }

    func outerOnlyImage(for photo: QuestMemoryPhoto) -> UIImage? {
        guard let name = photo.outerOnlyImageName else { return nil }
        return loadImage(fileName: name)
    }

    func selfieImage(for photo: QuestMemoryPhoto) -> UIImage? {
        guard let name = photo.selfieImageName else { return nil }
        return loadImage(fileName: name)
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

    /// image(for post:)と同じspotIdマッチングで、Memory Flip用の生outer画像を引く。
    /// 旧Memory(outerOnlyImageNameが無い)ではnilを返し、呼び出し側がgraceful fallbackする。
    func outerOnlyImage(for post: QuestFeedPost) -> UIImage? {
        guard let memory = memoryPhotos.first(where: { $0.spotId == post.spotId }),
              let name = memory.outerOnlyImageName else {
            return nil
        }
        return loadImage(fileName: name)
    }

    /// 同上、Memory Flip用の生selfie画像。
    func selfieImage(for post: QuestFeedPost) -> UIImage? {
        guard let memory = memoryPhotos.first(where: { $0.spotId == post.spotId }),
              let name = memory.selfieImageName else {
            return nil
        }
        return loadImage(fileName: name)
    }

    func visibleFeedPosts() -> [QuestFeedPost] {
        let now = Date()

        return feedPosts
            .filter { $0.expiresAt > now }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 戻り値は「実際に保存できたか」。呼び出し側(CameraView)はこれを見てからでないと
    /// FREE quotaを消費してはいけない(Pictri Core Invariant 5「保存失敗時はquotaを
    /// 消費しない」)。以前はVoidを返しており、ディスク書き込み失敗時(saveImageToDocuments
    /// がnilを返す場合)にsave()が黙って何もしないのに、呼び出し側はそれを検知できず
    /// quotaだけ減ってしまう経路が存在した。
    @discardableResult
    func save(
        image: UIImage,
        target: QuestCaptureTarget,
        verificationStatus: QuestVerificationStatus = .unverified,
        verifiedDistanceMeters: Double? = nil,
        outerOnlyImage: UIImage? = nil,
        selfieImage: UIImage? = nil
    ) -> Bool {
        guard let fileName = saveImageToDocuments(image: image) else {
            return false
        }

        // outerOnly/selfieは「表=場所/裏=自分」を成立させるための追加データであり、
        // 書き込みに失敗しても保存自体は失敗させない(compositeさえ保存できれば
        // 既存のInvariant 5的な「保存成功」は成立する、こちらはgraceful degradeでよい)。
        let outerOnlyFileName = outerOnlyImage.flatMap { saveImageToDocuments(image: $0) }
        let selfieFileName = selfieImage.flatMap { saveImageToDocuments(image: $0) }

        saveMemoryPhoto(
            target: target,
            imageName: fileName,
            verificationStatus: verificationStatus,
            verifiedDistanceMeters: verifiedDistanceMeters,
            outerOnlyImageName: outerOnlyFileName,
            selfieImageName: selfieFileName
        )

        createFeedPost(
            target: target,
            imageName: fileName,
            verificationStatus: verificationStatus,
            verifiedDistanceMeters: verifiedDistanceMeters
        )

        save()
        return true
    }

    /// Round 8 Progress Resolver。Viewが`memoryPhotos`を直接filterするのではなく、
    /// 必ずこの1つの入口を経由して`PrefectureProgress`を得る。おすすめSpotの
    /// ユニークspotId数だけをcountし(枚数ではない)、Anywhere capture
    /// (`freeform_<uuid>`のspotId、`isCuratedSpotMemory == false`)は含めない。
    func prefectureProgress(for prefectureId: String) -> PrefectureProgress {
        let hasVisited = visitedPrefectureIds.contains(prefectureId)
        let completedIds = Set(
            memoryPhotos
                .filter { $0.prefectureId == prefectureId && $0.isCuratedSpotMemory }
                .map { $0.spotId }
        )
        let total = mockQuestSpots.filter { $0.prefectureId == prefectureId }.count

        return PrefectureProgress(
            prefectureID: prefectureId,
            hasVisited: hasVisited,
            completedRecommendedSpotIDs: completedIds,
            totalRecommendedSpotCount: total
        )
    }

    func completedCount(prefectureId: String) -> Int {
        let spotIds = memoryPhotos
            .filter { $0.prefectureId == prefectureId }
            .map { $0.spotId }

        return Set(spotIds).count
    }

    /// 訪問済み都道府県の正式なSource of Truth。「実際にメモリーが1枚でもある県」を
    /// 基準にする(QuestMapView.swiftに同等のprivate計算が既にあったが、Store側に
    /// 正式なAPIが無かったため、画面ごとに同じSet(...)計算が重複していた)。
    /// prefectureIdは常に非Optionalの String(QuestMemoryPhoto.prefectureId)で、
    /// 重複したmemoryPhotos(同じ県に複数枚)があってもSetが自然に去重するため、
    /// 追加の正規化やdedup処理は不要。
    var visitedPrefectureIds: Set<String> {
        Set(memoryPhotos.map(\.prefectureId))
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
        target: QuestCaptureTarget,
        imageName: String,
        verificationStatus: QuestVerificationStatus,
        verifiedDistanceMeters: Double?,
        outerOnlyImageName: String? = nil,
        selfieImageName: String? = nil
    ) {
        if let index = memoryPhotos.firstIndex(where: { $0.spotId == target.spotId }) {
            memoryPhotos[index] = QuestMemoryPhoto(
                id: memoryPhotos[index].id,
                spotId: target.spotId,
                prefectureId: target.prefectureId,
                imageName: imageName,
                createdAtText: currentDateTimeText(),
                verificationStatus: verificationStatus.rawValue,
                verifiedDistanceMeters: verifiedDistanceMeters,
                outerOnlyImageName: outerOnlyImageName,
                selfieImageName: selfieImageName,
                resolvedAreaName: target.areaName,
                latitude: target.latitude,
                longitude: target.longitude,
                resolvedCountryCode: target.countryCode
            )
        } else {
            let newPhoto = QuestMemoryPhoto(
                id: UUID().uuidString,
                spotId: target.spotId,
                prefectureId: target.prefectureId,
                imageName: imageName,
                createdAtText: currentDateTimeText(),
                verificationStatus: verificationStatus.rawValue,
                verifiedDistanceMeters: verifiedDistanceMeters,
                outerOnlyImageName: outerOnlyImageName,
                selfieImageName: selfieImageName,
                resolvedAreaName: target.areaName,
                latitude: target.latitude,
                longitude: target.longitude,
                resolvedCountryCode: target.countryCode
            )

            memoryPhotos.insert(newPhoto, at: 0)
        }
    }

    private func createFeedPost(
        target: QuestCaptureTarget,
        imageName: String,
        verificationStatus: QuestVerificationStatus,
        verifiedDistanceMeters: Double?
    ) {
        let post = QuestFeedPost(
            id: UUID().uuidString,
            userId: "user_keita",
            username: "you",
            spotId: target.spotId,
            prefectureId: target.prefectureId,
            createdAt: Date(),
            expiresAt: Calendar.current.date(
                byAdding: .day,
                value: 7,
                to: Date()
            ) ?? Date(),
            displayDate: currentDateText(),
            displayPlace: target.displayPlace,
            isMine: true,
            imageName: imageName,
            verificationStatus: verificationStatus.rawValue,
            verifiedDistanceMeters: verifiedDistanceMeters
        )

        feedPosts.insert(post, at: 0)
    }

    // MARK: - Save / Load Metadata

    private func save() {
        #if DEBUG
        // clean modeではUserDefaultsへの書き込みを一切行わない。既存の永続データを
        // 変更・削除せず、プロセス終了と同時に消える表示専用の状態のままにするため。
        guard !PictriVisualReview.memoryModeIsClean else { return }
        #endif

        do {
            let memoryData = try JSONEncoder().encode(memoryPhotos)
            UserDefaults.standard.set(memoryData, forKey: memoryPhotosKey)

            let feedData = try JSONEncoder().encode(feedPosts)
            UserDefaults.standard.set(feedData, forKey: feedPostsKey)
        } catch {
            print("Failed to save metadata:", error.localizedDescription)
        }
    }

    #if DEBUG
    /// `-pictriHomeSeedAnywhereQA true` Round 8専用。既定の`mockQuestFeedPosts`
    /// 3件は全てcurated QuestSpot(spotIdがmockQuestSpotsに実在)のため、
    /// Anywhere Memory(curated Spot外で撮った投稿)のCard rim(neutral silver/
    /// soft-white)をQAで見せる材料が無かった。spotIdを`qa_freeform_`prefixの
    /// 非実在idにすることで、`isCuratedSpotMemory`(mockQuestSpotsとの一致判定)が
    /// 確実にfalseになる = captureKind == .anywhereになる1件だけを追加する。
    /// 本番`mockQuestFeedPosts`・本番RecommendedSpot catalogは一切変更しない。
    private static var homeAnywhereCaptureQAPost: QuestFeedPost {
        QuestFeedPost(
            id: "qa_anywhere_riku_yokohama",
            userId: "user_riku_qa",
            username: "riku",
            spotId: "qa_freeform_yokohama_streetcorner",
            prefectureId: "kanagawa",
            createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
            displayDate: currentDateTextStatic(),
            displayPlace: "yokohama",
            isMine: false
        )
    }

    private static func currentDateTextStatic() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: Date())
    }
    #endif

    #if DEBUG
    /// `-pictriHomeSeedExtraFeed true`専用。双方向Swipeの実装がFeed端の仕様
    /// (最初/最後の投稿では片側にしかsideカードが無い)なのか、Carousel自体の
    /// bugなのかを切り分けるためだけの、Release非同梱の一時データ。本番の
    /// `mockQuestFeedPosts`は変更しない。
    private static var homeBidirectionalSwipeQAPosts: [QuestFeedPost] {
        [
            QuestFeedPost(
                id: "qa_extra_mio_yamashita",
                userId: "user_mio_qa",
                username: "mio",
                spotId: "yamashita_park",
                prefectureId: "kanagawa",
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                expiresAt: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
                displayDate: "2026/05/25",
                displayPlace: "yamashita",
                isMine: false
            ),
            QuestFeedPost(
                id: "qa_extra_kai_akarenga",
                userId: "user_kai_qa",
                username: "kai",
                spotId: "akarenga",
                prefectureId: "kanagawa",
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                expiresAt: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date(),
                displayDate: "2026/05/23",
                displayPlace: "akarenga",
                isMine: false
            )
        ]
    }
    #endif

    private func load() {
        #if DEBUG
        // clean modeではUserDefaultsを一切読まず、アプリ同梱のmock seed状態だけで
        // 起動する。UserDefaultsの中身自体は削除しない(「読み込みを無視する」だけ)ため、
        // 次回persisted状態(通常起動)に戻せば既存の永続データはそのまま復元される。
        if PictriVisualReview.memoryModeIsClean {
            memoryPhotos = mockQuestMemoryPhotos
            feedPosts = mockQuestFeedPosts
            if PictriVisualReview.homeSeedExtraFeedRequested {
                feedPosts += Self.homeBidirectionalSwipeQAPosts
            }
            if PictriVisualReview.homeSeedAnywhereQARequested {
                feedPosts.insert(Self.homeAnywhereCaptureQAPost, at: 0)
            }
            return
        }
        #endif

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

        // CAMERA / POST IMAGING ROUND「PART 6 — JPEG QUALITY AUDIT」。0.88→0.92。
        // これが保存パイプライン唯一のJPEGエンコード箇所(QuestDualPhotoComposer.
        // compose()はUIGraphicsImageRenderer/CGContextでビットマップを合成する
        // だけでJPEG化はしない、二重圧縮なし)。実機比較(髪/文字/夜景等の細部)は
        // 本Roundの実機QAで実施予定——シミュレータのカメラ出力はダミー画像のため
        // ここでは「輪郭を再現前提に妥当な値へ引き上げる」候補値として採用。
        guard let data = image.jpegData(compressionQuality: 0.92) else {
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
