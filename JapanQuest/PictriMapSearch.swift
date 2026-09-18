import SwiftUI
import MapKit
import Combine

// MARK: - MAP ROUND 3 — Search Entry
//
// STEP 4「SEARCH ENTRY」: Native MapKit(`MKLocalSearchCompleter`/`MKLocalSearch`)
// のみを使う。新規Package依存・API keyは追加しない。国/都市/駅/エリア/一般地点を
// Apple側のcompletion、PicTri Recommended Spotは既存`mockQuestSpots`をローカルで
// 名前一致検索し、2つの結果列を視覚的に区別して1つのリストへまとめる
// (新しいSpot検索インデックス基盤は作らない、既存配列を都度filterするだけ)。

/// `MKLocalSearchCompleter`はdelegateベースのため、SwiftUIから使いやすい
/// ObservableObjectへ薄くラップする。新しいSpot検索ロジックはここに置かず、
/// あくまでApple自身の地名/POI補完だけを担当する。
@MainActor
final class PictriMapSearchCompleter: NSObject, ObservableObject {
    @Published private(set) var completions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func updateQuery(_ text: String, region: MKCoordinateRegion?) {
        if let region {
            completer.region = region
        }
        completer.queryFragment = text
    }

    func clear() {
        completer.queryFragment = ""
        completions = []
    }

    /// 選択されたcompletionを実際の座標を持つ`MKMapItem`へ解決する。
    /// Round 3では検索結果1件目だけを使う(route/複数候補比較は今回のscope外)。
    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        return try? await search.start().mapItems.first
    }
}

extension PictriMapSearchCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.completions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.completions = []
        }
    }
}

/// STEP 4: PicTri Recommended Spotのローカル検索。新しいSpot検索indexは作らず、
/// 既存`mockQuestSpots`(将来数百〜数千件になっても、この関数はO(n)のfilterのみ)を
/// 名前・エリア名・英語名で部分一致させるだけ。
enum PictriMapSpotSearch {
    static func matches(for query: String) -> [QuestSpot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return Array(
            mockQuestSpots
                .filter {
                    $0.name.lowercased().contains(lower)
                        || $0.areaName.lowercased().contains(lower)
                        || $0.englishName.lowercased().contains(lower)
                }
                .prefix(5)
        )
    }
}

// MARK: - Search bar (compact floating capsule)

/// STEP「SEARCH UI」: 巨大Search Barを常時表示しない。虫眼鏡+placeholderの
/// compact floating capsule。focus時のみごく小さくlavender accentを足す。
struct PictriMapSearchBar: View {
    @Binding var query: String
    var isActive: Bool
    var isFocused: FocusState<Bool>.Binding
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? PictriHomeBrandAccent.accent : Color.white.opacity(0.55))

            TextField(
                "",
                text: $query,
                prompt: Text("場所やスポットを検索").foregroundStyle(Color.white.opacity(0.42))
            )
            .focused(isFocused)
            .font(PictriTypography.body(13, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.92))
            .tint(PictriHomeBrandAccent.accent)
            .submitLabel(.search)

            if isActive && !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("検索をクリア")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background {
            Capsule()
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.85))
                .overlay {
                    Capsule().strokeBorder(
                        isActive ? PictriHomeBrandAccent.accent.opacity(0.55) : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
                }
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .accessibilityLabel("場所やスポットを検索")
    }
}

// MARK: - Search results overlay

enum PictriMapSearchResult: Identifiable {
    case spot(QuestSpot)
    case place(MKLocalSearchCompletion)

    var id: String {
        switch self {
        case .spot(let spot): return "spot_\(spot.id)"
        case .place(let completion): return "place_\(completion.title)_\(completion.subtitle)"
        }
    }
}

/// STEP「SEARCH PRESENTATION」: PicTri Recommended Spotの結果は先頭にまとめ、
/// lavenderの星+「おすすめ」で一般地点(Apple completion)と視覚的に区別する。
struct PictriMapSearchResultsList: View {
    let spots: [QuestSpot]
    let completions: [MKLocalSearchCompletion]
    let onSelectSpot: (QuestSpot) -> Void
    let onSelectPlace: (MKLocalSearchCompletion) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(spots) { spot in
                    Button {
                        onSelectSpot(spot)
                    } label: {
                        row(
                            icon: "star.fill",
                            iconTint: PictriHomeBrandAccent.accent,
                            title: spot.name,
                            subtitle: spot.areaName,
                            badge: "おすすめ"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Color.white.opacity(0.08))
                }

                ForEach(completions, id: \.self) { completion in
                    Button {
                        onSelectPlace(completion)
                    } label: {
                        row(
                            icon: "mappin",
                            iconTint: Color.white.opacity(0.55),
                            title: completion.title,
                            subtitle: completion.subtitle.isEmpty ? nil : completion.subtitle,
                            badge: nil
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(Color.white.opacity(0.08))
                }

                if spots.isEmpty && completions.isEmpty {
                    Text("見つかりませんでした")
                        .font(PictriTypography.body(12.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxHeight: 280)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }

    private func row(icon: String, iconTint: Color, title: String, subtitle: String?, badge: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(PictriTypography.body(13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(PictriTypography.body(9.5, weight: .bold))
                            .foregroundStyle(PictriHomeBrandAccent.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                Capsule().strokeBorder(PictriHomeBrandAccent.accent.opacity(0.5), lineWidth: 1)
                            }
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(PictriTypography.body(11.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
