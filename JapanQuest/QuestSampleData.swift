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
        gridIndex: 0,
        category: .nature
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
        gridIndex: 1,
        category: .landmark
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
        gridIndex: 2,
        category: .photogenic
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
        gridIndex: 3,
        category: .photogenic
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
        gridIndex: 4,
        category: .landmark
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
        gridIndex: 5,
        category: .nature
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
        gridIndex: 6,
        category: .landmark
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
        gridIndex: 7,
        category: .landmark
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
        gridIndex: 8,
        category: .landmark
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
        gridIndex: 9,
        category: .photogenic
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
        gridIndex: 10,
        category: .nature
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
        gridIndex: 11,
        category: .nature
    ),
    QuestSpot(
        id: "senshu_university_ikuta",
        prefectureId: "kanagawa",
        name: "専修大学",
        englishName: "senshu",
        areaName: "生田",
        latitude: 35.5985,
        longitude: 139.5432,
        unlockRadiusMeters: 250,
        gridIndex: 12,
        category: .landmark
    ),
    QuestSpot(
        id: "mukogaoka_yuen_station",
        prefectureId: "kanagawa",
        name: "向ヶ丘遊園駅",
        englishName: "mukogaoka",
        areaName: "向ヶ丘遊園",
        latitude: 35.6012,
        longitude: 139.5427,
        unlockRadiusMeters: 200,
        gridIndex: 13,
        category: .landmark
    ),
    QuestSpot(
        id: "noborito_station",
        prefectureId: "kanagawa",
        name: "登戸駅",
        englishName: "noborito",
        areaName: "登戸",
        latitude: 35.6142,
        longitude: 139.5773,
        unlockRadiusMeters: 200,
        gridIndex: 14,
        category: .landmark
    ),

    // MARK: 東京 (MapKit詳細Map汎用化の検証用サンプル。件数はMVP範囲に留める)
    QuestSpot(
        id: "sensoji_temple",
        prefectureId: "tokyo",
        name: "浅草寺",
        englishName: "asakusa",
        areaName: "浅草",
        latitude: 35.7148,
        longitude: 139.7967,
        unlockRadiusMeters: 250,
        gridIndex: 0,
        category: .landmark
    ),
    QuestSpot(
        id: "meiji_jingu",
        prefectureId: "tokyo",
        name: "明治神宮",
        englishName: "meijijingu",
        areaName: "原宿",
        latitude: 35.6764,
        longitude: 139.6993,
        unlockRadiusMeters: 300,
        gridIndex: 1,
        category: .nature
    ),
    QuestSpot(
        id: "shibuya_crossing",
        prefectureId: "tokyo",
        name: "渋谷スクランブル交差点",
        englishName: "shibuya",
        areaName: "渋谷",
        latitude: 35.6595,
        longitude: 139.7005,
        unlockRadiusMeters: 200,
        gridIndex: 2,
        category: .photogenic
    ),
    QuestSpot(
        id: "ueno_park",
        prefectureId: "tokyo",
        name: "上野公園",
        englishName: "ueno",
        areaName: "上野",
        latitude: 35.7156,
        longitude: 139.7745,
        unlockRadiusMeters: 300,
        gridIndex: 3,
        category: .nature
    ),
    QuestSpot(
        id: "tokyo_tower",
        prefectureId: "tokyo",
        name: "東京タワー",
        englishName: "tokyotower",
        areaName: "芝公園",
        latitude: 35.6586,
        longitude: 139.7454,
        unlockRadiusMeters: 250,
        gridIndex: 4,
        category: .landmark
    ),
    QuestSpot(
        id: "odaiba_marine_park",
        prefectureId: "tokyo",
        name: "お台場海浜公園",
        englishName: "odaiba",
        areaName: "お台場",
        latitude: 35.6267,
        longitude: 139.7746,
        unlockRadiusMeters: 300,
        gridIndex: 5,
        category: .photogenic
    ),
    QuestSpot(
        id: "roppongi_hills",
        prefectureId: "tokyo",
        name: "六本木ヒルズ展望台",
        englishName: "roppongi",
        areaName: "六本木",
        latitude: 35.6604,
        longitude: 139.7292,
        unlockRadiusMeters: 200,
        gridIndex: 6,
        category: .landmark
    ),
    QuestSpot(
        id: "yanaka_ginza",
        prefectureId: "tokyo",
        name: "谷中銀座商店街",
        englishName: "yanaka",
        areaName: "谷中",
        latitude: 35.7272,
        longitude: 139.7671,
        unlockRadiusMeters: 200,
        gridIndex: 7,
        category: .cafe
    ),
    QuestSpot(
        id: "kuramae_cafe_street",
        prefectureId: "tokyo",
        name: "蔵前のカフェ通り",
        englishName: "kuramae",
        areaName: "蔵前",
        latitude: 35.7075,
        longitude: 139.7930,
        unlockRadiusMeters: 200,
        gridIndex: 8,
        category: .cafe
    ),
    QuestSpot(
        id: "shinjuku_station",
        prefectureId: "tokyo",
        name: "新宿駅",
        englishName: "shinjuku",
        areaName: "新宿",
        latitude: 35.6896,
        longitude: 139.7006,
        unlockRadiusMeters: 250,
        gridIndex: 9,
        category: .landmark
    ),

    // MARK: 京都
    QuestSpot(
        id: "fushimi_inari",
        prefectureId: "kyoto",
        name: "伏見稲荷大社",
        englishName: "fushimiinari",
        areaName: "伏見",
        latitude: 34.9671,
        longitude: 135.7727,
        unlockRadiusMeters: 300,
        gridIndex: 0,
        category: .landmark
    ),
    QuestSpot(
        id: "kiyomizudera",
        prefectureId: "kyoto",
        name: "清水寺",
        englishName: "kiyomizu",
        areaName: "東山",
        latitude: 34.9949,
        longitude: 135.7850,
        unlockRadiusMeters: 250,
        gridIndex: 1,
        category: .landmark
    ),
    QuestSpot(
        id: "kinkakuji",
        prefectureId: "kyoto",
        name: "金閣寺",
        englishName: "kinkakuji",
        areaName: "北山",
        latitude: 35.0394,
        longitude: 135.7292,
        unlockRadiusMeters: 250,
        gridIndex: 2,
        category: .landmark
    ),
    QuestSpot(
        id: "arashiyama_bamboo",
        prefectureId: "kyoto",
        name: "嵐山竹林の道",
        englishName: "arashiyama",
        areaName: "嵐山",
        latitude: 35.0094,
        longitude: 135.6683,
        unlockRadiusMeters: 250,
        gridIndex: 3,
        category: .nature
    ),
    QuestSpot(
        id: "kamogawa_riverside",
        prefectureId: "kyoto",
        name: "鴨川沿いの散歩道",
        englishName: "kamogawa",
        areaName: "鴨川",
        latitude: 35.0116,
        longitude: 135.7681,
        unlockRadiusMeters: 300,
        gridIndex: 4,
        category: .nature
    ),
    QuestSpot(
        id: "gion_streets",
        prefectureId: "kyoto",
        name: "祇園の街並み",
        englishName: "gion",
        areaName: "祇園",
        latitude: 35.0037,
        longitude: 135.7752,
        unlockRadiusMeters: 200,
        gridIndex: 5,
        category: .photogenic
    ),
    QuestSpot(
        id: "philosophers_path",
        prefectureId: "kyoto",
        name: "哲学の道",
        englishName: "tetsugaku",
        areaName: "東山",
        latitude: 35.0272,
        longitude: 135.7947,
        unlockRadiusMeters: 250,
        gridIndex: 6,
        category: .photogenic
    ),
    QuestSpot(
        id: "ninenzaka_sannenzaka",
        prefectureId: "kyoto",
        name: "二年坂・産寧坂の石畳",
        englishName: "ninenzaka",
        areaName: "東山",
        latitude: 34.9977,
        longitude: 135.7809,
        unlockRadiusMeters: 200,
        gridIndex: 7,
        category: .photogenic
    ),
    QuestSpot(
        id: "nishiki_market",
        prefectureId: "kyoto",
        name: "錦市場",
        englishName: "nishiki",
        areaName: "中京",
        latitude: 35.0050,
        longitude: 135.7643,
        unlockRadiusMeters: 200,
        gridIndex: 8,
        category: .cafe
    ),
    QuestSpot(
        id: "kyotogyoen_machiya_cafe",
        prefectureId: "kyoto",
        name: "京都御苑近くの町家カフェ",
        englishName: "kyotogyoen",
        areaName: "京都御苑",
        latitude: 35.0254,
        longitude: 135.7622,
        unlockRadiusMeters: 200,
        gridIndex: 9,
        category: .cafe
    ),

    // MARK: 北海道 (範囲が広くなりすぎないよう札幌・小樽・富良野/美瑛に絞る)
    QuestSpot(
        id: "odori_park",
        prefectureId: "hokkaido",
        name: "大通公園",
        englishName: "odori",
        areaName: "札幌",
        latitude: 43.0596,
        longitude: 141.3467,
        unlockRadiusMeters: 300,
        gridIndex: 0,
        category: .nature
    ),
    QuestSpot(
        id: "sapporo_clock_tower",
        prefectureId: "hokkaido",
        name: "札幌時計台",
        englishName: "sapporo",
        areaName: "札幌",
        latitude: 43.0621,
        longitude: 141.3544,
        unlockRadiusMeters: 200,
        gridIndex: 1,
        category: .landmark
    ),
    QuestSpot(
        id: "hokkaido_jingu",
        prefectureId: "hokkaido",
        name: "北海道神宮",
        englishName: "hokkaidojingu",
        areaName: "札幌",
        latitude: 43.0531,
        longitude: 141.3086,
        unlockRadiusMeters: 250,
        gridIndex: 2,
        category: .landmark
    ),
    QuestSpot(
        id: "shiroikoibito_park",
        prefectureId: "hokkaido",
        name: "白い恋人パーク",
        englishName: "shiroikoibito",
        areaName: "札幌",
        latitude: 43.0759,
        longitude: 141.2892,
        unlockRadiusMeters: 200,
        gridIndex: 3,
        category: .photogenic
    ),
    QuestSpot(
        id: "mount_moiwa",
        prefectureId: "hokkaido",
        name: "藻岩山展望台",
        englishName: "moiwa",
        areaName: "札幌",
        latitude: 43.0338,
        longitude: 141.3200,
        unlockRadiusMeters: 300,
        gridIndex: 4,
        category: .nature
    ),
    QuestSpot(
        id: "otaru_canal",
        prefectureId: "hokkaido",
        name: "小樽運河",
        englishName: "otaru",
        areaName: "小樽",
        latitude: 43.1907,
        longitude: 141.0007,
        unlockRadiusMeters: 250,
        gridIndex: 5,
        category: .photogenic
    ),
    QuestSpot(
        id: "otaru_music_box_street",
        prefectureId: "hokkaido",
        name: "小樽オルゴール堂周辺のカフェ街",
        englishName: "otarucafe",
        areaName: "小樽",
        latitude: 43.1912,
        longitude: 141.0016,
        unlockRadiusMeters: 200,
        gridIndex: 6,
        category: .cafe
    ),
    QuestSpot(
        id: "farm_tomita",
        prefectureId: "hokkaido",
        name: "ファーム富田のラベンダー畑",
        englishName: "farmtomita",
        areaName: "富良野",
        latitude: 43.3389,
        longitude: 142.4636,
        unlockRadiusMeters: 300,
        gridIndex: 7,
        category: .nature
    ),
    QuestSpot(
        id: "blue_pond_biei",
        prefectureId: "hokkaido",
        name: "青い池",
        englishName: "aoiike",
        areaName: "美瑛",
        latitude: 43.4564,
        longitude: 142.6825,
        unlockRadiusMeters: 250,
        gridIndex: 8,
        category: .photogenic
    ),
    QuestSpot(
        id: "biei_hill_cafe",
        prefectureId: "hokkaido",
        name: "美瑛の丘のカフェ",
        englishName: "bieicafe",
        areaName: "美瑛",
        latitude: 43.4200,
        longitude: 142.6100,
        unlockRadiusMeters: 200,
        gridIndex: 9,
        category: .cafe
    ),

    // MARK: - Curated Spot Dataset Stage 4a(複数県プルーフ)
    // 座標はすべてweb検索で確認済み(2026年時点、出典は最終報告に記載)。
    // unlockRadiusMeatersは既存Spot(東京タワー等)と同じ既定値250mに揃え、
    // Spotごとの特別扱いをしない。神奈川の当初推奨3件(鎌倉大仏/江の島/
    // 横浜赤レンガ倉庫)は既存spot(kamakura_daibutsu/enoshima_coast/akarenga)と
    // 座標がほぼ一致し重複するため、差し替えて別の実在ランドマークにした。
    // 北海道の当初推奨2件(札幌時計台/大通公園)も既存spot(sapporo_clock_tower/
    // odori_park)と重複するため、函館エリアの別ランドマークへ差し替えた。

    // 神奈川(既存areaName「横浜」に2件追加、新規areaName「川崎」を1件追加)
    QuestSpot(
        id: "yokohama_chinatown",
        prefectureId: "kanagawa",
        name: "横浜中華街",
        englishName: "chinatown",
        areaName: "横浜",
        latitude: 35.443066,
        longitude: 139.644097,
        unlockRadiusMeters: 250,
        gridIndex: 15,
        category: .photogenic
    ),
    QuestSpot(
        id: "sankeien_garden",
        prefectureId: "kanagawa",
        name: "三溪園",
        englishName: "sankeien",
        areaName: "横浜",
        latitude: 35.417047,
        longitude: 139.658780,
        unlockRadiusMeters: 250,
        gridIndex: 16,
        category: .nature
    ),
    QuestSpot(
        id: "kawasaki_daishi",
        prefectureId: "kanagawa",
        name: "川崎大師",
        englishName: "kawasakidaishi",
        areaName: "川崎",
        latitude: 35.533820,
        longitude: 139.728887,
        unlockRadiusMeters: 250,
        gridIndex: 17,
        category: .landmark
    ),

    // 大阪(新規未訪問県、areaNameはSpotごとの周辺地区名)
    QuestSpot(
        id: "osaka_castle",
        prefectureId: "osaka",
        name: "大阪城天守閣",
        englishName: "osakacastle",
        areaName: "大阪城",
        latitude: 34.687383,
        longitude: 135.525824,
        unlockRadiusMeters: 250,
        gridIndex: 0,
        category: .landmark
    ),
    QuestSpot(
        id: "tsutenkaku_tower",
        prefectureId: "osaka",
        name: "通天閣",
        englishName: "tsutenkaku",
        areaName: "新世界",
        latitude: 34.652508,
        longitude: 135.506308,
        unlockRadiusMeters: 250,
        gridIndex: 1,
        category: .landmark
    ),
    QuestSpot(
        id: "dotonbori_glico",
        prefectureId: "osaka",
        name: "道頓堀グリコサイン",
        englishName: "dotonbori",
        areaName: "道頓堀",
        latitude: 34.668952,
        longitude: 135.501044,
        unlockRadiusMeters: 250,
        gridIndex: 2,
        category: .photogenic
    ),

    // 北海道(新規areaName「函館」、札幌/小樽/美瑛とは別エリア)
    QuestSpot(
        id: "mount_hakodate_observatory",
        prefectureId: "hokkaido",
        name: "函館山展望台",
        englishName: "hakodateyama",
        areaName: "函館",
        latitude: 41.760887,
        longitude: 140.714150,
        unlockRadiusMeters: 250,
        gridIndex: 10,
        category: .nature
    ),
    QuestSpot(
        id: "goryokaku_tower",
        prefectureId: "hokkaido",
        name: "五稜郭タワー",
        englishName: "goryokaku",
        areaName: "函館",
        latitude: 41.794637,
        longitude: 140.753902,
        unlockRadiusMeters: 250,
        gridIndex: 11,
        category: .landmark
    ),
    QuestSpot(
        id: "kanemori_akarenga",
        prefectureId: "hokkaido",
        name: "金森赤レンガ倉庫",
        englishName: "kanemori",
        areaName: "函館",
        latitude: 41.766904,
        longitude: 140.717765,
        unlockRadiusMeters: 250,
        gridIndex: 12,
        category: .photogenic
    ),
    // MARK: - PRODUCTION ROUND 5B「CHUGOKU RECOMMENDED SPOT CATALOG」
    // Round 5A-2〜5A-5のResearch Final Lock/Final Reportで confidence A かつ
    // APPROVED/Final Lock済みと確定したSpotのみを登録する。座標未確定・
    // confidence B・REVIEW状態のまま残っていたSpot(鳥取:投入堂遥拝所、
    // 島根:出雲そば荒木屋、山口:青海島)は今回のProduction登録から除外している
    // (Final Reportに明記済み、architectureとして数合わせのための追加は行わない)。

    // MARK: 鳥取県(11件)
    QuestSpot(
        id: "tottori_sand_dunes",
        prefectureId: "tottori",
        name: "鳥取砂丘",
        englishName: "tottori sand dunes",
        areaName: "鳥取市福部町",
        latitude: 35.542500,
        longitude: 134.230280,
        unlockRadiusMeters: 600,
        gridIndex: 0,
        category: .nature
    ),
    QuestSpot(
        id: "sand_museum",
        prefectureId: "tottori",
        name: "鳥取砂丘 砂の美術館",
        englishName: "sand museum",
        areaName: "鳥取市福部町",
        latitude: 35.539720,
        longitude: 134.238060,
        unlockRadiusMeters: 100,
        gridIndex: 1,
        category: .landmark
    ),
    QuestSpot(
        id: "uradome_coast",
        prefectureId: "tottori",
        name: "浦富海岸",
        englishName: "uradome coast",
        areaName: "岩美町田後",
        latitude: 35.592312,
        longitude: 134.304961,
        unlockRadiusMeters: 400,
        gridIndex: 2,
        category: .nature
    ),
    QuestSpot(
        id: "daisenji_temple",
        prefectureId: "tottori",
        name: "大山寺",
        englishName: "daisenji",
        areaName: "大山町",
        latitude: 35.390972,
        longitude: 133.534889,
        unlockRadiusMeters: 200,
        gridIndex: 3,
        category: .landmark
    ),
    QuestSpot(
        id: "hakuto_shrine",
        prefectureId: "tottori",
        name: "白兎神社",
        englishName: "hakuto shrine",
        areaName: "鳥取市白兎",
        latitude: 35.524170,
        longitude: 134.115420,
        unlockRadiusMeters: 150,
        gridIndex: 4,
        category: .landmark
    ),
    QuestSpot(
        id: "kurayoshi_shirakabe",
        prefectureId: "tottori",
        name: "倉吉白壁土蔵群",
        englishName: "kurayoshi shirakabe",
        areaName: "倉吉市",
        latitude: 35.432089,
        longitude: 133.825031,
        unlockRadiusMeters: 400,
        gridIndex: 5,
        category: .photogenic
    ),
    QuestSpot(
        id: "aoyama_gosho_furusatokan",
        prefectureId: "tottori",
        name: "青山剛昌ふるさと館",
        englishName: "gosho aoyama furusatokan",
        areaName: "北栄町",
        latitude: 35.498028,
        longitude: 133.761833,
        unlockRadiusMeters: 80,
        gridIndex: 6,
        category: .landmark
    ),
    QuestSpot(
        id: "mizuki_shigeru_road",
        prefectureId: "tottori",
        name: "水木しげるロード",
        englishName: "mizuki shigeru road",
        areaName: "境港市",
        latitude: 35.545350,
        longitude: 133.222868,
        unlockRadiusMeters: 150,
        gridIndex: 7,
        category: .photogenic
    ),
    QuestSpot(
        id: "mizuki_shigeru_museum",
        prefectureId: "tottori",
        name: "水木しげる記念館",
        englishName: "mizuki shigeru museum",
        areaName: "境港市",
        latitude: 35.546444,
        longitude: 133.231250,
        unlockRadiusMeters: 80,
        gridIndex: 8,
        category: .landmark
    ),
    QuestSpot(
        id: "ueda_shoji_museum",
        prefectureId: "tottori",
        name: "植田正治写真美術館",
        englishName: "ueda shoji museum of photography",
        areaName: "伯耆町",
        latitude: 35.389861,
        longitude: 133.435833,
        unlockRadiusMeters: 100,
        gridIndex: 9,
        category: .landmark
    ),
    QuestSpot(
        id: "tottori_prefectural_art_museum",
        prefectureId: "tottori",
        name: "鳥取県立美術館",
        englishName: "tottori prefectural museum of art",
        areaName: "倉吉市",
        latitude: 35.432428,
        longitude: 133.838918,
        unlockRadiusMeters: 120,
        gridIndex: 10,
        category: .landmark
    ),

    // MARK: 島根県(14件)
    QuestSpot(
        id: "izumo_taisha",
        prefectureId: "shimane",
        name: "出雲大社",
        englishName: "izumo taisha",
        areaName: "出雲市大社町",
        latitude: 35.401989,
        longitude: 132.685418,
        unlockRadiusMeters: 200,
        gridIndex: 0,
        category: .landmark
    ),
    QuestSpot(
        id: "inasa_no_hama",
        prefectureId: "shimane",
        name: "稲佐の浜",
        englishName: "inasa no hama",
        areaName: "出雲市大社町",
        latitude: 35.400806,
        longitude: 132.672139,
        unlockRadiusMeters: 300,
        gridIndex: 1,
        category: .nature
    ),
    QuestSpot(
        id: "izumo_hinomisaki_lighthouse",
        prefectureId: "shimane",
        name: "出雲日御碕灯台",
        englishName: "izumo hinomisaki lighthouse",
        areaName: "出雲市大社町日御碕",
        latitude: 35.433527,
        longitude: 132.629604,
        unlockRadiusMeters: 150,
        gridIndex: 2,
        category: .landmark
    ),
    QuestSpot(
        id: "matsue_castle",
        prefectureId: "shimane",
        name: "松江城",
        englishName: "matsue castle",
        areaName: "松江市",
        latitude: 35.475139,
        longitude: 133.050694,
        unlockRadiusMeters: 200,
        gridIndex: 3,
        category: .landmark
    ),
    QuestSpot(
        id: "shimane_art_museum",
        prefectureId: "shimane",
        name: "島根県立美術館",
        englishName: "shimane art museum",
        areaName: "松江市袖師町",
        latitude: 35.459639,
        longitude: 133.052583,
        unlockRadiusMeters: 150,
        gridIndex: 4,
        category: .landmark
    ),
    QuestSpot(
        id: "adachi_museum_of_art",
        prefectureId: "shimane",
        name: "足立美術館",
        englishName: "adachi museum of art",
        areaName: "安来市",
        latitude: 35.380028,
        longitude: 133.194139,
        unlockRadiusMeters: 150,
        gridIndex: 5,
        category: .landmark
    ),
    QuestSpot(
        id: "yuushien_garden",
        prefectureId: "shimane",
        name: "由志園",
        englishName: "yuushien garden",
        areaName: "松江市八束町",
        latitude: 35.490556,
        longitude: 133.175278,
        unlockRadiusMeters: 150,
        gridIndex: 6,
        category: .nature
    ),
    QuestSpot(
        id: "iwami_ginzan_omori",
        prefectureId: "shimane",
        name: "石見銀山（大森の町並み）",
        englishName: "iwami ginzan omori",
        areaName: "大田市大森町",
        latitude: 35.111788,
        longitude: 132.441338,
        unlockRadiusMeters: 500,
        gridIndex: 7,
        category: .photogenic
    ),
    QuestSpot(
        id: "tamatsukuri_onsen",
        prefectureId: "shimane",
        name: "玉造温泉",
        englishName: "tamatsukuri onsen",
        areaName: "松江市玉湯町",
        latitude: 35.417667,
        longitude: 133.009500,
        unlockRadiusMeters: 400,
        gridIndex: 8,
        category: .photogenic
    ),
    QuestSpot(
        id: "kuniga_coast_matengai",
        prefectureId: "shimane",
        name: "国賀海岸（摩天崖）",
        englishName: "kuniga coast matengai",
        areaName: "隠岐郡西ノ島町",
        latitude: 36.106778,
        longitude: 132.972944,
        unlockRadiusMeters: 600,
        gridIndex: 9,
        category: .nature
    ),
    QuestSpot(
        id: "taikodani_inari_shrine",
        prefectureId: "shimane",
        name: "太皷谷稲成神社",
        englishName: "taikodani inari shrine",
        areaName: "津和野町",
        latitude: 34.465417,
        longitude: 131.769170,
        unlockRadiusMeters: 120,
        gridIndex: 10,
        category: .landmark
    ),
    QuestSpot(
        id: "miho_shrine",
        prefectureId: "shimane",
        name: "美保神社",
        englishName: "miho shrine",
        areaName: "松江市美保関町",
        latitude: 35.562311,
        longitude: 133.306047,
        unlockRadiusMeters: 200,
        gridIndex: 11,
        category: .landmark
    ),
    QuestSpot(
        id: "yaegaki_shrine",
        prefectureId: "shimane",
        name: "八重垣神社",
        englishName: "yaegaki shrine",
        areaName: "松江市佐草町",
        latitude: 35.429028,
        longitude: 133.073694,
        unlockRadiusMeters: 150,
        gridIndex: 12,
        category: .landmark
    ),
    QuestSpot(
        id: "tsuwano_tonomachi_street",
        prefectureId: "shimane",
        name: "津和野 殿町通り",
        englishName: "tsuwano tonomachi street",
        areaName: "津和野町後田",
        latitude: 34.467274,
        longitude: 131.770884,
        unlockRadiusMeters: 120,
        gridIndex: 13,
        category: .photogenic
    ),

    // MARK: 岡山県(15件)
    QuestSpot(
        id: "okayama_korakuen",
        prefectureId: "okayama",
        name: "岡山後楽園",
        englishName: "okayama korakuen",
        areaName: "岡山市北区",
        latitude: 34.668125,
        longitude: 133.935139,
        unlockRadiusMeters: 180,
        gridIndex: 0,
        category: .nature
    ),
    QuestSpot(
        id: "okayama_castle",
        prefectureId: "okayama",
        name: "岡山城",
        englishName: "okayama castle",
        areaName: "岡山市北区",
        latitude: 34.665300,
        longitude: 133.936100,
        unlockRadiusMeters: 120,
        gridIndex: 1,
        category: .landmark
    ),
    QuestSpot(
        id: "kibitsu_shrine",
        prefectureId: "okayama",
        name: "吉備津神社",
        englishName: "kibitsu shrine",
        areaName: "岡山市北区",
        latitude: 34.670667,
        longitude: 133.850611,
        unlockRadiusMeters: 200,
        gridIndex: 2,
        category: .landmark
    ),
    QuestSpot(
        id: "kurashiki_bikan",
        prefectureId: "okayama",
        name: "倉敷美観地区",
        englishName: "kurashiki bikan historical quarter",
        areaName: "倉敷市中央",
        latitude: 34.595861,
        longitude: 133.771778,
        unlockRadiusMeters: 300,
        gridIndex: 3,
        category: .photogenic
    ),
    QuestSpot(
        id: "ohara_museum_of_art",
        prefectureId: "okayama",
        name: "大原美術館",
        englishName: "ohara museum of art",
        areaName: "倉敷市中央",
        latitude: 34.596110,
        longitude: 133.770560,
        unlockRadiusMeters: 60,
        gridIndex: 4,
        category: .landmark
    ),
    QuestSpot(
        id: "washuzan",
        prefectureId: "okayama",
        name: "鷲羽山",
        englishName: "washuzan",
        areaName: "倉敷市児島",
        latitude: 34.435478,
        longitude: 133.812447,
        unlockRadiusMeters: 200,
        gridIndex: 5,
        category: .nature
    ),
    QuestSpot(
        id: "bitchu_matsuyama_castle",
        prefectureId: "okayama",
        name: "備中松山城",
        englishName: "bitchu matsuyama castle",
        areaName: "高梁市",
        latitude: 34.809078,
        longitude: 133.622303,
        unlockRadiusMeters: 200,
        gridIndex: 6,
        category: .landmark
    ),
    QuestSpot(
        id: "fukiya_furusato_village",
        prefectureId: "okayama",
        name: "吹屋ふるさと村",
        englishName: "fukiya furusato village",
        areaName: "高梁市成羽町吹屋",
        latitude: 34.861361,
        longitude: 133.470528,
        unlockRadiusMeters: 300,
        gridIndex: 7,
        category: .photogenic
    ),
    QuestSpot(
        id: "nagi_moca",
        prefectureId: "okayama",
        name: "奈義町現代美術館",
        englishName: "nagi museum of contemporary art",
        areaName: "奈義町",
        latitude: 35.123944,
        longitude: 134.174944,
        unlockRadiusMeters: 100,
        gridIndex: 8,
        category: .landmark
    ),
    QuestSpot(
        id: "shizutani_school",
        prefectureId: "okayama",
        name: "旧閑谷学校",
        englishName: "shizutani school",
        areaName: "備前市",
        latitude: 34.796389,
        longitude: 134.219500,
        unlockRadiusMeters: 200,
        gridIndex: 9,
        category: .landmark
    ),
    QuestSpot(
        id: "saijo_inari",
        prefectureId: "okayama",
        name: "最上稲荷",
        englishName: "saijo inari",
        areaName: "岡山市北区",
        latitude: 34.708956,
        longitude: 133.833411,
        unlockRadiusMeters: 200,
        gridIndex: 10,
        category: .landmark
    ),
    QuestSpot(
        id: "oujigatake",
        prefectureId: "okayama",
        name: "王子が岳",
        englishName: "oujigatake",
        areaName: "玉野市",
        latitude: 34.461940,
        longitude: 133.882220,
        unlockRadiusMeters: 200,
        gridIndex: 11,
        category: .nature
    ),
    QuestSpot(
        id: "okayama_prefectural_art_museum",
        prefectureId: "okayama",
        name: "岡山県立美術館",
        englishName: "okayama prefectural museum of art",
        areaName: "岡山市北区天神町",
        latitude: 34.667780,
        longitude: 133.929720,
        unlockRadiusMeters: 150,
        gridIndex: 12,
        category: .landmark
    ),
    QuestSpot(
        id: "inujima_seirensho_art_museum",
        prefectureId: "okayama",
        name: "犬島精錬所美術館",
        englishName: "inujima seirensho art museum",
        areaName: "岡山市東区犬島",
        latitude: 34.563069,
        longitude: 134.105943,
        unlockRadiusMeters: 100,
        gridIndex: 13,
        category: .landmark
    ),
    QuestSpot(
        id: "kojima_jeans_street",
        prefectureId: "okayama",
        name: "児島ジーンズストリート",
        englishName: "kojima jeans street",
        areaName: "倉敷市児島味野",
        latitude: 34.469050,
        longitude: 133.802441,
        unlockRadiusMeters: 250,
        gridIndex: 14,
        category: .photogenic
    ),

    // MARK: 広島県(15件)
    QuestSpot(
        id: "itsukushima_shrine",
        prefectureId: "hiroshima",
        name: "嚴島神社",
        englishName: "itsukushima shrine",
        areaName: "廿日市市宮島町",
        latitude: 34.296527,
        longitude: 132.319007,
        unlockRadiusMeters: 150,
        gridIndex: 0,
        category: .landmark
    ),
    QuestSpot(
        id: "mount_misen",
        prefectureId: "hiroshima",
        name: "弥山",
        englishName: "mount misen",
        areaName: "廿日市市宮島町",
        latitude: 34.279592,
        longitude: 132.319611,
        unlockRadiusMeters: 300,
        gridIndex: 1,
        category: .nature
    ),
    QuestSpot(
        id: "atomic_bomb_dome",
        prefectureId: "hiroshima",
        // Design Note(将来UI実装時のみ有効): 原爆ドームは他のRecommended Spotと
        // 同じ達成演出(gold celebration/gamification/軽薄なwording)を使わない。
        // 静かなMemory/Visit表現に留めること。今回はmodelへ新しいfieldは追加しない。
        name: "原爆ドーム",
        englishName: "atomic bomb dome",
        areaName: "広島市中区",
        latitude: 34.395466,
        longitude: 132.453525,
        unlockRadiusMeters: 45,
        gridIndex: 2,
        category: .landmark
    ),
    QuestSpot(
        id: "hiroshima_peace_memorial_museum",
        prefectureId: "hiroshima",
        // Design Note: 原爆ドームと同様、静かなpresentationを維持すること。
        name: "広島平和記念資料館",
        englishName: "hiroshima peace memorial museum",
        areaName: "広島市中区",
        latitude: 34.391812,
        longitude: 132.452105,
        unlockRadiusMeters: 60,
        gridIndex: 3,
        category: .landmark
    ),
    QuestSpot(
        id: "orizuru_tower",
        prefectureId: "hiroshima",
        name: "おりづるタワー",
        englishName: "orizuru tower",
        areaName: "広島市中区",
        latitude: 34.395670,
        longitude: 132.454686,
        unlockRadiusMeters: 45,
        gridIndex: 4,
        category: .landmark
    ),
    QuestSpot(
        id: "shukkeien_garden",
        prefectureId: "hiroshima",
        name: "縮景園",
        englishName: "shukkeien garden",
        areaName: "広島市中区",
        latitude: 34.400338,
        longitude: 132.467449,
        unlockRadiusMeters: 150,
        gridIndex: 5,
        category: .nature
    ),
    QuestSpot(
        id: "hiroshima_castle",
        prefectureId: "hiroshima",
        name: "広島城",
        englishName: "hiroshima castle",
        areaName: "広島市中区",
        latitude: 34.402146,
        longitude: 132.459540,
        unlockRadiusMeters: 150,
        gridIndex: 6,
        category: .landmark
    ),
    QuestSpot(
        id: "senkoji_temple_park",
        prefectureId: "hiroshima",
        name: "千光寺・千光寺公園",
        englishName: "senkoji temple park",
        areaName: "尾道市",
        latitude: 34.410365,
        longitude: 133.198685,
        unlockRadiusMeters: 400,
        gridIndex: 7,
        category: .photogenic
    ),
    QuestSpot(
        id: "kosanji_museum",
        prefectureId: "hiroshima",
        name: "耕三寺博物館・未来心の丘",
        englishName: "kosanji museum",
        areaName: "尾道市瀬戸田町",
        latitude: 34.304386,
        longitude: 133.090396,
        unlockRadiusMeters: 150,
        gridIndex: 8,
        category: .landmark
    ),
    QuestSpot(
        id: "okunoshima",
        prefectureId: "hiroshima",
        name: "大久野島",
        englishName: "okunoshima",
        areaName: "竹原市",
        latitude: 34.306329,
        longitude: 132.991949,
        unlockRadiusMeters: 350,
        gridIndex: 9,
        category: .nature
    ),
    QuestSpot(
        id: "yamato_museum_kure",
        prefectureId: "hiroshima",
        name: "大和ミュージアム・呉市海事歴史科学館",
        englishName: "yamato museum",
        areaName: "呉市",
        latitude: 34.241185,
        longitude: 132.555880,
        unlockRadiusMeters: 150,
        gridIndex: 10,
        category: .landmark
    ),
    QuestSpot(
        id: "tomonoura",
        prefectureId: "hiroshima",
        name: "鞆の浦",
        englishName: "tomonoura",
        areaName: "福山市",
        latitude: 34.380877,
        longitude: 133.380327,
        unlockRadiusMeters: 300,
        gridIndex: 11,
        category: .photogenic
    ),
    QuestSpot(
        id: "shinshoji_zen_museum",
        prefectureId: "hiroshima",
        name: "神勝寺 禅と庭のミュージアム",
        englishName: "shinshoji zen museum",
        areaName: "福山市",
        latitude: 34.427126,
        longitude: 133.308951,
        unlockRadiusMeters: 150,
        gridIndex: 12,
        category: .landmark
    ),
    QuestSpot(
        id: "anagomeshi_ueno",
        prefectureId: "hiroshima",
        name: "あなごめし うえの",
        englishName: "anagomeshi ueno",
        areaName: "廿日市市宮島口",
        latitude: 34.311511,
        longitude: 132.303516,
        unlockRadiusMeters: 50,
        gridIndex: 13,
        category: .cafe
    ),
    QuestSpot(
        id: "micchan_sohonten",
        prefectureId: "hiroshima",
        name: "みっちゃん総本店",
        englishName: "micchan sohonten",
        areaName: "広島市中区八丁堀",
        latitude: 34.395786,
        longitude: 132.463591,
        unlockRadiusMeters: 50,
        gridIndex: 14,
        category: .cafe
    ),

    // MARK: 山口県(14件、青海島はconfidence Bのため今回除外)
    QuestSpot(
        id: "tsunoshima_bridge",
        prefectureId: "yamaguchi",
        name: "角島大橋",
        englishName: "tsunoshima bridge",
        areaName: "下関市豊北町",
        latitude: 34.347789,
        longitude: 130.895565,
        unlockRadiusMeters: 150,
        gridIndex: 0,
        category: .photogenic
    ),
    QuestSpot(
        id: "motonosumi_inari_shrine",
        prefectureId: "yamaguchi",
        name: "元乃隅神社",
        englishName: "motonosumi inari shrine",
        areaName: "長門市油谷津黄",
        latitude: 34.420083,
        longitude: 131.063169,
        unlockRadiusMeters: 200,
        gridIndex: 1,
        category: .landmark
    ),
    QuestSpot(
        id: "akiyoshido_cave",
        prefectureId: "yamaguchi",
        name: "秋芳洞",
        englishName: "akiyoshido cave",
        areaName: "美祢市",
        latitude: 34.228061,
        longitude: 131.303411,
        unlockRadiusMeters: 150,
        gridIndex: 2,
        category: .nature
    ),
    QuestSpot(
        id: "akiyoshidai_karst_plateau",
        prefectureId: "yamaguchi",
        name: "秋吉台",
        englishName: "akiyoshidai karst plateau",
        areaName: "美祢市",
        latitude: 34.234847,
        longitude: 131.304638,
        unlockRadiusMeters: 250,
        gridIndex: 3,
        category: .nature
    ),
    QuestSpot(
        id: "kintaikyo_bridge",
        prefectureId: "yamaguchi",
        name: "錦帯橋",
        englishName: "kintaikyo bridge",
        areaName: "岩国市",
        latitude: 34.167644,
        longitude: 132.178321,
        unlockRadiusMeters: 200,
        gridIndex: 4,
        category: .landmark
    ),
    QuestSpot(
        id: "karato_market",
        prefectureId: "yamaguchi",
        name: "唐戸市場",
        englishName: "karato market",
        areaName: "下関市唐戸町",
        latitude: 33.956625,
        longitude: 130.945817,
        unlockRadiusMeters: 80,
        gridIndex: 5,
        category: .landmark
    ),
    QuestSpot(
        id: "hagi_castle_jokamachi",
        prefectureId: "yamaguchi",
        name: "萩城跡・萩城下町",
        englishName: "hagi castle jokamachi",
        areaName: "萩市堀内",
        latitude: 34.417520,
        longitude: 131.383776,
        unlockRadiusMeters: 400,
        gridIndex: 6,
        category: .photogenic
    ),
    QuestSpot(
        id: "rurikoji_temple",
        prefectureId: "yamaguchi",
        name: "瑠璃光寺五重塔",
        englishName: "rurikoji five-story pagoda",
        areaName: "山口市",
        latitude: 34.189840,
        longitude: 131.471777,
        unlockRadiusMeters: 150,
        gridIndex: 7,
        category: .landmark
    ),
    QuestSpot(
        id: "shokasonjuku",
        prefectureId: "yamaguchi",
        name: "松下村塾",
        englishName: "shokasonjuku",
        areaName: "萩市椿東",
        latitude: 34.412144,
        longitude: 131.417335,
        unlockRadiusMeters: 150,
        gridIndex: 8,
        category: .landmark
    ),
    QuestSpot(
        id: "hagi_reverberatory_furnace",
        prefectureId: "yamaguchi",
        name: "萩反射炉",
        englishName: "hagi reverberatory furnace",
        areaName: "萩市椿東",
        latitude: 34.428203,
        longitude: 131.418279,
        unlockRadiusMeters: 100,
        gridIndex: 9,
        category: .landmark
    ),
    QuestSpot(
        id: "nagato_yumoto_onsen",
        prefectureId: "yamaguchi",
        name: "長門湯本温泉",
        englishName: "nagato yumoto onsen",
        areaName: "長門市深川湯本",
        latitude: 34.329157,
        longitude: 131.173563,
        unlockRadiusMeters: 350,
        gridIndex: 10,
        category: .photogenic
    ),
    QuestSpot(
        id: "hofu_tenmangu",
        prefectureId: "yamaguchi",
        name: "防府天満宮",
        englishName: "hofu tenmangu",
        areaName: "防府市",
        latitude: 34.063104,
        longitude: 131.574283,
        unlockRadiusMeters: 200,
        gridIndex: 11,
        category: .landmark
    ),
    QuestSpot(
        id: "shimonoseki_kaikyokan_aquarium",
        prefectureId: "yamaguchi",
        name: "海響館",
        englishName: "kaikyokan aquarium",
        areaName: "下関市",
        latitude: 33.954431,
        longitude: 130.942433,
        unlockRadiusMeters: 100,
        gridIndex: 12,
        category: .landmark
    ),
    QuestSpot(
        id: "iwakuni_castle",
        prefectureId: "yamaguchi",
        name: "岩国城",
        englishName: "iwakuni castle",
        areaName: "岩国市",
        latitude: 34.175249,
        longitude: 132.174270,
        unlockRadiusMeters: 150,
        gridIndex: 13,
        category: .landmark
    ),
    // MARK: - HYOGO FAST-TRACK PRODUCTION ROUND「兵庫県 Recommended Spot Catalog」
    // 2026年9月時点でOfficial Source + 独立地理情報源(OSM/Nominatim)により
    // confidence Aで確定したSpotのみ登録。淡路うずしお(船上GPSの不安定さを懸念し
    // viewpoint未確定のため今回は見送り)、丹波篠山城下町(座標が観光案内板の
    // ジオコードのみでconfidence不足)、食(神戸牛/明石焼/出石そば、個別店舗を
    // 十分に検証できなかったため0件)は今回のProduction登録から除外している。
    QuestSpot(
        id: "himeji_castle",
        prefectureId: "hyogo",
        name: "姫路城・好古園",
        englishName: "himeji castle",
        areaName: "姫路市",
        latitude: 34.839331,
        longitude: 134.694020,
        unlockRadiusMeters: 250,
        gridIndex: 0,
        category: .landmark
    ),
    QuestSpot(
        id: "shoshazan_engyoji",
        prefectureId: "hyogo",
        name: "書寫山 圓教寺",
        englishName: "shoshazan engyoji",
        areaName: "姫路市書写",
        latitude: 34.888771,
        longitude: 134.659092,
        unlockRadiusMeters: 200,
        gridIndex: 1,
        category: .landmark
    ),
    QuestSpot(
        id: "takeda_castle_ruins",
        prefectureId: "hyogo",
        name: "竹田城跡",
        englishName: "takeda castle ruins",
        areaName: "朝来市和田山町",
        latitude: 35.298898,
        longitude: 134.835899,
        unlockRadiusMeters: 250,
        gridIndex: 2,
        category: .landmark
    ),
    QuestSpot(
        id: "kinosaki_onsen",
        prefectureId: "hyogo",
        name: "城崎温泉",
        englishName: "kinosaki onsen",
        areaName: "豊岡市城崎町",
        latitude: 35.626162,
        longitude: 134.809533,
        unlockRadiusMeters: 350,
        gridIndex: 3,
        category: .photogenic
    ),
    QuestSpot(
        id: "genbudo_cave",
        prefectureId: "hyogo",
        name: "玄武洞",
        englishName: "genbudo cave",
        areaName: "豊岡市",
        latitude: 35.588199,
        longitude: 134.804843,
        unlockRadiusMeters: 150,
        gridIndex: 4,
        category: .nature
    ),
    QuestSpot(
        id: "izushi_castle_town",
        prefectureId: "hyogo",
        name: "出石城下町",
        englishName: "izushi castle town",
        areaName: "豊岡市出石町",
        latitude: 35.462164,
        longitude: 134.874339,
        unlockRadiusMeters: 250,
        gridIndex: 5,
        category: .photogenic
    ),
    QuestSpot(
        id: "arima_onsen",
        prefectureId: "hyogo",
        name: "有馬温泉",
        englishName: "arima onsen",
        areaName: "神戸市北区",
        latitude: 34.796786,
        longitude: 135.247933,
        unlockRadiusMeters: 350,
        gridIndex: 6,
        category: .photogenic
    ),
    QuestSpot(
        id: "kitano_ijinkan",
        prefectureId: "hyogo",
        name: "北野異人館街",
        englishName: "kitano ijinkan district",
        areaName: "神戸市中央区北野町",
        latitude: 34.701260,
        longitude: 135.189732,
        unlockRadiusMeters: 300,
        gridIndex: 7,
        category: .photogenic
    ),
    QuestSpot(
        id: "nankinmachi",
        prefectureId: "hyogo",
        name: "南京町",
        englishName: "nankinmachi",
        areaName: "神戸市中央区",
        latitude: 34.688107,
        longitude: 135.188382,
        unlockRadiusMeters: 150,
        gridIndex: 8,
        category: .photogenic
    ),
    QuestSpot(
        id: "meriken_park_port_tower",
        prefectureId: "hyogo",
        name: "メリケンパーク・神戸ポートタワー",
        englishName: "meriken park kobe port tower",
        areaName: "神戸市中央区",
        latitude: 34.683309,
        longitude: 135.189321,
        unlockRadiusMeters: 200,
        gridIndex: 9,
        category: .landmark
    ),
    QuestSpot(
        id: "mount_maya_kikuseidai",
        prefectureId: "hyogo",
        name: "摩耶山 掬星台",
        englishName: "mount maya kikuseidai",
        areaName: "神戸市灘区",
        latitude: 34.733950,
        longitude: 135.206696,
        unlockRadiusMeters: 200,
        gridIndex: 10,
        category: .nature
    ),
    QuestSpot(
        id: "awaji_yumebutai",
        prefectureId: "hyogo",
        name: "淡路夢舞台",
        englishName: "awaji yumebutai",
        areaName: "淡路市",
        latitude: 34.560976,
        longitude: 135.006881,
        unlockRadiusMeters: 150,
        gridIndex: 11,
        category: .landmark
    ),
    QuestSpot(
        id: "awaji_hanasajiki",
        prefectureId: "hyogo",
        name: "あわじ花さじき",
        englishName: "awaji hanasajiki",
        areaName: "淡路市",
        latitude: 34.552914,
        longitude: 134.978836,
        unlockRadiusMeters: 300,
        gridIndex: 12,
        category: .nature
    ),
    QuestSpot(
        id: "izanagi_jingu",
        prefectureId: "hyogo",
        name: "伊弉諾神宮",
        englishName: "izanagi jingu",
        areaName: "淡路市多賀",
        latitude: 34.459676,
        longitude: 134.852707,
        unlockRadiusMeters: 150,
        gridIndex: 13,
        category: .landmark
    ),
    QuestSpot(
        id: "maiko_park_akashi_kaikyo",
        prefectureId: "hyogo",
        name: "舞子公園・明石海峡大橋",
        englishName: "maiko park akashi kaikyo bridge",
        areaName: "神戸市垂水区",
        latitude: 34.631657,
        longitude: 135.035613,
        unlockRadiusMeters: 200,
        gridIndex: 14,
        category: .landmark
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
