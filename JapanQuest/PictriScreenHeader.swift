import SwiftUI

// MARK: - MAP/ALBUM REFERENCE MIGRATION — Shared Top-Level Design System
//
// Round「MAP / ALBUM REFERENCE MIGRATION」で、Map/Albumの新しいtop-level画面を
// Homeと「同じアプリに見える」ようにするための共有token/componentをまとめた
// 新設ファイル。HomeView.swift自身は一切変更しない(Home Absolute Freeze)。
// ここに置く値は、HomeView.swiftの`header`/`homeBackground`/`titleBlock`が
// 実際に使っている値を1:1でコピーしたもので、Homeのpixelには一切影響しない
// (Home側は引き続き自分のprivateな実装を使い続ける)。
//
// 目的は「共通Design Systemとして構造を抽出する」であり、Homeを書き換えて
// 共有させる(=Home側にpixel差分が出るリスクを負う)のではなく、値だけを
// 複製して新しいMap/Album画面から個別に参照する方式を取っている。

/// Home/Map/Albumで共通のroot background。Home`homeBackground`と同一構成
/// (paper土台 + surfaceRaisedのradial depth + brand accentのradial + 静止した
/// atmosphere flecks)。Map/Albumだけ紺/紫/純黒/card backgroundにしない、という
/// 今回の明示要求(G01)に対応する唯一の背景。
struct PictriScreenBackground: View {
    private static let atmosphereFlecks: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (0.12, 0.10, 1.6, 0.06), (0.82, 0.07, 1.2, 0.05), (0.64, 0.16, 1.8, 0.04),
        (0.28, 0.20, 1.3, 0.05), (0.90, 0.22, 1.5, 0.04), (0.06, 0.26, 1.2, 0.05),
        (0.50, 0.06, 1.4, 0.04), (0.72, 0.28, 1.1, 0.05)
    ]

    var body: some View {
        ZStack {
            PictriFinalTheme.paper
            RadialGradient(
                colors: [
                    PictriDarkTheme.surfaceRaised.opacity(0.9),
                    PictriDarkTheme.surfaceRaised.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 20,
                endRadius: 460
            )
            RadialGradient(
                colors: [
                    PictriHomeBrandAccent.accent.opacity(0.05),
                    PictriHomeBrandAccent.accent.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.44),
                startRadius: 30,
                endRadius: 380
            )
            .allowsHitTesting(false)
            GeometryReader { proxy in
                ForEach(Array(Self.atmosphereFlecks.enumerated()), id: \.offset) { _, fleck in
                    Circle()
                        .fill(Color.white.opacity(fleck.opacity))
                        .frame(width: fleck.size, height: fleck.size)
                        .position(x: proxy.size.width * fleck.x, y: proxy.size.height * fleck.y)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Home`header`と同一構成(中央固定のPicTri wordmark + 右上notification/account
/// pill)。`PictriHomeTopPill`はHomeView.swift定義のものをそのまま再利用する
/// (複製しない、1つの実装を共有)。
struct PictriTopBrandHeader: View {
    let badgeCount: Int
    let onAccountTap: () -> Void

    var body: some View {
        ZStack {
            Text("PicTri")
                .font(PictriTypography.display(24))
                .tracking(2.2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [PictriFinalTheme.ink, PictriHomeBrandAccent.accent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(alignment: .center, spacing: 10) {
                Spacer(minLength: 0)

                Button(action: onAccountTap) {
                    PictriHomeTopPill(badgeCount: badgeCount)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("アカウント")
                .accessibilityValue(badgeCount == 0 ? "" : "通知\(badgeCount)件")
            }
        }
    }
}

/// Home`titleBlock`と同一構成(見出し + 短いlavender underline + optional subtitle)。
struct PictriSectionTitleBlock: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PictriTypography.display(20))
                .foregroundStyle(PictriFinalTheme.ink)

            Capsule()
                .fill(PictriHomeBrandAccent.accent)
                .frame(width: 34, height: 3)

            if let subtitle {
                Text(subtitle)
                    .font(PictriTypography.body(13, weight: .semibold))
                    .foregroundStyle(PictriDarkTheme.textFaint)
                    .monospacedDigit()
            }
        }
    }
}
