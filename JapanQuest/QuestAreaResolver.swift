import CoreLocation
import MapKit

/// Anywhere Capture Phase「Spot Unlock Architecture」で追加。
/// 「現在地はどの都道府県か」を、Spotのunlock radius内にいない場合でも解決するための
/// 唯一の場所。独自のポリゴン判定やEuclidean距離への退化はせず、標準の
/// `CLGeocoder`(逆ジオコーディング)を再利用する(Design原則「既存の標準APIがあれば
/// 再利用する」に準拠)。
///
/// 将来の韓国対応(2026年8月31日のユーザー渡航に向けた布石、ただし今回はJapan以外
/// 未実装)に備え、`isoCountryCode`の判定をこの1箇所へ集約している。国コード分岐を
/// 増やす時はここだけを見ればよい。
struct QuestResolvedArea: Equatable {
    let countryCode: String
    let prefectureId: String
    let areaName: String
}

enum QuestAreaResolver {
    /// CLGeocoderはiOS 26で非推奨(MKReverseGeocodingRequestへの置き換えが標準)。
    /// 「既存の標準APIを再利用する、独自実装へ退化しない」という方針に従い、
    /// このSDKの現行標準であるMKReverseGeocodingRequestを使う。既存コードベースの
    /// 呼び出し規約(completion handler、cameraService.capturePhoto等と同じ形)に
    /// 合わせるため、内部でTaskを起こしてasync/awaitをラップする。
    static func resolveArea(
        for location: CLLocation,
        completion: @escaping (QuestResolvedArea?) -> Void
    ) {
        Task {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                completion(nil)
                return
            }

            guard let mapItem = try? await request.mapItems.first else {
                completion(nil)
                return
            }

            let placemark = legacyPlacemark(from: mapItem)

            guard let countryCode = placemark.isoCountryCode else {
                completion(nil)
                return
            }

            // 今回はJapan(JP)のみ対応。将来ここへ"KR"分岐を追加する想定だが、
            // 今回のPhaseでは実装しない(Architectureを塞がないことだけが目的)。
            guard countryCode == "JP" else {
                completion(nil)
                return
            }

            guard let prefectureId = matchPrefectureId(administrativeArea: placemark.administrativeArea) else {
                completion(nil)
                return
            }

            let areaName = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.name
                ?? "現在地"

            completion(
                QuestResolvedArea(
                    countryCode: countryCode,
                    prefectureId: prefectureId,
                    areaName: areaName
                )
            )
        }
    }

    /// MKMapItem.placemarkはiOS 26で非推奨。置き換え先のMKAddress/
    /// MKAddressRepresentationsは整形済みの住所文字列(fullAddress/shortAddress等)
    /// しか提供せず、administrativeArea/isoCountryCode/localityのような構造化
    /// フィールドを持たない。Spot/Area unlockの正確性を左右する位置検証という
    /// 用途上、ロケール依存の文字列パースへ退化させるより、意図的にこの1箇所へ
    /// 隔離した上でplacemarkを使い続ける方が安全と判断した(最終報告に明記)。
    @available(*, deprecated, message: "MKMapItem.placemark(非推奨)を意図的に隔離して使用する箇所。理由はコード内コメント参照。")
    private static func legacyPlacemark(from mapItem: MKMapItem) -> CLPlacemark {
        mapItem.placemark
    }

    /// CLPlacemark.administrativeAreaは端末のlocale/region設定によって
    /// 「神奈川県」(漢字+接尾辞)や「Kanagawa」(ローマ字、接尾辞なし)など表記が揺れる。
    /// questPrefectureShapes(QuestMapGeoData.swift、47都道府県ぶん既存)を
    /// Source of Truthとして両方の表記を試す。北海道だけ「道」を漢字名に含めて
    /// 保持している(shape.name == "北海道")ため、接尾辞除去の対象から意図的に外す。
    private static func matchPrefectureId(administrativeArea: String?) -> String? {
        guard let administrativeArea else { return nil }
        let trimmed = administrativeArea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var kanjiCandidate = trimmed
        for suffix in ["県", "都", "府"] {
            if kanjiCandidate.hasSuffix(suffix) {
                kanjiCandidate = String(kanjiCandidate.dropLast())
                break
            }
        }

        if let match = questPrefectureShapes.first(where: { $0.name == trimmed || $0.name == kanjiCandidate }) {
            return match.id
        }

        var romaji = trimmed.lowercased()
        if romaji.hasSuffix(" prefecture") {
            romaji = String(romaji.dropLast(" prefecture".count))
        }
        romaji = romaji.trimmingCharacters(in: .whitespacesAndNewlines)

        return questPrefectureShapes.first(where: { $0.id == romaji })?.id
    }
}
