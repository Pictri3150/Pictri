import Foundation

// MARK: - Vlog Day grouping
//
// Vlog対象は「Pictriで現地撮影して、その日に保存されたMemory」のみ(camera roll全体
// から選ぶgeneric AI video editorにはしない、という今回のProduct方針)。
// QuestMemoryStore.memoryPhotosをdevice local dayでグルーピングするだけの表示用集約で、
// 新しい永続データは持たない(MemoryをVlog用に別保存しない=二重source of truthを作らない)。
struct VlogDay: Identifiable {
    let dateKey: String
    let date: Date
    /// 撮影が古い順(=story順)。プレイヤーはこの並びのまま再生する。
    let photos: [QuestMemoryPhoto]

    var id: String { dateKey }
}

enum QuestVlogDayGrouping {
    private static func dayKeyFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func timestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }

    /// 新しい日が先頭に来る順で、日ごとにグルーピングする。各日の中の写真は撮影が
    /// 古い順(story順)に並べ直す(memoryStore.memoryPhotos自体は新しい順に保存されて
    /// いるため、Vlogとして再生する時だけ向きを変える)。
    static func groupedByDay(_ photos: [QuestMemoryPhoto]) -> [VlogDay] {
        let dayKeyFmt = dayKeyFormatter()
        let timeFmt = timestampFormatter()

        var byKey: [String: (date: Date, photos: [QuestMemoryPhoto])] = [:]
        var order: [String] = []

        for photo in photos {
            guard let timestamp = timeFmt.date(from: photo.createdAtText) else { continue }
            let key = dayKeyFmt.string(from: timestamp)
            if byKey[key] == nil {
                byKey[key] = (timestamp, [])
                order.append(key)
            }
            byKey[key]?.photos.append(photo)
        }

        return order.compactMap { key in
            guard let entry = byKey[key] else { return nil }
            let chronological = entry.photos.sorted { lhs, rhs in
                guard let l = timeFmt.date(from: lhs.createdAtText),
                      let r = timeFmt.date(from: rhs.createdAtText) else { return false }
                return l < r
            }
            return VlogDay(dateKey: key, date: entry.date, photos: chronological)
        }
    }

    static func todayKey(referenceDate: Date = Date()) -> String {
        dayKeyFormatter().string(from: referenceDate)
    }
}

// MARK: - Vlog generation service boundary
//
// FREE = local deterministic generator(乱数を使わない、決定論的な並び・尺)。
// PREMIUM = 将来のAI生成の入れ物(protocolだけ用意し、今回は外部AI API・API key・
// 依存ライブラリを一切追加しない)。呼び出し側(PictriVlogSectionView等)は
// generator.makeScript(for:)がnilを返せば「未生成」として扱い、生成できたふりの
// UIを一切出さない。

struct PictriVlogScript: Identifiable {
    struct Scene: Identifiable {
        let id: String
        let photo: QuestMemoryPhoto
        let spot: QuestSpot?
        let duration: TimeInterval
    }

    let day: VlogDay
    let scenes: [Scene]

    var id: String { day.id }
}

protocol PictriVlogGenerating {
    /// nilは「対象Memoryが無い」等の正当な理由のみ。生成ロジック自体が未実装の場合も
    /// nilを返す(呼び出し側がtier別にCTA文言を出し分けるだけで、fake resultは作らない)。
    func makeScript(for day: VlogDay) -> PictriVlogScript?
}

/// FREE/PREMIUM共通の「今すぐ実在するVlog」を作る生成器。1枚からでも成立する
/// (Design方針「1枚でも簡易Vlogは成立してよい」)。並び順=撮影順、尺は固定ルールで
/// 決定論的に決まるため、同じ日のスクリプトは再生成しても常に同じ結果になる。
struct LocalDeterministicVlogGenerator: PictriVlogGenerating {
    static let sceneDuration: TimeInterval = 2.6

    func makeScript(for day: VlogDay) -> PictriVlogScript? {
        guard !day.photos.isEmpty else { return nil }
        let scenes = day.photos.map { photo in
            PictriVlogScript.Scene(
                id: photo.id,
                photo: photo,
                spot: mockQuestSpots.first { $0.id == photo.spotId },
                duration: Self.sceneDuration
            )
        }
        return PictriVlogScript(day: day, scenes: scenes)
    }
}

/// PREMIUMが将来接続する先のAI生成器。今回のセッションでは外部AI API・API key・
/// 新規dependencyを一切追加していないため、常にnilを返す(未実装であることを
/// 呼び出し側が正しく扱えるようにするための、意図的なプレースホルダー実装)。
struct PremiumAIVlogGenerator: PictriVlogGenerating {
    func makeScript(for day: VlogDay) -> PictriVlogScript? {
        // TODO: 実際のAIサービスに接続する(今回スコープ外)。
        nil
    }
}
