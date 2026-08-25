import SwiftUI

// MARK: - Pictri Matte Design System (Visual Direction Consolidation)
//
// 旧: Run A時代のwarm dark charcoal(#16130Fベース)は、繰り返しの反転・流用の過程で
// 「espresso / vintage leather」寄りのbrown castになっていた。今回、方向を
// MATTE COATED PAPER + GRAPHITE BLACK + OPTICAL WHITE + SUBTLE GLASS へ作り直す。
//
// このファイルは`PictriAppearanceStore.shared`(mode: .dark/.light)を読み、
// 「Dark = 黒い高級写真集、Light = 白い高級写真集」という同一Design DNAの2面を
// 1つのtoken集合として提供する。型名`PictriDarkTheme`は既存の全画面
// (Home/Map/Camera/Memories/Opening)が直接参照しているため、リネームによる
// 巨大な呼び出し箇所の書き換えを避け、意図的に維持している
// (実体はdark専用ではなく、mode-awareな正準トークン)。
//
// 呼び出し側は生のColor(...)やhexを直書きせず、必ずこのenum経由で参照すること。
enum PictriDarkTheme {

    private static var mode: PictriAppearanceMode { PictriAppearanceStore.current }

    // MARK: Surface ramp(3〜4段。cool-neutral graphite、pure blackにはしない)
    /// 最背面。
    static var surfaceBase: Color {
        mode == .dark ? hex(0x121214) : hex(0xF7F7F5)
    }
    /// カード面(surfaceBaseより一段明るい/暗い)。
    static var surfaceRaised: Color {
        mode == .dark ? hex(0x1C1C1F) : hex(0xFFFFFF)
    }
    /// さらに浮いた面(sheet/modal等)。
    static var surfaceOverlay: Color {
        mode == .dark ? hex(0x27272B) : hex(0xFBFBF9)
    }
    /// 低コントラストの区切り線。neutral translucent white/black。
    static var hairline: Color {
        mode == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.08)
    }

    // MARK: Map専用(未訪問県)。Visual Reality Check Phaseで判明した問題への対応:
    // surfaceOverlay/hairlineは元々カード用に「背景とほぼ同じだが僅かに違う」ことを
    // 意図した値のため、日本地図のような画面全体に敷く用途で使うとLight modeでは
    // 未訪問県の輪郭がほぼ背景に溶けて見えなくなっていた(Dark modeは元々十分なコントラストが
    // あったため据え置き)。Mapの塗り・線だけ専用トークンとして分離し、Light側だけ
    // はっきり見える濃さに調整する。
    static var mapUnvisitedFill: Color {
        mode == .dark ? surfaceOverlay : hex(0xE9E9E5)
    }
    static var mapUnvisitedStroke: Color {
        mode == .dark ? hairline : Color.black.opacity(0.16)
    }

    // MARK: Opening専用(常時固定dark。Appearance設定=Lightでも、Openingは
    // 「暗闇の中でMemoryが露光される」というcinematicな1回限りのブランド演出のため、
    // 他の全画面と違って現在のAppearance modeには追従させない。多くのアプリの
    // launch screenがsystem外観に依存せず固定なのと同じ考え方。
    static let openingSurface = hex(0x121214)
    static let openingTextPrimary = hex(0xF1F0ED)

    // MARK: Accent — terracotta(要点のみ: 主要CTA・選択中タブ)。両modeで共通。
    static let accent = hex(0xD97757)
    static var accentSoft: Color { hex(0xD97757).opacity(0.16) }
    /// accent地の上に乗せるテキスト。terracottaは中間輝度のため、mode問わず
    /// 暗いinkを使うことでAA相当のコントラストを確保する(白文字は約2.8:1でAA未達)。
    static let onAccent = hex(0x1A1310)

    // MARK: Text
    static var textPrimary: Color {
        mode == .dark ? hex(0xF1F0ED) : hex(0x1C1C1E)
    }
    static var textSecondary: Color {
        mode == .dark ? hex(0xA8A8AC) : hex(0x6B6B6E)
    }
    /// 装飾的な補助情報専用(本文には使わない)。
    static var textFaint: Color {
        mode == .dark ? hex(0x6E6E72) : hex(0x9C9C9F)
    }

    // MARK: Glass(操作要素専用。写真・feedコンテンツには使わない)
    /// Bottom Nav・floating controls・小型CTA等、「操作するもの」だけに使う
    /// ガラス面。iOS 26 SDK(deployment target 26.4)のnative Materialを使い、
    /// 強いwhite stroke・大量blur・虹色反射は避ける。
    static var glassMaterial: Material {
        mode == .dark ? .ultraThinMaterial : .regularMaterial
    }
    /// Glass面の縁取り(1px未満に見える極薄hairline)。
    static var glassStroke: Color {
        mode == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }
    /// Glass面の内側にごく薄く乗せるhighlight(強いwhite strokeにしない)。
    static var glassHighlight: Color {
        mode == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.5)
    }
    static var glassShadow: Color {
        mode == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.12)
    }

    // MARK: Typography
    /// display: serif(SwiftUI標準の.serif design、フォントファイル同梱不要)。
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// body: system sans。段階はweightで表現する。
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// caption: bodyと同じdesignだが、呼び出し側の意図を明確にするため別名を用意。
    static func caption(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // MARK: Spacing(余裕のあるeditorialな余白スケール)
    static let screenPadding: CGFloat = 24
    static let sectionGap: CGFloat = 36
    static let stackGap: CGFloat = 14
    static let tapMinimum: CGFloat = 44

    // MARK: Radius
    static let radiusPhotoCard: CGFloat = 20
    static let radiusControl: CGFloat = 14
    static let radiusPill: CGFloat = 999

    // MARK: Shadow(暗面/白面どちらでも効く柔らかいelevation。1層のみ、多用しない)
    static var shadowColor: Color {
        mode == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.14)
    }
    static let shadowRadius: CGFloat = 24
    static let shadowY: CGFloat = 14

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - Glass components(操作要素専用)

/// Bottom Nav・floating controls等、「操作するもの」に使う共通ガラス背景。
/// 写真・feedコンテンツには絶対に使わない(PhotoSurfaceとは別系統)。
struct PictriGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = PictriDarkTheme.radiusPill
    var shadowEnabled: Bool = true

    func body(content: Content) -> some View {
        content
            .background(PictriDarkTheme.glassMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PictriDarkTheme.glassStroke, lineWidth: 0.75)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PictriDarkTheme.glassHighlight, lineWidth: 0.5)
                    .blendMode(.plusLighter)
                    .padding(0.5)
            }
            .shadow(
                color: shadowEnabled ? PictriDarkTheme.glassShadow : .clear,
                radius: shadowEnabled ? 16 : 0,
                x: 0,
                y: shadowEnabled ? 6 : 0
            )
    }
}

extension View {
    /// 操作要素(nav・floating control・小型CTA)専用のglass仕上げ。
    func pictriGlass(cornerRadius: CGFloat = PictriDarkTheme.radiusPill, shadow: Bool = true) -> some View {
        modifier(PictriGlassBackground(cornerRadius: cornerRadius, shadowEnabled: shadow))
    }
}
