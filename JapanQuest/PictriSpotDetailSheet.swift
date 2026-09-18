import SwiftUI
import UIKit

// MARK: - MAP ROUND 4 — Recommended Spot Detail
//
// Product Goal(spec): 「観光地情報カード」ではなく、
// Discover → 魅力確認 → 達成有無 → 撮影可否 → Camera、という
// PicTri独自のSpot Discovery Flowの核。情報を大量に並べない
// (Wikipedia・レビュー点数・ランキング・広告・ホテル・AI itinerary・
// 大量タグは持たない)。
//
// STEP 2「SPOT DETAIL ARCHITECTURE」: 大規模NavigationStack再設計は行わず、
// 既存のMap画面へ`.sheet(item:)`(medium/large detent)として追加するだけ。
// 閉じれば同じMap camera・同じselected markerへ戻る(sheetは背後のMapを
// 破棄しない、標準的なmodal presentationのため)。

/// STEP 6「CAPTURE ELIGIBILITY」。既存の達成判定(`QuestMemoryStore.hasMemory`)・
/// 位置判定(`QuestLocationManager.isNear`)をそのまま利用して導出するだけの
/// 表示用状態で、新しい達成ロジックや保存経路は一切持たない。
enum PictriSpotCaptureEligibility {
    case completed
    case insideRange
    case outsideRange(distanceText: String?)
    case locationUnavailable
}

struct PictriSpotDetailSheet: View {
    let spot: QuestSpot
    let prefectureName: String
    let prefectureProgress: PrefectureProgress
    let hasMemory: Bool
    let representativeImage: UIImage?
    let eligibility: PictriSpotCaptureEligibility
    let onCapture: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                heroPhoto

                VStack(alignment: .leading, spacing: 10) {
                    recommendedLabel

                    Text(spot.name)
                        .font(PictriTypography.display(22))
                        .foregroundStyle(PictriFinalTheme.ink)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PictriDarkTheme.textFaint)
                        Text("\(prefectureName) ・ \(spot.areaName)")
                            .font(PictriTypography.body(13, weight: .semibold))
                            .foregroundStyle(PictriDarkTheme.textFaint)
                    }
                }

                PictriHairline()

                prefectureProgressRow

                PictriHairline()

                captureSection
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .background(PictriDarkTheme.surfaceBase.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Photo (STEP 4「PHOTO FIRST」)

    /// 達成済みなら実際のMemory写真をhero自体として見せる(=STEP9「この場所の
    /// 思い出」を、複製の別サムネイルを増やさずPhoto-firstの原則のまま満たす)。
    /// 未達成でPhoto無しの場合は、既存Card/Homeと同じ処方のintentional dark
    /// placeholder(単なるgray rectangle/巨大アイコンにしない)。
    @ViewBuilder
    private var heroPhoto: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let representativeImage {
                    Image(uiImage: representativeImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [PictriHomeCardTheme.placeholderTop, PictriHomeCardTheme.placeholderBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        RadialGradient(
                            colors: [Color.white.opacity(0.07), Color.clear],
                            center: UnitPoint(x: 0.5, y: 0.38),
                            startRadius: 8,
                            endRadius: 160
                        )
                        Image(systemName: "photo")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.22))
                    }
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }

            if hasMemory {
                completedBadge
                    .padding(10)
            }
        }
    }

    /// STEP 5「SPOT STATUS」: Spot単体の達成はlavenderの控えめなcheckのみ。
    /// Goldは県コンプリート専用のため、ここでは絶対に使わない。
    private var completedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
            Text("達成済み")
                .font(PictriTypography.body(10.5, weight: .bold))
        }
        .foregroundStyle(PictriHomeBrandAccent.onAccent)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule().fill(PictriHomeBrandAccent.accent)
        }
    }

    private var recommendedLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: hasMemory ? "checkmark.seal.fill" : "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(hasMemory ? "この場所の思い出" : "PicTriおすすめスポット")
                .font(PictriTypography.body(11, weight: .bold))
        }
        .foregroundStyle(PictriHomeBrandAccent.accent)
    }

    // MARK: - Prefecture progress (STEP 10)

    /// 「東京都 おすすめ 3/12」程度の小さな1行のみ。巨大dashboardにしない。
    /// 10〜15件規模でも崩れない(`PrefectureProgress`は件数非依存の比率ベース)。
    private var prefectureProgressRow: some View {
        HStack(spacing: 8) {
            Text(prefectureName)
                .font(PictriTypography.body(12.5, weight: .semibold))
                .foregroundStyle(PictriFinalTheme.inkSoft)

            Text("おすすめ \(prefectureProgress.completedCount)/\(max(prefectureProgress.totalRecommendedSpotCount, 1))")
                .font(PictriTypography.body(12.5, weight: .bold))
                .foregroundStyle(PictriHomeBrandAccent.accent)
                .monospacedDigit()

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Capture eligibility (STEP 6/7/8)

    @ViewBuilder
    private var captureSection: some View {
        switch eligibility {
        case .completed:
            statusLine(icon: "checkmark.circle.fill", text: "このスポットは達成済みです", tint: PictriHomeBrandAccent.accent)

        case .insideRange:
            VStack(alignment: .leading, spacing: 10) {
                statusLine(icon: "checkmark.circle", text: "ここで撮影できます", tint: PictriHomeBrandAccent.accent)
                captureButton
            }

        case .outsideRange(let distanceText):
            statusLine(
                icon: "location.circle",
                text: distanceText.map { "スポット付近で撮影できます・あと\($0)" } ?? "スポット付近で撮影できます",
                tint: PictriDarkTheme.textFaint
            )

        case .locationUnavailable:
            statusLine(icon: "location.slash", text: "現在地が取得できません", tint: PictriDarkTheme.textFaint)
        }
    }

    private func statusLine(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(PictriTypography.body(12.5, weight: .semibold))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }

    /// STEP 17「CTA DESIGN」: 標準の青Buttonは使わない。PicTri既存accent
    /// (中央Camera Dockと同じmuted lavender)、巨大Buttonにはしない。
    private var captureButton: some View {
        Button(action: {
            onCapture()
            dismiss()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("ここで撮る")
                    .font(PictriTypography.body(14, weight: .bold))
            }
            .foregroundStyle(PictriHomeBrandAccent.onAccent)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background {
                Capsule().fill(PictriHomeBrandAccent.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spot.name)で撮影")
    }
}
