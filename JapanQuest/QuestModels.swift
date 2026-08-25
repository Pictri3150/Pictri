import SwiftUI
import CoreGraphics

struct QuestUser: Identifiable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let profileImageName: String?
}

struct QuestPrefecture: Identifiable, Hashable {
    let id: String
    let name: String
    let englishName: String
    let totalSpotCount: Int
}

/// Map探索画面のフィルタチップとピン種別を分けるための、スポットの見た目上の分類。
/// 「人気」のような順位づけの概念は持たず、あくまで内容の種類だけを表す。
enum QuestSpotCategory: String, Hashable {
    case nature
    case landmark
    case photogenic
    case cafe

    var label: String {
        switch self {
        case .nature: return "自然"
        case .landmark: return "名所"
        case .photogenic: return "フォトジェニック"
        case .cafe: return "カフェ"
        }
    }

    var systemImage: String {
        switch self {
        case .nature: return "leaf.fill"
        case .landmark: return "building.columns.fill"
        case .photogenic: return "camera.fill"
        case .cafe: return "cup.and.saucer.fill"
        }
    }
}

struct QuestSpot: Identifiable, Hashable {
    let id: String
    let prefectureId: String
    let name: String
    let englishName: String
    let areaName: String
    let latitude: Double
    let longitude: Double
    let unlockRadiusMeters: Double
    let gridIndex: Int
    var category: QuestSpotCategory = .landmark
}

extension QuestSpot {
    /// Anywhere Capture Phase「Spot Unlock Architecture」で追加。curated QuestSpotに
    /// 属さないMemory(おすすめSpot外で撮った通常のMemory)をMemories画面へ表示する際、
    /// 既存の`(spot: QuestSpot, photo: QuestMemoryPhoto)`という表示用の組を崩さずに
    /// 済ませるための、表示専用の合成QuestSpot。unlockRadiusMeters=0/category=.landmark
    /// はこの合成Spotがcollection対象にならないことを示す(実際のunlock判定は
    /// isCuratedSpotMemoryで既存spotIdの一致を見るため、この値そのものは判定に使わない)。
    static func synthesized(for photo: QuestMemoryPhoto) -> QuestSpot {
        let displayName = photo.resolvedAreaName ?? "そのほかの場所"
        return QuestSpot(
            id: photo.spotId,
            prefectureId: photo.prefectureId,
            name: displayName,
            englishName: displayName,
            areaName: displayName,
            latitude: photo.latitude ?? 0,
            longitude: photo.longitude ?? 0,
            unlockRadiusMeters: 0,
            gridIndex: 0,
            category: .landmark
        )
    }
}

struct QuestPost: Identifiable, Hashable {
    let id: String
    let userId: String
    let spotId: String
    let prefectureId: String
    let createdAtText: String
    let displayDate: String
    let displayPlace: String
    let isVisibleInFeed: Bool
}

struct QuestFeedPost: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let username: String
    let spotId: String
    let prefectureId: String
    let createdAt: Date
    let expiresAt: Date
    let displayDate: String
    let displayPlace: String
    let isMine: Bool
    var imageName: String? = nil
    var verificationStatus: String? = nil
    var verifiedDistanceMeters: Double? = nil
}

extension QuestFeedPost {
    var proofStatus: QuestVerificationStatus {
        QuestVerificationStatus(rawValue: verificationStatus ?? "") ?? .unknown
    }
}

struct QuestMemoryPhoto: Identifiable, Codable, Hashable {
    let id: String
    let spotId: String
    let prefectureId: String
    let imageName: String?
    let createdAtText: String
    var verificationStatus: String? = nil
    var verifiedDistanceMeters: Double? = nil
    /// 外カメラ(場所)だけの生画像。Memory Flip Phase A以降の新規保存でのみ入る
    /// (nilなら旧Memory=imageNameのcompositeしか無い、graceful fallback対象)。
    /// compose済みimageNameには内カメラinsetが焼き込み済みで、そこから場所だけを
    /// 復元することは不可能なため、compose前の生backImageを別ファイルとして
    /// 追加保存する。既存imageNameの意味・用途は一切変更しない。
    var outerOnlyImageName: String? = nil
    /// 内カメラ(そのときの自分)だけの生画像。同上の理由でcompose前の生frontImageを
    /// 別ファイルとして追加保存する。nilなら旧Memory、cropInnerCamera(from: composite)
    /// へのgraceful fallback対象。
    var selfieImageName: String? = nil
    /// Anywhere Capture Phase「Spot Unlock Architecture」で追加。おすすめSpotの
    /// unlock radius外(=curated QuestSpotに属さない)場所で撮ったMemoryの表示名
    /// (QuestAreaResolver.resolveAreaが解決したlocality、またはSpot captureの場合は
    /// spot.areaName)。nilは旧Memory(この概念が存在する前のデータ)を示す。
    var resolvedAreaName: String? = nil
    /// 撮影時点の緯度・経度(可能な場合のみ)。位置情報が取得できなかった場合は
    /// 0,0のような無意味な値を保存せず、必ずnilのままにする。
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// 将来の国拡張(韓国等)に備え、どの国のMemoryかを保持する。今回はJP以外は
    /// 生成されない(QuestAreaResolver参照)。nilは旧Memory。
    var resolvedCountryCode: String? = nil
}

extension QuestMemoryPhoto {
    var proofStatus: QuestVerificationStatus {
        QuestVerificationStatus(rawValue: verificationStatus ?? "") ?? .unknown
    }

    /// このMemoryが実在のcurated QuestSpot(おすすめSpot)に紐づいているか。
    /// 別Boolを保存せず、既存のmockQuestSpotsとspotIdの一致だけで導出する
    /// (Spot Unlock Source of Truthを単一化する方針、詳細は最終報告)。
    var isCuratedSpotMemory: Bool {
        mockQuestSpots.contains { $0.id == spotId }
    }
}

enum QuestVerificationStatus: String, Codable, Hashable {
    case verified
    case developer
    case unverified
    case unknown

    var label: String {
        switch self {
        case .verified:
            return "VERIFIED"
        case .developer:
            return "DEV MODE"
        case .unverified:
            return "UNVERIFIED"
        case .unknown:
            return "記録済み"
        }
    }

    var iconName: String {
        switch self {
        case .verified:
            return "checkmark.seal.fill"
        case .developer:
            return "hammer.fill"
        case .unverified:
            return "location.slash.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Current UI Mock Models

struct RecentQuestPost: Identifiable {
    let id = UUID()
    let user: String
    let location: String
    let locationKey: String
    let date: String
    let timeAgo: String
    let gradient: LinearGradient
}

struct PrefectureMemory: Identifiable {
    let id = UUID()
    let name: String
    let completed: Int
    let total: Int
    let completedPreviewCount: Int
    let remainingCount: Int
    let previewColors: [Color]
}

struct MemorySpot: Identifiable {
    let id = UUID()
    let name: String
    let isUnlocked: Bool
    let color: LinearGradient
}

struct MapDot: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let isCompleted: Bool
}

struct KanagawaDot: Identifiable {
    let id = UUID()
    let name: String
    let position: CGPoint
    let size: CGFloat
    let isCompleted: Bool
}

struct QuestFriend: Identifiable, Hashable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let recentPlace: String
    let lastSharedText: String
}

struct QuestFriendRequest: Identifiable, Hashable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let message: String
    let requestedAtText: String
}
