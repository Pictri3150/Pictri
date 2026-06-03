import SwiftUI
import CoreGraphics

let mockUsers: [QuestUser] = [
    QuestUser(
        id: "user_keita",
        username: "keita_travel",
        displayName: "Keita",
        profileImageName: nil
    ),
    QuestUser(
        id: "user_haruka",
        username: "haruka_photo",
        displayName: "Haruka",
        profileImageName: nil
    ),
    QuestUser(
        id: "user_sota",
        username: "sota_world",
        displayName: "Sota",
        profileImageName: nil
    )
]

let mockQuestPrefectures: [QuestPrefecture] = [
    QuestPrefecture(
        id: "kanagawa",
        name: "神奈川",
        englishName: "Kanagawa",
        totalSpotCount: 24
    ),
    QuestPrefecture(
        id: "tokyo",
        name: "東京",
        englishName: "Tokyo",
        totalSpotCount: 30
    ),
    QuestPrefecture(
        id: "kyoto",
        name: "京都",
        englishName: "Kyoto",
        totalSpotCount: 28
    ),
    QuestPrefecture(
        id: "hokkaido",
        name: "北海道",
        englishName: "Hokkaido",
        totalSpotCount: 32
    )
]

let mockQuestSpots: [QuestSpot] = [
    QuestSpot(
        id: "enoshima_coast",
        prefectureId: "kanagawa",
        name: "江の島海岸",
        englishName: "enoshima",
        areaName: "湘南",
        latitude: 35.2996,
        longitude: 139.4807,
        unlockRadiusMeters: 250,
        gridIndex: 0
    ),
    QuestSpot(
        id: "kamakura_daibutsu",
        prefectureId: "kanagawa",
        name: "鎌倉大仏",
        englishName: "kamakura",
        areaName: "鎌倉",
        latitude: 35.3167,
        longitude: 139.5358,
        unlockRadiusMeters: 250,
        gridIndex: 1
    ),
    QuestSpot(
        id: "akarenga",
        prefectureId: "kanagawa",
        name: "赤レンガ倉庫",
        englishName: "yokohama",
        areaName: "横浜",
        latitude: 35.4526,
        longitude: 139.6428,
        unlockRadiusMeters: 250,
        gridIndex: 2
    ),
    QuestSpot(
        id: "minatomirai",
        prefectureId: "kanagawa",
        name: "みなとみらい",
        englishName: "minatomirai",
        areaName: "横浜",
        latitude: 35.4579,
        longitude: 139.6323,
        unlockRadiusMeters: 300,
        gridIndex: 3
    ),
    QuestSpot(
        id: "kamakura_station",
        prefectureId: "kanagawa",
        name: "鎌倉駅",
        englishName: "kamakura",
        areaName: "鎌倉",
        latitude: 35.3192,
        longitude: 139.5503,
        unlockRadiusMeters: 200,
        gridIndex: 4
    ),
    QuestSpot(
        id: "yamashita_park",
        prefectureId: "kanagawa",
        name: "山下公園",
        englishName: "yamashita",
        areaName: "横浜",
        latitude: 35.4442,
        longitude: 139.6498,
        unlockRadiusMeters: 250,
        gridIndex: 5
    ),
    QuestSpot(
        id: "tsurugaoka_hachimangu",
        prefectureId: "kanagawa",
        name: "鶴岡八幡宮",
        englishName: "tsurugaoka",
        areaName: "鎌倉",
        latitude: 35.3261,
        longitude: 139.5565,
        unlockRadiusMeters: 250,
        gridIndex: 6
    ),
    QuestSpot(
        id: "hakone_shrine",
        prefectureId: "kanagawa",
        name: "箱根神社",
        englishName: "hakone",
        areaName: "箱根",
        latitude: 35.2056,
        longitude: 139.0256,
        unlockRadiusMeters: 300,
        gridIndex: 7
    ),
    QuestSpot(
        id: "hasedera",
        prefectureId: "kanagawa",
        name: "長谷寺",
        englishName: "hasedera",
        areaName: "鎌倉",
        latitude: 35.3127,
        longitude: 139.5332,
        unlockRadiusMeters: 250,
        gridIndex: 8
    ),
    QuestSpot(
        id: "enosui",
        prefectureId: "kanagawa",
        name: "新江ノ島水族館",
        englishName: "enosui",
        areaName: "湘南",
        latitude: 35.3100,
        longitude: 139.4801,
        unlockRadiusMeters: 250,
        gridIndex: 9
    ),
    QuestSpot(
        id: "hakone_ropeway",
        prefectureId: "kanagawa",
        name: "箱根ロープウェイ",
        englishName: "hakone",
        areaName: "箱根",
        latitude: 35.2407,
        longitude: 139.0203,
        unlockRadiusMeters: 300,
        gridIndex: 10
    ),
    QuestSpot(
        id: "owakudani",
        prefectureId: "kanagawa",
        name: "大涌谷",
        englishName: "owakudani",
        areaName: "箱根",
        latitude: 35.2444,
        longitude: 139.0197,
        unlockRadiusMeters: 300,
        gridIndex: 11
    )
]

// MARK: - Current UI Sample Data

let mockRecentPosts: [RecentQuestPost] = [
    RecentQuestPost(
        user: "haruka",
        location: "江の島",
        locationKey: "enoshima",
        date: "2026/05/24",
        timeAgo: "2日前",
        gradient: LinearGradient(
            colors: [
                .blue.opacity(0.65),
                .orange.opacity(0.55),
                .black.opacity(0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    RecentQuestPost(
        user: "sota",
        location: "みなとみらい",
        locationKey: "yokohama",
        date: "2026/05/22",
        timeAgo: "4日前",
        gradient: LinearGradient(
            colors: [
                .purple.opacity(0.55),
                .blue.opacity(0.55),
                .black.opacity(0.9)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
]

let mockPrefectures: [PrefectureMemory] = [
    PrefectureMemory(
        name: "神奈川",
        completed: 8,
        total: 24,
        completedPreviewCount: 4,
        remainingCount: 4,
        previewColors: [
            .blue.opacity(0.55),
            .green.opacity(0.45),
            .orange.opacity(0.55),
            .purple.opacity(0.50)
        ]
    ),
    PrefectureMemory(
        name: "東京",
        completed: 6,
        total: 30,
        completedPreviewCount: 4,
        remainingCount: 2,
        previewColors: [
            .red.opacity(0.45),
            .blue.opacity(0.48),
            .brown.opacity(0.55),
            .green.opacity(0.45)
        ]
    ),
    PrefectureMemory(
        name: "京都",
        completed: 10,
        total: 28,
        completedPreviewCount: 4,
        remainingCount: 6,
        previewColors: [
            .orange.opacity(0.60),
            .green.opacity(0.50),
            .yellow.opacity(0.42),
            .brown.opacity(0.55)
        ]
    ),
    PrefectureMemory(
        name: "北海道",
        completed: 5,
        total: 32,
        completedPreviewCount: 3,
        remainingCount: 2,
        previewColors: [
            .blue.opacity(0.48),
            .green.opacity(0.46),
            .orange.opacity(0.45)
        ]
    )
]

let mockKanagawaSpots: [MemorySpot] = [
    MemorySpot(
        name: "江の島海岸",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.blue.opacity(0.55), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "鎌倉大仏",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.green.opacity(0.55), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "赤レンガ倉庫",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.red.opacity(0.50), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "みなとみらい",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.purple.opacity(0.55), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "鎌倉駅",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.brown.opacity(0.55), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "山下公園",
        isUnlocked: false,
        color: LinearGradient(
            colors: [.black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "鶴岡八幡宮",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.green.opacity(0.45), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "箱根神社",
        isUnlocked: false,
        color: LinearGradient(
            colors: [.black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "長谷寺",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.orange.opacity(0.50), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "新江ノ島水族館",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.cyan.opacity(0.50), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "箱根ロープウェイ",
        isUnlocked: true,
        color: LinearGradient(
            colors: [.green.opacity(0.50), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    ),
    MemorySpot(
        name: "大涌谷",
        isUnlocked: false,
        color: LinearGradient(
            colors: [.black],
            startPoint: .top,
            endPoint: .bottom
        )
    )
]

let mockMapDots: [MapDot] = [
    MapDot(
        position: CGPoint(x: 208, y: 150),
        size: 8,
        isCompleted: false
    ),
    MapDot(
        position: CGPoint(x: 178, y: 230),
        size: 8,
        isCompleted: false
    ),
    MapDot(
        position: CGPoint(x: 192, y: 282),
        size: 12,
        isCompleted: false
    ),
    MapDot(
        position: CGPoint(x: 150, y: 300),
        size: 8,
        isCompleted: true
    ),
    MapDot(
        position: CGPoint(x: 133, y: 342),
        size: 8,
        isCompleted: false
    )
]

let mockKanagawaDots: [KanagawaDot] = [
    KanagawaDot(
        name: "江の島",
        position: CGPoint(x: 250, y: 340),
        size: 14,
        isCompleted: false
    ),
    KanagawaDot(
        name: "鎌倉",
        position: CGPoint(x: 220, y: 280),
        size: 10,
        isCompleted: true
    ),
    KanagawaDot(
        name: "横浜",
        position: CGPoint(x: 285, y: 220),
        size: 10,
        isCompleted: false
    ),
    KanagawaDot(
        name: "箱根",
        position: CGPoint(x: 90, y: 290),
        size: 10,
        isCompleted: false
    ),
    KanagawaDot(
        name: "川崎",
        position: CGPoint(x: 305, y: 175),
        size: 8,
        isCompleted: true
    )
]
let mockQuestMemoryPhotos: [QuestMemoryPhoto] = [
    QuestMemoryPhoto(
        id: "memory_enoshima_001",
        spotId: "enoshima_coast",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/24 15:42"
    ),
    QuestMemoryPhoto(
        id: "memory_kamakura_daibutsu_001",
        spotId: "kamakura_daibutsu",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/23 14:18"
    ),
    QuestMemoryPhoto(
        id: "memory_akarenga_001",
        spotId: "akarenga",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/21 19:08"
    ),
    QuestMemoryPhoto(
        id: "memory_minatomirai_001",
        spotId: "minatomirai",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/20 20:33"
    ),
    QuestMemoryPhoto(
        id: "memory_kamakura_station_001",
        spotId: "kamakura_station",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/19 16:05"
    ),
    QuestMemoryPhoto(
        id: "memory_tsurugaoka_001",
        spotId: "tsurugaoka_hachimangu",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/18 11:24"
    ),
    QuestMemoryPhoto(
        id: "memory_hasedera_001",
        spotId: "hasedera",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/17 13:48"
    ),
    QuestMemoryPhoto(
        id: "memory_enosui_001",
        spotId: "enosui",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/16 10:12"
    ),
    QuestMemoryPhoto(
        id: "memory_hakone_ropeway_001",
        spotId: "hakone_ropeway",
        prefectureId: "kanagawa",
        imageName: nil,
        createdAtText: "2026/05/15 15:30"
    )
]

// MARK: - Feed Sample Data

private func sampleDate(daysAgo: Int) -> Date {
    Calendar.current.date(
        byAdding: .day,
        value: -daysAgo,
        to: Date()
    ) ?? Date()
}

private func sampleExpireDate(daysFromNow: Int) -> Date {
    Calendar.current.date(
        byAdding: .day,
        value: daysFromNow,
        to: Date()
    ) ?? Date()
}

let mockQuestFeedPosts: [QuestFeedPost] = [
    QuestFeedPost(
        id: "feed_haruka_enoshima",
        userId: "user_haruka",
        username: "haruka",
        spotId: "enoshima_coast",
        prefectureId: "kanagawa",
        createdAt: sampleDate(daysAgo: 2),
        expiresAt: sampleExpireDate(daysFromNow: 5),
        displayDate: "2026/05/24",
        displayPlace: "enoshima",
        isMine: false
    ),
    QuestFeedPost(
        id: "feed_sota_minatomirai",
        userId: "user_sota",
        username: "sota",
        spotId: "minatomirai",
        prefectureId: "kanagawa",
        createdAt: sampleDate(daysAgo: 4),
        expiresAt: sampleExpireDate(daysFromNow: 3),
        displayDate: "2026/05/22",
        displayPlace: "minatomirai",
        isMine: false
    ),
    QuestFeedPost(
        id: "feed_keita_kamakura",
        userId: "user_keita",
        username: "you",
        spotId: "kamakura_daibutsu",
        prefectureId: "kanagawa",
        createdAt: sampleDate(daysAgo: 8),
        expiresAt: sampleDate(daysAgo: 1),
        displayDate: "2026/05/16",
        displayPlace: "kamakura",
        isMine: true
    )
]

// MARK: - Friend Sample Data

let mockQuestFriends: [QuestFriend] = [
    QuestFriend(
        id: "friend_haruka",
        userId: "user_haruka",
        username: "haruka_photo",
        displayName: "Haruka",
        recentPlace: "enoshima",
        lastSharedText: "2日前"
    ),
    QuestFriend(
        id: "friend_sota",
        userId: "user_sota",
        username: "sota_world",
        displayName: "Sota",
        recentPlace: "minatomirai",
        lastSharedText: "4日前"
    ),
    QuestFriend(
        id: "friend_aoi",
        userId: "user_aoi",
        username: "aoi_trip",
        displayName: "Aoi",
        recentPlace: "kamakura",
        lastSharedText: "5日前"
    )
]

let mockQuestFriendRequests: [QuestFriendRequest] = [
    QuestFriendRequest(
        id: "request_yuna",
        userId: "user_yuna",
        username: "yuna_japan",
        displayName: "Yuna",
        message: "フレンド申請が届いています",
        requestedAtText: "今日"
    ),
    QuestFriendRequest(
        id: "request_ren",
        userId: "user_ren",
        username: "ren_walk",
        displayName: "Ren",
        message: "フレンド申請が届いています",
        requestedAtText: "昨日"
    )
]
