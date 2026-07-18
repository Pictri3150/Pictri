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
}

extension QuestMemoryPhoto {
    var proofStatus: QuestVerificationStatus {
        QuestVerificationStatus(rawValue: verificationStatus ?? "") ?? .unknown
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
            return "UNKNOWN"
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
