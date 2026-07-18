import SwiftUI

// MARK: - Pictri Design System
//
// 各画面で重複していた色・角丸・余白・ボタン・バッジ・見出し・空状態の定義を
// 最小限のセットにまとめたもの。既存の JQUI / AppBackground はそのまま維持し、
// このファイルはその上に薄く積む形で追加する。

enum PictriTheme {
    // 背景(黒だが、わずかに青みを帯びたチャコール。純黒白からの脱却)
    static let backgroundTop = Color(red: 0.035, green: 0.04, blue: 0.058)
    static let backgroundBottom = Color(red: 0.065, green: 0.072, blue: 0.10)

    // サーフェス(インディゴをわずかに混ぜたカード面。単調な白透過をやめる)
    static let surface = Color(red: 0.42, green: 0.46, blue: 0.62).opacity(0.10)
    static let surfaceStrong = Color(red: 0.44, green: 0.48, blue: 0.64).opacity(0.16)
    static let surfaceBorder = Color.white.opacity(0.10)

    // テキスト
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textFaint = Color.white.opacity(0.36)

    // アクセント(soft indigo-blue。主要インタラクション・現在地感・選択状態に使う)
    static let accent = Color(red: 0.46, green: 0.62, blue: 0.98)
    static let accentSoft = Color(red: 0.46, green: 0.62, blue: 0.98).opacity(0.18)

    // Memories / 達成・完了に使うteal
    static let teal = Color(red: 0.34, green: 0.80, blue: 0.74)
    static let tealSoft = Color(red: 0.34, green: 0.80, blue: 0.74).opacity(0.16)

    // いいね・温かみに使うcoral-amber
    static let warm = Color(red: 0.98, green: 0.62, blue: 0.44)
    static let warmSoft = Color(red: 0.98, green: 0.62, blue: 0.44).opacity(0.16)

    // 角丸
    static let cornerLarge: CGFloat = 28
    static let cornerMedium: CGFloat = 20
    static let cornerSmall: CGFloat = 14

    // 余白
    static let spacingLarge: CGFloat = 22
    static let spacingMedium: CGFloat = 14
    static let spacingSmall: CGFloat = 8

    /// まだ行っていないスポットのアイコン面などに使う、暗い余白トーン。
    /// MemoriesのPrefecturePreviewTile(空セル)と同じ配色に揃えることで、
    /// 「未訪問=暗い余白、訪問済み=色がつく」という思想をMap/Home/Memories全体で一貫させる。
    /// MemoryVisualStyle.gradient(訪問済みスポット用の色)とは意図的に別物として扱う。
    static let unvisitedSpotGradient = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Surface

/// カード状の背景・枠線・角丸をまとめて与えるモディファイア。
struct PictriSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = PictriTheme.cornerLarge
    var fill: Color = PictriTheme.surface
    var borderOpacity: Double = 0.10

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(borderOpacity), lineWidth: 1)
            }
    }
}

extension View {
    func pictriSurface(
        cornerRadius: CGFloat = PictriTheme.cornerLarge,
        fill: Color = PictriTheme.surface,
        borderOpacity: Double = 0.10
    ) -> some View {
        modifier(
            PictriSurfaceModifier(
                cornerRadius: cornerRadius,
                fill: fill,
                borderOpacity: borderOpacity
            )
        )
    }
}

// MARK: - Buttons

struct PictriPrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isDisabled ? .white.opacity(0.12) : .white)
            .foregroundStyle(isDisabled ? .white.opacity(0.38) : .black)
            .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PictriSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(.white.opacity(0.10))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PictriPrimaryButtonStyle {
    static var pictriPrimary: PictriPrimaryButtonStyle { PictriPrimaryButtonStyle() }
}

extension ButtonStyle where Self == PictriSecondaryButtonStyle {
    static var pictriSecondary: PictriSecondaryButtonStyle { PictriSecondaryButtonStyle() }
}

// MARK: - Status Badge

enum PictriStatusTone: Equatable {
    case strong
    case neutral
    case muted

    var background: Color {
        switch self {
        case .strong: return .white
        case .neutral: return .white.opacity(0.88)
        case .muted: return .white.opacity(0.13)
        }
    }

    var foreground: Color {
        switch self {
        case .strong, .neutral: return .black
        case .muted: return .white.opacity(0.68)
        }
    }
}

/// 色だけに頼らず、アイコン+テキストで状態を伝えるバッジ。
struct PictriStatusBadge: View {
    let text: String
    let systemImage: String
    var tone: PictriStatusTone = .neutral

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 13, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tone.background)
            .foregroundStyle(tone.foreground)
            .clipShape(Capsule())
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Section Header

struct PictriSectionHeader: View {
    let title: String
    var trailing: AnyView?

    init(_ title: String, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PictriTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            trailing
        }
    }
}

// MARK: - Screen Header

/// Map / Camera など「英字見出しだけで普通すぎる」問題を解消するための共通ヘッダー。
/// 小さな英字eyebrow + 短い日本語タイトルで、画面の主役を静かに示す。
struct PictriScreenHeader: View {
    let eyebrow: String
    let title: String
    var trailing: AnyView?

    init(eyebrow: String, title: String, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.38))

                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            trailing
        }
    }
}

// MARK: - Compact Metric

/// 距離・件数などの補助情報を、主役にせず静かに添えるための小さな数値表示。
struct PictriCompactMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Accent Chip

/// 白黒だけに頼らない状態表示チップ。用途に応じてPictriThemeの差し色を使う。
enum PictriAccentColor {
    case indigo
    case teal
    case warm
    case neutral

    var color: Color {
        switch self {
        case .indigo: return PictriTheme.accent
        case .teal: return PictriTheme.teal
        case .warm: return PictriTheme.warm
        case .neutral: return .white
        }
    }
}

struct PictriAccentChip: View {
    let text: String
    var systemImage: String?
    var accent: PictriAccentColor = .indigo
    var isFilled: Bool = true

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isFilled ? accent.color : accent.color.opacity(0.16))
        .foregroundStyle(isFilled ? Color.black : accent.color)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Status Card

/// 「今どういう状態か」を1枚・1メッセージだけで伝えるカード。
/// Camera画面で複数の説明文が重なる問題を解消するために、状態表示はここに一本化する。
struct PictriStatusCard: View {
    let systemImage: String
    let title: String
    var detail: String?
    var accent: PictriAccentColor = .indigo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent.color)
                .frame(width: 34, height: 34)
                .background(accent.color.opacity(0.16))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.44))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PictriTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Glass Pill

/// カメラモード表示やMapバッジなど、プレビュー上に浮かせる小さな半透明ピル。
struct PictriGlassPill: View {
    let text: String
    var systemImage: String?
    var tone: PictriStatusTone = .strong

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.system(size: 12, weight: .bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .background(tone.background.opacity(tone == .strong ? 0.82 : 1), in: Capsule())
        .foregroundStyle(tone.foreground)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Empty State

/// 「何もない」ではなく「まだ余白」として見せるための共通空状態ビュー。
struct PictriEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.white.opacity(0.38))
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.pictriSecondary)
                .padding(.top, 4)
                .frame(maxWidth: 220)
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .pictriSurface(fill: .white.opacity(0.05))
    }
}
