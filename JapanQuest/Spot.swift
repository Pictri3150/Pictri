import Foundation

struct Spot: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let area: String
    let description: String
    let latitude: Double
    let longitude: Double
    let unlockRadiusMeters: Double
    let stampText: String
}

let sampleSpots: [Spot] = [
    Spot(
        id: "enoshima",
        name: "江の島",
        area: "湘南",
        description: "海・夕日・神社・食べ歩きが楽しめる神奈川を代表する観光スポット。",
        latitude: 35.2996,
        longitude: 139.4807,
        unlockRadiusMeters: 250,
        stampText: "ENOSHIMA"
    ),
    Spot(
        id: "kamakura_daibutsu",
        name: "鎌倉大仏",
        area: "鎌倉",
        description: "鎌倉を象徴する大仏。海外旅行者にも人気の歴史スポット。",
        latitude: 35.3167,
        longitude: 139.5358,
        unlockRadiusMeters: 250,
        stampText: "KAMAKURA"
    ),
    Spot(
        id: "akarenga",
        name: "横浜赤レンガ倉庫",
        area: "横浜",
        description: "横浜らしい港町の雰囲気が残る人気スポット。",
        latitude: 35.4526,
        longitude: 139.6428,
        unlockRadiusMeters: 250,
        stampText: "YOKOHAMA"
    ),
    Spot(
        id: "minatomirai",
        name: "みなとみらい",
        area: "横浜",
        description: "夜景・ショッピング・海沿いの散歩が楽しめる都市型観光地。",
        latitude: 35.4579,
        longitude: 139.6323,
        unlockRadiusMeters: 300,
        stampText: "MINATOMIRAI"
    ),
    Spot(
        id: "kawasaki_daishi",
        name: "川崎大師",
        area: "川崎",
        description: "参道の食べ歩きと歴史ある寺院が魅力の川崎を代表するスポット。",
        latitude: 35.5356,
        longitude: 139.7295,
        unlockRadiusMeters: 250,
        stampText: "KAWASAKI"
    )
]
