import SwiftUI

// MARK: - Pictri Design System
//
// 各画面で重複していた色・角丸・余白・ボタン・バッジ・見出し・空状態の定義を
// 最小限のセットにまとめたもの。既存の JQUI / AppBackground はそのまま維持し、
// このファイルはその上に薄く積む形で追加する。

enum PictriTheme {
    // Visual Direction Consolidation: このenumの色は今後PictriDarkTheme(mode-aware、
    // PictriDarkPremiumTheme.swift)を単一の正準ソースとしてリダイレクトする。
    // 呼び出し箇所(Home/Camera/Memories/タブバー等)は無変更のまま、Dark/Light
    // Appearanceの切り替えに自動追従する。
    static var backgroundTop: Color { PictriDarkTheme.surfaceBase }
    static var backgroundBottom: Color { PictriDarkTheme.surfaceOverlay }

    static var surface: Color { PictriDarkTheme.surfaceRaised }
    static var surfaceStrong: Color { PictriDarkTheme.surfaceOverlay }
    static var surfaceBorder: Color { PictriDarkTheme.hairline }

    static var textPrimary: Color { PictriDarkTheme.textPrimary }
    static var textSecondary: Color { PictriDarkTheme.textSecondary }
    static var textFaint: Color { PictriDarkTheme.textFaint }

    static var accent: Color { PictriDarkTheme.accent }
    static var accentSoft: Color { PictriDarkTheme.accentSoft }

    // Memories / 達成・完了に使うteal(dark bg向けに彩度・明度を調整、色相は維持)
    static let teal = Color(red: 0.24, green: 0.79, blue: 0.54)
    static let tealSoft = Color(red: 0.24, green: 0.79, blue: 0.54).opacity(0.16)

    // いいね・温かみに使うcoral-amber(dark bg向けに調整、色相は維持)
    static let warm = Color(red: 1.00, green: 0.56, blue: 0.42)
    static let warmSoft = Color(red: 1.00, green: 0.56, blue: 0.42).opacity(0.16)

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
            .background(isDisabled ? PictriTheme.textPrimary.opacity(0.12) : PictriTheme.textPrimary)
            .foregroundStyle(isDisabled ? PictriTheme.textPrimary.opacity(0.38) : Color(red: 0.090, green: 0.075, blue: 0.063))
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

/// 白基調画面(Home/Memories Collect等)向けのセカンダリボタン。PictriSecondaryButtonStyleの
/// 白背景版で、accentカラーのテキスト+淡いaccent地の組み合わせにする。
struct PictriLightSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(PictriLightTheme.accentSoft)
            .foregroundStyle(PictriLightTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: PictriTheme.cornerMedium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PictriLightSecondaryButtonStyle {
    static var pictriLightSecondary: PictriLightSecondaryButtonStyle { PictriLightSecondaryButtonStyle() }
}

// MARK: - Status Badge

enum PictriStatusTone: Equatable {
    case strong
    case neutral
    case muted

    var background: Color {
        switch self {
        case .strong: return PictriTheme.textPrimary
        case .neutral: return PictriTheme.textPrimary.opacity(0.88)
        case .muted: return PictriTheme.textPrimary.opacity(0.13)
        }
    }

    var foreground: Color {
        switch self {
        case .strong, .neutral: return Color(red: 0.090, green: 0.075, blue: 0.063)
        case .muted: return PictriTheme.textPrimary.opacity(0.68)
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
    var textColor: Color = PictriTheme.textPrimary
    var trailing: AnyView?

    init(_ title: String, textColor: Color = PictriTheme.textPrimary, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.title = title
        self.textColor = textColor
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(textColor)
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
        .foregroundStyle(isFilled ? Color(red: 0.090, green: 0.075, blue: 0.063) : accent.color)
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
/// `isLight`をtrueにすると、白基調画面(Home/Memories Collect等)向けの淡い配色になる。
struct PictriEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var isLight: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(isLight ? PictriLightTheme.textFaint : .white.opacity(0.38))
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isLight ? PictriLightTheme.textPrimary : .white)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isLight ? PictriLightTheme.textSecondary : .white.opacity(0.46))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if let actionTitle, let action {
                Group {
                    if isLight {
                        Button(action: action) {
                            Text(actionTitle)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .buttonStyle(.pictriLightSecondary)
                    } else {
                        Button(action: action) {
                            Text(actionTitle)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .buttonStyle(.pictriSecondary)
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: 220)
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background {
            if isLight {
                RoundedRectangle(cornerRadius: PictriTheme.cornerLarge, style: .continuous)
                    .fill(PictriLightTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: PictriTheme.cornerLarge, style: .continuous)
                            .stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
                    }
            } else {
                Color.clear.pictriSurface(fill: .white.opacity(0.05))
            }
        }
    }
}

// MARK: - Pictri Light Theme (Map専用)
//
// Map関連画面(日本全体Map・都道府県詳細・エリア探索)だけに使う、白基調・軽い・
// 上品なテーマ。既存のPictriTheme(黒基調、Home/Camera/Memories/Accountで使用)は
// 無変更で維持し、この2つのテーマは意図的に混ぜない(黒基調の白文字をこちらで
// 使うと白背景に白文字で読めなくなるため)。

// dark premium統一(4画面再統一フェーズ)により、名称は白基調時代のまま維持しつつ
// (呼び出し側を書き換える巨大リファクタを避けるため)、値だけをPictriDarkTheme
// (PictriDarkPremiumTheme.swift)と同じ近似のwarm near-black / terracotta accentへ
// 反転した。「white」「paper」的な名前が実際にはdarkな値を指す箇所が残るのは意図的な
// トレードオフ(呼び出し箇所を全数置換しない代わりに、コメントで明示する)。
enum PictriLightTheme {
    // Visual Direction Consolidation: neutral/surface系はPictriDarkTheme(mode-aware)
    // を単一の正準ソースとしてリダイレクトする(brown castの原因だった固定hexを廃止)。
    static var background: Color { PictriDarkTheme.surfaceBase }
    /// 旧: 少しだけ暖かいoff white。今はsurfaceよりわずかに明るいraised面。
    static var warmWhite: Color { PictriDarkTheme.surfaceOverlay }
    static var surface: Color { PictriDarkTheme.surfaceRaised }
    static var surfaceBorder: Color { PictriDarkTheme.hairline }
    /// sand/coral系のカードで使う、ほんのり暖色がかった境界線。
    static let warmBorder = Color(red: 0.80, green: 0.66, blue: 0.52).opacity(0.45)

    static var textPrimary: Color { PictriDarkTheme.textPrimary }
    static var textSecondary: Color { PictriDarkTheme.textSecondary }
    static var textFaint: Color { PictriDarkTheme.textFaint }

    /// sky blueは「Map上の水・空・補助情報」限定に格下げ。主要CTAには多用しない。
    static var accent: Color { PictriDarkTheme.accent }
    static var accentSoft: Color { PictriDarkTheme.accentSoft }

    /// 訪問済み/保存済み/場所が色づいた状態を示すteal / mint(dark bg向けに彩度・明度調整)。
    static let teal = Color(red: 0.24, green: 0.79, blue: 0.54)
    static let mint = Color(red: 0.50, green: 0.85, blue: 0.68)
    static let mintSoft = Color(red: 0.50, green: 0.85, blue: 0.68).opacity(0.16)
    static let skyBlue = Color(red: 0.50, green: 0.68, blue: 0.88)

    /// 友達・コメント・いいね・承認など「人の温度感」に使う、暖色のコーラル。
    static let coral = Color(red: 1.00, green: 0.58, blue: 0.48)
    static let coralSoft = Color(red: 1.00, green: 0.58, blue: 0.48).opacity(0.16)

    /// 次に行きたい場所・旅の余白・軽い誘導CTAに使う、暖かいsand。
    static let sand = Color(red: 0.80, green: 0.68, blue: 0.52)
    static let sandSoft = Color(red: 0.80, green: 0.68, blue: 0.52).opacity(0.18)

    /// sandより一段はっきりした、行動を促すamber(名所・ちょっと強めの誘導に使う)。
    static let amber = Color(red: 0.92, green: 0.68, blue: 0.38)
    static let amberSoft = Color(red: 0.92, green: 0.68, blue: 0.38).opacity(0.18)

    /// 旧: くすんだラベンダー(紫)。「紫を主役から外す」方針により、名前は既存呼び出し
    /// 箇所を壊さないため維持しつつ、値だけ warm copper(muted copper)へ置き換えた。
    static let lavender = Color(red: 0.78, green: 0.55, blue: 0.38)
    static let lavenderSoft = Color(red: 0.78, green: 0.55, blue: 0.38).opacity(0.16)

    /// 未訪問(まだ埋まっていない余白)を示す、背景に沈む低コントラストのmuted面。
    static var unvisitedFill: Color { PictriDarkTheme.surfaceOverlay }
    static var unvisitedStroke: Color { surfaceBorder }
    static var fog: Color { PictriDarkTheme.surfaceOverlay }

    /// 「訪問済み/記憶がある」を指す時の意味的エイリアス(実体はteal)。
    /// 「未訪問/まだ行っていない場所」を指す時の意味的エイリアス(実体はunvisitedFill)。
    /// Home/Memories側で「visited/unvisitedという名前で読みたい」箇所に使う。
    static var visited: Color { teal }
    static var unvisited: Color { unvisitedFill }

    /// 旧名。coralへ統合したため以後はcoral/coralSoftを直接使う(既存コードとの後方互換のみ)。
    static var friendWarm: Color { coral }
    static var friendWarmSoft: Color { coralSoft }

    /// 写真・夜・Camera背景に使う深いトーン。Cameraが他画面と断絶して見えないよう
    /// 統一paletteのsurfaceBaseへ揃える。
    static var photoDepth: Color { PictriDarkTheme.surfaceBase }

    /// surfaceBorderの意味的エイリアス。カード用の淡い境界線。
    static var subtleBorder: Color { surfaceBorder }

    static var shadow: Color { PictriDarkTheme.shadowColor }

    /// 都道府県ごとの訪問済み配色を、idの文字コード合計から安定的に決める。
    /// Swiftの String.hashValue はプロセスごとにランダム化されるため使わず、
    /// 同じ県が再起動やスクショの取り直しのたびに違う色に見えないようにする。
    /// skyBlueへ寄りすぎないよう、teal/mint/lavenderの3トーンを基本にした。
    static func visitedPrefectureColor(id: String) -> Color {
        let palette = [teal, mint, lavender]
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    /// 白基調画面(Home/Map/Memories Collect/Account)全体で使う角丸の3段階。
    /// 以前は画面ごとに18/20/22/24/26/28がバラバラに直書きされており、
    /// カードの角丸だけで「同じアプリ」に見えない一因になっていたため、
    /// hero(主役パネル) > card(標準カード) > row(リスト行・小カード) の3段だけに統一する。
    static let heroCornerRadius: CGFloat = 28
    static let cardCornerRadius: CGFloat = 24
    static let rowCornerRadius: CGFloat = 20
}

// MARK: - Light Card (白基調画面の共通カード)

/// Home Hero / Map progress card / Memories県カード / Account cardなど、白基調画面の
/// 「カード」に共通する背景・角丸・border・shadowをまとめたモディファイア。
/// 個別に.background().clipShape().overlay{stroke}.shadow()を書き下すと、画面ごとに
/// 角丸やshadowの強さが微妙にズレていくため、白基調カードは基本これ経由に統一する。
struct PictriLightCardModifier: ViewModifier {
    var cornerRadius: CGFloat = PictriLightTheme.cardCornerRadius
    var fill: Color = PictriLightTheme.surface
    var borderColor: Color = PictriLightTheme.surfaceBorder
    var shadowRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(color: PictriLightTheme.shadow, radius: shadowRadius, x: 0, y: shadowRadius / 3)
    }
}

extension View {
    func pictriLightCard(
        cornerRadius: CGFloat = PictriLightTheme.cardCornerRadius,
        fill: Color = PictriLightTheme.surface,
        borderColor: Color = PictriLightTheme.surfaceBorder,
        shadowRadius: CGFloat = 14
    ) -> some View {
        modifier(
            PictriLightCardModifier(
                cornerRadius: cornerRadius,
                fill: fill,
                borderColor: borderColor,
                shadowRadius: shadowRadius
            )
        )
    }
}

// MARK: - Light CTA Button (白基調画面の主要CTA)

/// Home「地図でスポットを探す」・Account「友達に追加」「承認」など、白基調画面の主要CTAを
/// 1つの高さ・角丸・文字サイズに揃えるための共通ボタンスタイル。色(mint/coral/sand等)だけを
/// 文脈で変え、形はPicTri全体で統一する。
struct PictriLightCTAButtonStyle: ButtonStyle {
    var tint: Color = PictriLightTheme.mint
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(isDisabled ? PictriLightTheme.unvisitedFill : tint)
            .foregroundStyle(isDisabled ? PictriLightTheme.textFaint : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: PictriLightTheme.rowCornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PictriLightCTAButtonStyle {
    static func pictriLightCTA(tint: Color = PictriLightTheme.mint, isDisabled: Bool = false) -> PictriLightCTAButtonStyle {
        PictriLightCTAButtonStyle(tint: tint, isDisabled: isDisabled)
    }
}

/// 「CTA=青」から脱却するための、文脈別の軽量トーン。フィルタチップやボタンなど
/// 複数箇所で「この文脈は何色か」を毎回書き下さずに済むようにするための最小限の分類で、
/// 大規模なデザインシステム化はしない。
enum PictriLightTone {
    case mint
    case sand
    case amber
    case coral
    case lavender
    case neutral

    var color: Color {
        switch self {
        case .mint: return PictriLightTheme.mint
        case .sand: return PictriLightTheme.sand
        case .amber: return PictriLightTheme.amber
        case .coral: return PictriLightTheme.coral
        case .lavender: return PictriLightTheme.lavender
        case .neutral: return PictriLightTheme.textSecondary
        }
    }

    var soft: Color {
        switch self {
        case .mint: return PictriLightTheme.mintSoft
        case .sand: return PictriLightTheme.sandSoft
        case .amber: return PictriLightTheme.amberSoft
        case .coral: return PictriLightTheme.coralSoft
        case .lavender: return PictriLightTheme.lavenderSoft
        case .neutral: return PictriLightTheme.unvisitedFill
        }
    }
}

// MARK: - Light Progress Card

/// 「訪れた都道府県 17/47」「訪問スポット 12/20」のような、数字+バー+割合をまとめた
/// 進捗カード。日本全体Mapと都道府県詳細の両方で同じ型を再利用する。
/// Visual Foundation Part C。以前はKPIダッシュボード然としたカード
/// (大きな数字+%表示+gradient progress bar+白カード影)で、PICTRI_DO_NOT_DEGRADE.md
/// #9「No dashboard statistics — no KPI blocks, rings, charts, percentages,
/// streaks」に反していた(=「よくあるAI生成アプリ」感の代表例)。Memories Index
/// が既に確立している「7県・17枚 集めた」という控えめなinline text表現に揃え、
/// カード・影・パーセンテージ・バーを廃止した。呼び出し側(icon/label/current/total)
/// は無変更のため、Map側のコード変更は不要。
struct PictriLightProgressCard: View {
    let icon: String
    let label: String
    let current: Int
    let total: Int
    var accentColor: Color = PictriLightTheme.mint

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accentColor)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PictriLightTheme.textSecondary)

            Text("\(current)/\(total)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PictriLightTheme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Light Floating Pill

/// 「地域一覧」「エリア一覧」のような、Mapの上に浮かべる白いピルボタン。
struct PictriLightFloatingPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(PictriLightTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(PictriLightTheme.surface)
            .clipShape(Capsule())
            .shadow(color: PictriLightTheme.shadow, radius: 12, x: 0, y: 4)
    }
}

// MARK: - Light Filter Chip

/// エリア探索画面のカテゴリフィルタチップ。「人気/ランキング」文脈を避けるため、
/// カテゴリ名(自然・フォトジェニック・名所など)のみを使う。
struct PictriLightFilterChip: View {
    let text: String
    var systemImage: String?
    let isSelected: Bool
    var tone: PictriLightTone = .mint

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isSelected ? tone.color : PictriLightTheme.surface)
        .foregroundStyle(isSelected ? Color.white : PictriLightTheme.textSecondary)
        .clipShape(Capsule())
        .overlay {
            if !isSelected {
                Capsule().stroke(PictriLightTheme.surfaceBorder, lineWidth: 1)
            }
        }
    }
}

// MARK: - Light Spot Card

/// 「近くのスポット」「次に行きたい場所」で使う、写真+訪問状態付きのカード。
struct PictriLightSpotCard: View {
    let title: String
    let subtitle: String
    let isVisited: Bool
    var thumbnail: Image?
    var accentColor: Color = PictriLightTheme.accent
    /// Map上で選択中のピンと連動して、対応するカードを軽く強調する。
    /// ランキング/人気感を出さないよう、枠線+淡いtintのみに留める。
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail {
                        thumbnail
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: isVisited
                                ? [PictriLightTheme.teal.opacity(0.32), PictriLightTheme.teal.opacity(0.12)]
                                : [PictriLightTheme.skyBlue.opacity(0.28), PictriLightTheme.skyBlue.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .overlay {
                            Image(systemName: isVisited ? "checkmark.circle.fill" : "mappin.circle.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(isVisited ? PictriLightTheme.teal : PictriLightTheme.skyBlue)
                        }
                    }
                }
                .frame(height: 92)
                .clipped()

                Image(systemName: isVisited ? "checkmark" : "camera.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(isVisited ? Color.black.opacity(0.34) : accentColor)
                    .clipShape(Circle())
                    .padding(7)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(isVisited ? PictriLightTheme.textFaint : accentColor)
                        .frame(width: 6, height: 6)

                    Text(isVisited ? "訪問済み" : "未訪問")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isVisited ? PictriLightTheme.textFaint : accentColor)

                    Spacer(minLength: 0)
                }

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(10)
        }
        .frame(width: 148)
        .background(isSelected ? accentColor.opacity(0.10) : PictriLightTheme.surface)
        // Home「次に行きたい場所」・Account系rowと同じrowCornerRadiusに揃える。
        // このカードはPrefecture detail・Area exploreの両方から共有で使われるため、
        // ここを直すだけで両画面のスポットカードが同時に統一される。
        .clipShape(RoundedRectangle(cornerRadius: PictriLightTheme.rowCornerRadius, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: PictriLightTheme.rowCornerRadius, style: .continuous)
                    .stroke(accentColor, lineWidth: 2)
            }
        }
        .shadow(color: PictriLightTheme.shadow, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Light Nudge Card

/// 「あと少しで達成!」のような軽い達成訴求カード。
struct PictriLightNudgeCard: View {
    let title: String
    let detail: String
    var systemImage: String = "flag.fill"
    var accentColor: Color = PictriLightTheme.teal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PictriLightTheme.textFaint)
        }
        .padding(14)
        .background(PictriLightTheme.surface)
        // 他の白基調rowと同じrowCornerRadius(20)に揃える(以前は18で微妙にズレていた)。
        .clipShape(RoundedRectangle(cornerRadius: PictriLightTheme.rowCornerRadius, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pictri Final Theme (Claude Design Final Handoff)
//
// ローカルのDesign Handoff資料(PICTRI_DESIGN_TOKENS.md)の値を
// 1:1で取り込んだ、正式なsemantic token層。既存のPictriTheme(暗色系、Camera/タブバー等が
// 使用中)・PictriLightTheme(白基調系、青accent、Home/Memories Collect/Account等が使用中)
// とは意図的に別のenumとして追加している。どちらも既存画面が現に参照しているため、
// 値を書き換えるとHome/Memories/Camera/Account/タブバーの見た目が変わってしまう。
// 今後Home/Memories等をFinal Designへ段階的に移行する際は、新しいDesign Systemを
// 重複作成せず、この token setを正式なsourceとして参照すること。
// 現時点ではPictriJapanCollectionMap.swift(Map)のみがこのtoken setを使用する。
// dark premium統一(4画面再統一フェーズ)により、ink(文字)/paper(面)の意味論を反転した。
// 元はDesign Handoffの「紙にインク」の白基調世界観だったが、4画面をdark editorial /
// quiet luxuryへ揃えるため、ink=明るいivory(文字)・paper=暗いsurface(面)として運用する。
// フィールド名は既存の全呼び出し箇所(Home/Camera/Memories/MapView等、90箇所以上)を
// 壊さずに済むよう意図的に維持している(巨大リファクタを避けるための判断)。
// 唯一の例外: PictriPhotoPrintの物理的な「影」は ink ではなく paperDeep(常に暗い側)を
// 参照するよう修正済み(ink反転後もshadowが暗いままになるようにするため)。
/// Round 8「Prefecture Progress System」専用の6段階color token。
/// `PictriFinalTheme.memoryColor`(既存、47県のearned tripを5色でローテーションする
/// 別用途。MapView/MemoriesView/CameraViewが使用中で、今回は一切変更しない)とは
/// 完全に独立した新設token setで、Home Mapの「Collection Summary」表示専用に使う。
/// Goldは「県内のおすすめSpotを全てコンプリート」した場合にのみ使う(Memory Card/
/// Camera/Dock/ボタン等では絶対に使わない、Round 8の明示的な制約)。
/// 白は`#FFFFFF`ではなくSoft White、金は彩度を抑えたMuted Goldにしている。
/// Round「HOME MAP FINAL VISUAL CORRECTION」で確定した、Home Map最終Visual
/// Directionのtoken。直前Round(HOME WHITE MAP REDESIGN)で作った
/// `PictriHomeMapCanvasTheme`(白いmap canvas前提のtoken)/`PictriRegionPalette`は
/// ユーザーの明示的な却下(「White Map Canvas / White Rounded Cardは不採用」)を
/// 受けて廃止し、この1つのtoken setへ統合した。
///
/// 最終方針: Home地図はbackground(海も含めた矩形全体)を`.clear`にし、Home自身の
/// dark backgroundをそのまま透過させる。ここに並ぶのは「都道府県polygonの塗り・
/// 県境線」だけの値で、地図専用の背景色は一切持たない。
///
/// 状態判定順序(仕様通り、Viewはこの順序をそのまま使う):
///   1. !hasVisited            → unvisited (soft white)
///   2. completedSpotIDs.isEmpty → anywhereVisited (dark charcoal)
///   3. isComplete             → complete (gold)
///   4. それ以外                → regionColor(regionId)
enum PictriHomeMapTheme {
    /// STATE 0 — 未訪問。純白(#FFFFFF)は使わず、既存のsoft white token
    /// (`PictriPrefectureProgressTheme.softWhite`)をそのまま再利用する
    /// (Home地図専用に別の白を新設しない)。日本列島全体の輪郭が常に
    /// はっきり見える、という要求を満たす主要な塗り。
    static var unvisited: Color { PictriPrefectureProgressTheme.softWhite }

    /// STATE 1 — Anywhere撮影のみ(おすすめSpot未達成)。dark charcoal。
    /// 背景(Homeのdark surface)と完全同化しないよう、surfaceより
    /// 一段明るい値にする。
    static let anywhereVisited = Color(red: 46 / 255, green: 46 / 255, blue: 51 / 255)

    /// STATE 3 — コンプリート。既存のcompletionGoldをそのまま参照する
    /// (Goldの実体を複数箇所へ増やさない、Album等と完全に同じ値)。
    static var complete: Color { PictriPrefectureProgressTheme.completionGold }

    // STATE 2 — 地方色(9区分固定)。`QuestPrefectureShape.region`をそのまま
    // lookup keyにする(新しい地理データやprefecture→region対応表は追加しない)。
    // 実機確認(前Round)で「黄系の地方色はcompletionGold(#D6B65A、色相約43°)と
    // 混同する」ことが判明したため、9色いずれも43°付近を明確に避けている。
    // 彩度・明度は「若者向けで可愛いが子供っぽくない」範囲(概ね彩度30-45%・
    // 明度55-65%)に抑え、NEONは使わない。
    static let hokkaido = Color(red: 150 / 255, green: 140 / 255, blue: 180 / 255)   // muted lavender
    static let tohoku = Color(red: 130 / 255, green: 165 / 255, blue: 205 / 255)     // soft blue
    static let kanto = Color(red: 130 / 255, green: 190 / 255, blue: 165 / 255)      // mint / soft green
    static let chubu = Color(red: 165 / 255, green: 195 / 255, blue: 120 / 255)      // fresh yellow-green
    static let kansai = Color(red: 185 / 255, green: 110 / 255, blue: 95 / 255)      // warm terracotta(goldとの衝突回避のためyellowから振替)
    static let chugoku = Color(red: 110 / 255, green: 175 / 255, blue: 175 / 255)    // soft teal(kansai/kyushuの暖色帯と被らないよう、暖色系からteal寄りへ振替)
    static let shikoku = Color(red: 215 / 255, green: 140 / 255, blue: 150 / 255)    // coral / pink
    static let kyushu = Color(red: 200 / 255, green: 110 / 255, blue: 135 / 255)     // rose
    static let okinawa = Color(red: 180 / 255, green: 90 / 255, blue: 140 / 255)     // magenta / deep pink

    static func regionColor(forRegion region: String) -> Color {
        switch region {
        case "hokkaido": return hokkaido
        case "tohoku": return tohoku
        case "kanto": return kanto
        case "chubu": return chubu
        case "kansai": return kansai
        case "chugoku": return chugoku
        case "shikoku": return shikoku
        case "kyushu": return kyushu
        case "okinawa": return okinawa
        default: return kanto
        }
    }

    /// 未訪問(soft white)地の上の県境。中間の neutral gray。
    static let unvisitedBorder = Color(red: 119 / 255, green: 119 / 255, blue: 127 / 255)
    /// 訪問済み(charcoal/地方色/gold、いずれの塗りでも共通)の県境。charcoalの
    /// ような暗い塗りの上でも沈まないよう、白寄りの半透明にする
    /// (単色の暗いstrokeだと、暗いcharcoal塗りの上で輪郭が消えてしまうため)。
    static let visitedBorder = Color.white.opacity(0.55)
}

enum PictriPrefectureProgressTheme {
    /// 訪問済みだが、おすすめSpotをまだ1件もコンプリートしていない県。
    static let softWhite = Color(red: 233 / 255, green: 233 / 255, blue: 236 / 255)
    /// 1/5相当。
    static let paleLavender = Color(red: 227 / 255, green: 213 / 255, blue: 250 / 255)
    /// 2/5相当。
    static let lightLavender = Color(red: 201 / 255, green: 172 / 255, blue: 242 / 255)
    /// 3/5相当。
    static let lavender = Color(red: 169 / 255, green: 130 / 255, blue: 227 / 255)
    /// 4/5相当。
    static let deepLavender = Color(red: 131 / 255, green: 97 / 255, blue: 198 / 255)
    /// 5/5(コンプリート)専用。他のどこにも使わない。
    static let completionGold = Color(red: 214 / 255, green: 182 / 255, blue: 90 / 255)

    static func color(for level: PrefectureProgress.CollectionLevel, dormantFallback: Color) -> Color {
        switch level {
        case .unvisited: return dormantFallback
        case .visitedNoSpots: return softWhite
        case .level1: return paleLavender
        case .level2: return lightLavender
        case .level3: return lavender
        case .level4: return deepLavender
        case .complete: return completionGold
        }
    }
}

enum PictriFinalTheme {

    // MARK: Ink & paper (base world)
    // Visual Direction Consolidation: PictriDarkTheme(mode-aware)へリダイレクト。
    // ink/paperという「紙にインク」の名前は維持しつつ、実体はmatte graphite/optical
    // whiteの正準トークンとなり、Dark/Light Appearanceに自動追従する。
    static var ink: Color { PictriDarkTheme.textPrimary }
    static var inkSoft: Color { PictriDarkTheme.textSecondary }
    static var inkFaint: Color { PictriDarkTheme.textFaint }
    static var paper: Color { PictriDarkTheme.surfaceBase }
    static var paperWarm: Color { PictriDarkTheme.surfaceRaised }
    static var paperDeep: Color { PictriDarkTheme.surfaceOverlay }
    static var line: Color { PictriDarkTheme.hairline }
    static var surfaceRaised: Color { PictriDarkTheme.surfaceRaised }
    static var surfaceInk: Color { ink }
    static var onInk: Color { paper }
    static let onAccent = hex(0x1A1310)

    // MARK: Terracotta accent — "the actor"
    static let accent = hex(0xD97757)

    // MARK: Dormant (unvisited — never colorful)
    static var dormant: Color { PictriDarkTheme.surfaceOverlay }
    static var dormantDot: Color { PictriDarkTheme.hairline }
    static var dormantInk: Color { PictriDarkTheme.textFaint }

    // MARK: Memory colors (earned; a place/trip owns exactly one)
    // dark bg向けに彩度・明度を上げた値(Run B: PictriJapanCollectionMapPalette.darkと
    // 同一の調整値を再利用し、Map/Home/Memoriesで同じ県=同じ色に見えるよう揃えている)。
    static let memoryShu = hex(0xFF6B47)
    static let memoryYamabuki = hex(0xFFC93D)
    static let memoryMidori = hex(0x3DC98A)
    static let memoryRuri = hex(0x5C8AFF)
    static let memoryBotan = hex(0xF073B5)
    static let memoryColors: [Color] = [memoryShu, memoryYamabuki, memoryMidori, memoryRuri, memoryBotan]

    /// 都道府県/tripが持つmemory colorを、idの文字コード合計から決定論的に割り当てる。
    /// Swiftのhashは再起動ごとに変わるため使わない。「per prefecture/trip, stable once
    /// assigned」という仕様を、新しい永続化を増やさずに満たすための導出。
    static func memoryColor(for id: String) -> Color {
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return memoryColors[sum % memoryColors.count]
    }

    /// memoryColor(for:)と同じ導出(id文字コード合計)を使うため、常に同じidには
    /// 同じ色名が対応する(色そのものと名前が食い違わない)。
    static let memoryColorNames: [String] = ["朱", "山吹", "緑", "瑠璃", "牡丹"]

    static func memoryColorName(for id: String) -> String {
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return memoryColorNames[sum % memoryColorNames.count]
    }

    // MARK: Semantic(dark bg向けに明度を上げて視認性を確保)
    static let danger = hex(0xFF5C46)
    static let success = hex(0x2FBE86)

    // MARK: Secondary illustrative palette(Visual Foundation Part A)
    //
    // memoryColors(朱/山吹/緑/瑠璃/牡丹)は「実際に訪れて earned した」場所だけが
    // 持てる色(DO_NOT_DEGRADE #10「No random accent colors. Only the five memory
    // colors, and only on things that were actually visited.」)。この6色は
    // それとは別の用途専用: paywall/permission/quota/empty stateのような、
    // 何も「訪問実績」を語らない utility画面の、ごく控えめなイラスト・アイコン
    // アクセントとしてのみ使う。dark bgでも視認できる程度に明度を上げつつ、彩度は
    // 抑えたまま(neon/cyber/強いCTA色は禁止)。secondaryLavender(紫)はterracotta系
    // のmuted copperへ置き換えた(名前は既存呼び出し箇所を壊さないため維持)。
    static let secondaryCoral = hex(0xE0A98F)
    static let secondarySand = hex(0xD4C3A5)
    static let secondaryMint = hex(0xA8CBB8)
    static let secondaryMutedGreen = hex(0x8FB08E)
    static let secondarySoftAmber = hex(0xD9B87E)
    static let secondaryLavender = hex(0xB99A82)

    // MARK: Spacing (base 4)
    static let screenPadding: CGFloat = 20
    static let sectionGap: CGFloat = 28
    static let stackGap: CGFloat = 12
    static let tapMinimum: CGFloat = 44

    // MARK: Radius roles
    static let radiusPhotoPrint: CGFloat = 5
    static let radiusCameraPreview: CGFloat = 10
    static let radiusControl: CGFloat = 12
    static let radiusGroupedBlock: CGFloat = 13
    static let radiusPill: CGFloat = 999
    static let radiusSheetTop: CGFloat = 22

    // MARK: Motion durations (seconds)
    static let durationPress: Double = 0.14
    static let durationDefault: Double = 0.24
    static let durationSlow: Double = 0.42
    static let durationBloom: Double = 0.52
    static let durationInkToPaper: Double = 0.5

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - Pictri Typography (Claude Design Final Handoff)
//
// PICTRI_DESIGN_TOKENS.md「Typography」/ PICTRI_ASSET_MANIFEST.md「Type」で指定されている
// 正式な書体は Dela Gothic One(display) / Zen Maru Gothic(body, 400/500/700/900) /
// Space Mono(meta)。Asset Manifestではこの3書体はすべて`[X]`(=exportが必要、
// このプロジェクトにはまだ同梱されていない)に分類されている。
// このリポジトリ・PictriDesignHandoffFinal配下のどちらにもフォントファイル(.ttf/.otf)が
// 存在しないことを確認済み(find済み)。ネットワークから新規に取得することはせず、
// 未同梱のままroleだけを正式に定義する。`Font.custom(name:size:)`は指定名のフォントが
// 見つからない場合、クラッシュせずsystem fontへ自動fallbackするため、今回はこのまま
// buildできる(見た目は当面system fontのまま)。実フォントファイルが将来
// target(Info.plistのUIAppFonts含む)へ追加されれば、コード変更なしで自動的に
// 正式書体へ切り替わる。
//
// Home等の画面側は`.font(.system(size: ...))`をこの場で直接指定するのではなく、
// 必ずこのenumのrole(display/title/body/caption/mono)経由にする。
enum PictriTypography {
    /// Google Fonts想定のPostScript名。実バイナリを同梱するまではsystem fontへ自動fallback。
    private static let displayFamily = "DelaGothicOne-Regular"
    private static let bodyRegularFamily = "ZenMaruGothic-Regular"
    private static let bodyMediumFamily = "ZenMaruGothic-Medium"
    private static let bodyBoldFamily = "ZenMaruGothic-Bold"
    private static let bodyBlackFamily = "ZenMaruGothic-Black"
    private static let monoRegularFamily = "SpaceMono-Regular"
    private static let monoBoldFamily = "SpaceMono-Bold"

    /// 画面タイトル・県名・「色がつく瞬間」の見出し等。短い文字列専用(段落には使わない)。
    static func display(_ size: CGFloat) -> Font {
        .custom(displayFamily, size: size)
    }

    /// 本文・投稿文・ラベル等、読ませるテキスト全般。weightで太さのroleだけを切り替える
    /// (Zen Maru Gothicは400/500/700/900の4段階、中間のweightは近い段階へ丸める)。
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .black, .heavy:
            return .custom(bodyBlackFamily, size: size)
        case .bold, .semibold:
            return .custom(bodyBoldFamily, size: size)
        case .medium:
            return .custom(bodyMediumFamily, size: size)
        default:
            return .custom(bodyRegularFamily, size: size)
        }
    }

    /// 日付・座標・件数など、Latin/数字だけの小さなmetaテキスト専用
    /// (Handoff: 「mono carries Latin/numerals only」)。
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        weight == .bold || weight == .semibold || weight == .heavy || weight == .black
            ? .custom(monoBoldFamily, size: size)
            : .custom(monoRegularFamily, size: size)
    }
}

// MARK: - Pictri Hairline
//
// PICTRI_DO_NOT_DEGRADE.md #1「Surfaces are paper with hairlines. Content is separated
// by lines and space, not boxes.」の実装。汎用white rounded cardの代わりに、
// セクション・投稿間の区切りとして使う1ptの罫線。
struct PictriHairline: View {
    var color: Color = PictriFinalTheme.line

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
    }
}

// MARK: - Pictri Photo Print
//
// PICTRI_COMPONENT_INVENTORY.md「PhotoPrint: any photograph rendered as a physical
// print... the ONLY approved photo container besides full-bleed.」の実装。
// 単なるRoundedRectangle+imageではなく、paper padding・print radius・print shadow・
// 決定論的な微小回転(±1°程度)・任意captionを持つ「印刷された写真」として描画する。
/// rotationSeed(例: post.id)から決定論的に角度を決める。都度ランダムだと再描画のたびに
/// 傾きが変わり「画面が毎回変わる」実装になるため禁止されている(依頼原文の通り)。
struct PictriPhotoPrint<Content: View>: View {
    let content: Content
    var rotationSeed: String?
    var caption: String?
    var aspectRatio: CGFloat = 4.0 / 5.0
    /// 紙の余白(Design Tokens「raised-paper padding 3-6 depending on size」)。
    /// 既定値5はCameraの確認画面(CameraView.swift、今回のPhaseでは不可触)が
    /// 元々使っていた値のままにして、明示的に別の値を渡さない限りその見た目が
    /// 変わらないようにする。Home feedのような大きいprintだけ、呼び出し側で
    /// より太い値を渡す。
    var padding: CGFloat = 5

    init(
        rotationSeed: String? = nil,
        caption: String? = nil,
        aspectRatio: CGFloat = 4.0 / 5.0,
        padding: CGFloat = 5,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.rotationSeed = rotationSeed
        self.caption = caption
        self.aspectRatio = aspectRatio
        self.padding = padding
    }

    private var rotationDegrees: Double {
        guard let rotationSeed else { return 0 }
        let seed = rotationSeed.utf8.reduce(0) { $0 + Int($1) }
        // -1.0...1.0度の範囲に収める(Handoff: 「≤1° rotation」)。
        return (Double(seed % 21) - 10) / 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
                .aspectRatio(aspectRatio, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: PictriFinalTheme.radiusPhotoPrint - 2, style: .continuous))

            if let caption {
                Text(caption)
                    .font(PictriTypography.mono(11, weight: .regular))
                    .foregroundStyle(PictriFinalTheme.inkFaint)
            }
        }
        .padding(padding)
        .background(PictriFinalTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: PictriFinalTheme.radiusPhotoPrint, style: .continuous))
        // 影は常にPictriDarkTheme.shadowColor(常に黒ベース)を参照する。paperDeepは
        // mode-awareになりlight modeでは明るい値を返すため、影に使うと不具合になる。
        .shadow(color: PictriDarkTheme.shadowColor.opacity(0.6), radius: 0, x: 0, y: 1)
        .shadow(color: PictriDarkTheme.shadowColor, radius: 10, x: 0, y: 6)
        .rotationEffect(.degrees(rotationDegrees))
    }
}
