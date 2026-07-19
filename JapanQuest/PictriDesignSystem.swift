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
struct PictriCompactMetric: View {
    let label: String
    let value: String
    var isLight: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isLight ? PictriLightTheme.textSecondary : .white.opacity(0.42))

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isLight ? PictriLightTheme.textPrimary : .white.opacity(0.75))
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

enum PictriLightTheme {
    static let background = Color(red: 0.985, green: 0.988, blue: 0.996)
    static let surface = Color.white
    static let surfaceBorder = Color.black.opacity(0.05)

    static let textPrimary = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let textSecondary = Color.black.opacity(0.46)
    static let textFaint = Color.black.opacity(0.28)

    /// 主要CTA・撮影可能・選択中を示すsky blue。Map内での「今できる行動」の色。
    static let accent = Color(red: 0.18, green: 0.50, blue: 0.92)
    static let accentSoft = Color(red: 0.18, green: 0.50, blue: 0.92).opacity(0.12)

    /// 訪問済み/記録があることを示すteal / mint / sky blueの3トーン。
    static let teal = Color(red: 0.20, green: 0.68, blue: 0.64)
    static let mint = Color(red: 0.46, green: 0.76, blue: 0.60)
    static let skyBlue = Color(red: 0.44, green: 0.66, blue: 0.88)

    /// 未訪問(まだ埋まっていない余白)を示すlight gray。
    static let unvisitedFill = Color(red: 0.91, green: 0.92, blue: 0.94)
    static let unvisitedStroke = Color.white

    /// 「訪問済み/記憶がある」を指す時の意味的エイリアス(実体はteal)。
    /// 「未訪問/まだ行っていない場所」を指す時の意味的エイリアス(実体はunvisitedFill)。
    /// Home/Memories側で「visited/unvisitedという名前で読みたい」箇所に使う。
    static let visited = teal
    static let unvisited = unvisitedFill

    /// 友達・コメント・いいねなど「人の温度感」に使う、白背景用の淡いコーラル。
    /// PictriTheme.warm(黒背景用)と役割は同じだが、白背景でも沈まないよう明度を上げている。
    static let friendWarm = Color(red: 0.90, green: 0.56, blue: 0.44)
    static let friendWarmSoft = Color(red: 0.90, green: 0.56, blue: 0.44).opacity(0.14)

    /// 写真・夜・Camera背景に使う深いindigo/blue gray。純黒を避け、PicTriアイコンの
    /// 紫〜青グラデーションに近いトーンにすることで、Cameraが他画面と断絶して
    /// 見えないようにする。
    static let photoDepth = Color(red: 0.09, green: 0.10, blue: 0.16)

    /// surfaceBorderの意味的エイリアス。カード用の淡い境界線。
    static let subtleBorder = surfaceBorder

    static let shadow = Color.black.opacity(0.07)

    /// 都道府県ごとの訪問済み配色を、idの文字コード合計から安定的に決める。
    /// Swiftの String.hashValue はプロセスごとにランダム化されるため使わず、
    /// 同じ県が再起動やスクショの取り直しのたびに違う色に見えないようにする。
    static func visitedPrefectureColor(id: String) -> Color {
        let palette = [teal, skyBlue, mint]
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}

// MARK: - Light Progress Card

/// 「訪れた都道府県 17/47」「訪問スポット 12/20」のような、数字+バー+割合をまとめた
/// 進捗カード。日本全体Mapと都道府県詳細の両方で同じ型を再利用する。
struct PictriLightProgressCard: View {
    let icon: String
    let label: String
    let current: Int
    let total: Int
    var accentColor: Color = PictriLightTheme.accent

    private var ratio: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(current) / Double(total))
    }

    private var percentText: String {
        "\(Int((ratio * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentColor)

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(current)")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(accentColor)

                Text("/ \(total)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textFaint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PictriLightTheme.unvisitedFill)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [PictriLightTheme.teal, accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 6)

            Text("訪問率 \(percentText)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PictriLightTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 16, x: 0, y: 6)
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
        .background(isSelected ? PictriLightTheme.accent : PictriLightTheme.surface)
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
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Light Share Card

/// 「家族や友だちにシェアしよう」の軽いカード。特定ブランドのアイコンは使わず、
/// iOS標準のShareLinkで「誰と共有するか」はユーザー自身に委ねる
/// (LINE/Instagram等の商標アイコンを模倣しない、かつフォロー/フォロワー型SNSにしない)。
struct PictriLightShareCard: View {
    let shareText: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(PictriLightTheme.accentSoft)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PictriLightTheme.accent)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text("家族や友だちにシェアしよう")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PictriLightTheme.textPrimary)

                Text("身内だけに、旅の記録を共有できます")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PictriLightTheme.textSecondary)
            }

            Spacer(minLength: 8)

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PictriLightTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(PictriLightTheme.accentSoft)
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(PictriLightTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: PictriLightTheme.shadow, radius: 12, x: 0, y: 4)
    }
}

// MARK: - Light Decorative Motifs

/// 日本全体Map/県詳細Mapの余白に控えめに置く、線画風の木・波アイコン。
/// 実装当初は灰色の矩形を並べていたシミュレータープレースホルダーで
/// 「壊れて見える」問題が起きた反省を踏まえ、極薄い不透明度に留める。
struct PictriPineTreeMotif: View {
    var tint: Color = PictriLightTheme.skyBlue

    var body: some View {
        VStack(spacing: -3) {
            PictriTriangleShape().frame(width: 10, height: 8)
            PictriTriangleShape().frame(width: 14, height: 9)
            PictriTriangleShape().frame(width: 18, height: 11)
        }
        .foregroundStyle(tint)
    }
}

struct PictriWaveMotif: View {
    var tint: Color = PictriLightTheme.skyBlue
    var width: CGFloat = 30

    var body: some View {
        PictriWaveShape()
            .stroke(tint, lineWidth: 1.4)
            .frame(width: width, height: 8)
    }
}

struct PictriTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct PictriWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.17, y: midY - rect.height * 0.55),
            control2: CGPoint(x: rect.minX + rect.width * 0.33, y: midY + rect.height * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control1: CGPoint(x: rect.midX + rect.width * 0.17, y: midY - rect.height * 0.55),
            control2: CGPoint(x: rect.midX + rect.width * 0.33, y: midY + rect.height * 0.55)
        )
        return path
    }
}
