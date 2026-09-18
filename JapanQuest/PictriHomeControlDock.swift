import SwiftUI

// MARK: - Home v18 — DARK GLASS FLOATING BAR
//
// v17は「独立したカプセルが浮いている」構造そのものを確立したが、表面は
// `surfaceRaised`単色+ごく弱いグラデーションのみで、平面的な濃いグレーの
// 板に見えていた。v18はこの浮遊構造・寸法方針(container幅基準、
// 固定機種判定なし)をそのまま維持し、バー表面だけを「暗いスモークガラス」
// へ作り直す。iOS 26 SDK(Deployment Target 26.4)で正式に提供されている
// Liquid Glass API `View.glassEffect(_:in:)`(`SwiftUICore`、`SwiftUI`から
// 再export)をガラスの基礎層として使用し、その上へ暗いTint・方向性のある
// 反射・外周エッジ・内側陰影を個別レイヤーとして重ねる(Materialを1枚
// 置いただけで済ませない)。
//
// 中央カメラボタンも同じ理由で全面書き直し、直径をv17比で拡大しつつ
// 「台座→外周リング→内側リング→ラベンダーのガラス面→アイコン」の
// 5層構成にし、押下時のみ控えめなscale/shadow反応を追加する。
/// Round「WORLD INTERACTIVE MAP / DIRECT HOME NAVIGATION」で追加、
/// Round「NAVIGATION DOCK ROUND 2.1」で仕様を確定。Dockを呼び出しているのが
/// 今どの主要画面かを表す。
///
/// Round 2の反省(このRoundで修正した問題): 旧実装は「自分自身を指す
/// ボタン」をそのスロットごとHomeへ置換していたため、Map画面では左が
/// Home・Album画面では右がHomeになり、「左=Map/右=Album」というボタンの
/// 位置的な意味が画面によって変わってしまっていた(muscle memoryを壊す
/// Navigation不整合)。Round 2.1では左右の意味(Map/Album)を全画面で
/// 完全固定し、代わりに「中央」をHome画面だけCamera・Map/Album画面では
/// Homeへ切り替える方式に変更した。
enum PictriPrimaryScreen {
    case home
    case map
    case album
}

struct PictriHomeControlDock: View {
    /// Homeの外側GeometryReaderが実測したcontainer幅。バー自身は
    /// 新たなGeometryReaderをネストせず、この値だけから寸法を算出する。
    let containerWidth: CGFloat
    let onMapTap: () -> Void
    let onCameraTap: () -> Void
    let onAlbumTap: () -> Void
    /// Map/Album画面で中央のHomeボタンから使う。既定`{}`(Home自身は中央が
    /// Cameraのままのため、この引数自体を渡さない)。
    var onHomeTap: () -> Void = {}
    /// 呼び出し元の画面。既定`.home`(Home側の既存呼び出しはこの引数自体を
    /// 渡さないため、常に`.home`=旧来通り[Map][Camera][Album]のまま)。
    var currentScreen: PictriPrimaryScreen = .home

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 左slot: 常に「マップ」(位置・意味を画面によって変えない、Round 2.1の
    /// 核心要求)。既にMap画面にいる場合のみactionをno-opにする(自分自身への
    /// 再navigationを避けるだけで、アイコン/ラベル/位置は不変)。
    private var leftSlot: (icon: String, label: String, isActive: Bool, action: () -> Void) {
        ("mappin.and.ellipse", "マップ", currentScreen == .map, currentScreen == .map ? {} : onMapTap)
    }

    /// 右slot: 常に「アルバム」。Album画面にいる場合のみactionをno-opにする。
    private var rightSlot: (icon: String, label: String, isActive: Bool, action: () -> Void) {
        ("photo.on.rectangle", "アルバム", currentScreen == .album, currentScreen == .album ? {} : onAlbumTap)
    }

    /// 中央slot: Homeでは既存のCamera、Map/AlbumではHomeへ戻るボタン。
    /// 物理的な円形control(diameter/lift/位置)は完全に共有し、中身
    /// (icon・action・ガラス面の彩度)だけを`PictriHomeDockCenterButton`が
    /// 切り替える(Dock Geometryが画面遷移で動かないことがRound 2.1の
    /// 明示要件)。
    private var centerIsHome: Bool { currentScreen != .home }

    private var barWidth: CGFloat {
        PictriHomeFloatingBarMetrics.barWidth(containerWidth: containerWidth)
    }
    private var barHeight: CGFloat {
        PictriHomeFloatingBarMetrics.barHeight(containerWidth: containerWidth)
    }
    private var cameraDiameter: CGFloat {
        PictriHomeFloatingBarMetrics.cameraDiameter(containerWidth: containerWidth)
    }
    private var sideItemWidth: CGFloat {
        PictriHomeFloatingBarMetrics.sideItemWidth(containerWidth: containerWidth)
    }
    private var totalVisualHeight: CGFloat {
        PictriHomeFloatingBarMetrics.totalVisualHeight(containerWidth: containerWidth)
    }

    var body: some View {
        ZStack {
            PictriHomeGlassCapsule()
                .frame(width: barWidth, height: barHeight)

            HStack(spacing: 0) {
                dockItem(icon: leftSlot.icon, label: leftSlot.label, isActive: leftSlot.isActive, action: leftSlot.action)
                    .frame(width: sideItemWidth)

                // 中央カメラボタンの直径ぶんだけ確実に空けておく専用列。
                // ボタン自身はこのZStackへ別レイヤーとして重なるため、
                // ここは3列レイアウトの位置合わせ専用の透明スペーサー。
                Spacer(minLength: 0)

                dockItem(icon: rightSlot.icon, label: rightSlot.label, isActive: rightSlot.isActive, action: rightSlot.action)
                    .frame(width: sideItemWidth)
            }
            .frame(width: barWidth, height: barHeight)

            // NAVIGATION DOCK ROUND 2.1: Home画面ではCamera、Map/Album画面
            // ではHomeへ戻るボタン。`PictriHomeDockCenterButton`が同じ
            // diameter/lift/`PictriCameraButtonStyle`を共有するため、
            // 遷移してもDock Geometry(幅・高さ・中央位置・突出量)は
            // 一切動かない(このRoundの明示的な必須要件)。
            Button(action: centerIsHome ? onHomeTap : onCameraTap) {
                PictriHomeDockCenterButton(diameter: cameraDiameter, kind: centerIsHome ? .home : .camera)
            }
            .buttonStyle(PictriCameraButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel(centerIsHome ? "ホーム" : "カメラ")
            // バー中心からcameraLiftぶんだけ上へ持ち上げる。突出量
            // (Metrics側`cameraTopProtrusion`)はこのoffsetと
            // `barHeight`・`cameraDiameter`から一意に導出される値と一致する。
            .offset(y: -PictriHomeFloatingBarMetrics.cameraLift)
        }
        .frame(width: barWidth, height: totalVisualHeight, alignment: .bottom)
        .frame(maxWidth: .infinity)
    }

    /// `isActive`は既定`false`(Home側呼び出しは引数を渡さないため常にfalse、
    /// Homeの見た目は無変更)。Map/Albumが自分自身を指すitemだけ`true`を渡すと、
    /// Referenceの「lavenderのlabel + 小さいdot」を表示する。
    private func dockItem(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                Text(label)
                    .font(PictriTypography.body(9.5, weight: .bold))
                // `isActive == false`(Home側の既定経路)ではこの子要素自体が
                // VStackに存在しない。`.clear`で色だけ消す実装だと、常に
                // 3pt+spacing分のレイアウト領域を消費してしまいHome Dockの
                // 幾何(凍結対象)が変わってしまうため、`if`で要素自体を出し分ける。
                if isActive {
                    Circle()
                        .fill(PictriHomeBrandAccent.accent)
                        .frame(width: 3, height: 3)
                }
            }
            .foregroundStyle(isActive ? PictriHomeBrandAccent.accent : PictriDarkTheme.textFaint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: PictriDarkTheme.tapMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

// MARK: - Glass capsule surface

/// バー本体の表面。以下6層を個別に管理する:
/// 1) ガラスの基礎層(iOS 26 Liquid Glass、未満はMaterial fallback)
/// 2) 暗いスモークTint 3) 左上→右下の表面反射 4) 方向性のある外周エッジ
/// 5) 内側ハイライト/シャドウ(Capsule内部へmask) 6) 外側の浮遊影。
private struct PictriHomeGlassCapsule: View {
    private var shape: Capsule { Capsule(style: .continuous) }

    var body: some View {
        ZStack {
            glassBase
            smokeTint
            surfaceSheen
            innerHighlight
            innerShadow
            edgeHighlightBorder
        }
        // 6) 外側の浮遊影。広い浮遊影+接地影の2層は維持しつつ、薄い上部
        // 反射光を1層追加する(バー全体を紫に発光させない)。
        .shadow(color: Color.black.opacity(0.36), radius: 22, x: 0, y: 13)
        .shadow(color: Color.black.opacity(0.28), radius: 6, x: 0, y: 4)
        .shadow(color: Color.white.opacity(0.035), radius: 5, x: 0, y: -2)
    }

    /// 1) ガラスの基礎層。Deployment Target(26.4)は既にiOS 26以上のため
    /// `glassEffect(_:in:)`(SwiftUICore/iOS 26公式Liquid Glass API、
    /// インストール済みSDKのシンボルテーブルで存在確認済み)を無条件に
    /// 使用できるが、将来Deployment Targetが引き下げられた場合に備え
    /// 明示的な`#available`分岐を残す。未満の場合は`ultraThinMaterial`
    /// 系(`PictriDarkTheme.glassMaterial`)へfallbackする。
    @ViewBuilder
    private var glassBase: some View {
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(PictriDarkTheme.glassMaterial)
        }
    }

    /// 2) 暗いスモークTint。透明な白いガラスではなく「黒いスモークガラス」
    /// にするための地色。Home背景(surfaceBase)よりわずかに明るい
    /// surfaceRaisedを基調にし、上がわずかに明るく下が深くなる弱い
    /// グラデーションにする。
    private var smokeTint: some View {
        shape.fill(
            LinearGradient(
                colors: [
                    PictriDarkTheme.surfaceRaised.opacity(0.64),
                    PictriDarkTheme.surfaceBase.opacity(0.80)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// 3) 表面の反射層。
    /// v5 TASK3 ROOT CAUSE: 旧実装は`startPoint: .topLeading, endPoint:
    /// .bottomTrailing`の対角線グラデーションだったが、このCapsuleは横に
    /// 非常に長く縦に短い形状のため、対角線グラデーションは実質的に
    /// 「左が白く霞み、右が黒く沈む」という**横方向優勢の**グラデーションとして
    /// 見えていた(前ラウンドで`edgeHighlightBorder`だけ対称化したが、この層が
    /// 左右差の本当の主因だった。Final screenshotで実際に確認して特定)。
    /// 今回は禁止された「大きな左→右gradient」を避け、`startPoint: .top,
    /// endPoint: .bottom`の純粋な垂直方向グラデーションへ変更した(上から光が
    /// 当たる自然さは維持しつつ、左右は構造的に完全対称になる)。
    private var surfaceSheen: some View {
        shape.fill(
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.13), location: 0.0),
                    .init(color: PictriHomeBrandAccent.pearl.opacity(0.05), location: 0.28),
                    .init(color: Color.clear, location: 0.60),
                    .init(color: Color.black.opacity(0.16), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// 5) 内側の陰影。厚みのあるガラスに見せるため、Capsule輪郭の内側
    /// だけへ上ハイライト/下シャドウを限定する(`mask(shape)`で外へ
    /// blurが漏れないようにする — 問題を隠すためのmaskではなく、
    /// 装飾レイヤーをShape内部へ限定するためのmask)。
    private var innerHighlight: some View {
        shape
            .stroke(Color.white.opacity(0.10), lineWidth: 3)
            .blur(radius: 2)
            .offset(y: -1.4)
            .mask(shape)
    }

    private var innerShadow: some View {
        shape
            .stroke(Color.black.opacity(0.24), lineWidth: 3)
            .blur(radius: 2)
            .offset(y: 1.6)
            .mask(shape)
    }

    /// 4) 外周の反射エッジ。AngularGradientの1本のstrokeBorderで表現する
    /// (銀色の金属フレームやネオン管に見えないよう、いずれの区間も低opacityに
    /// 抑える)。
    /// v4 TASK5 DOCK QUALITY: 旧stopsは右(location 0.25、accent opacity 0.16)を
    /// 明確に強調する一方、左(location 0.75)はopacity 0.06しか無く、左右が
    /// 非対称(「左が薄く右が濃い」)で安っぽく見える原因になっていた。
    /// 上辺=最も明るい/下辺=最も暗いという垂直方向の「上からの光」の
    /// 自然さは維持しつつ、左右(0.25と0.75、0.10と0.90)を完全に鏡像対称の
    /// 値へ揃え、lavender accentも左右均等な「ごく控えめなaccent」に留めた
    /// (紫を増やして華やかにするのではなく、左右の不均衡だけを是正する)。
    private var edgeHighlightBorder: some View {
        shape.strokeBorder(
            AngularGradient(
                stops: [
                    .init(color: Color.white.opacity(0.32), location: 0.0),       // 上辺(最も明るい)
                    .init(color: PictriHomeBrandAccent.pearl.opacity(0.14), location: 0.12),
                    .init(color: PictriHomeBrandAccent.accent.opacity(0.12), location: 0.25), // 右
                    .init(color: Color.black.opacity(0.22), location: 0.40),
                    .init(color: Color.black.opacity(0.34), location: 0.50),      // 下辺(最も暗い)
                    .init(color: Color.black.opacity(0.22), location: 0.60),
                    .init(color: PictriHomeBrandAccent.accent.opacity(0.12), location: 0.75), // 左(右と対称)
                    .init(color: PictriHomeBrandAccent.pearl.opacity(0.14), location: 0.88),
                    .init(color: Color.white.opacity(0.32), location: 1.0)
                ],
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            ),
            lineWidth: PictriHomeFloatingBarMetrics.strokeWidth
        )
    }
}

// MARK: - Camera button press feedback

/// カメラボタン押下中だけ、控えめなscale/shadow反応を加える。ONE-SHOTの
/// `Button.action`はSwiftUI標準の仕組みのまま(ここでは見た目だけを変更し、
/// actionの二重実行やnavigation処理には一切関与しない)。
private struct PictriCameraButtonStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .overlay {
                Circle()
                    .fill(Color.black.opacity(pressed ? 0.08 : 0))
                    .allowsHitTesting(false)
            }
            .scaleEffect(pressed ? (reduceMotion ? 0.99 : 0.965) : 1.0)
            .shadow(color: Color.black.opacity(pressed ? 0.22 : 0.32), radius: pressed ? 10 : 15, x: 0, y: pressed ? 4 : 8)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: pressed)
    }
}

// MARK: - Camera lens

/// 中央カメラボタン。CameraをこのUIの明確な主役にするため、
/// 台座→外周リング→内側リング→ラベンダーのガラス面→アイコンの5層で
/// 構成する。Glowは使わず、layerごとの明暗差と反射の位置だけで
/// 立体感を出す(星・キラキラ・金色・オレンジ・強いネオンは使わない)。
/// NAVIGATION DOCK ROUND 2.1: 中央slotの中身(Home画面=Camera、
/// Map/Album画面=Home)。
enum PictriDockCenterKind {
    case camera
    case home
}

/// 旧`PictriHomeDockCameraLens`をHome画面のCamera専用から、中央slot共通の
/// 物理control(台座→外周リング→内側リング→ガラス面→icon)へ一般化した。
/// `kind == .camera`の描画パスは旧実装と完全に同一の値(diameter比・色・
/// gradient半径)のまま1文字も変えていない(Home Dock Geometry Freeze)。
/// `kind == .home`はicon/gradient半径だけを変え、「Cameraほど撮影レンズ的に
/// 見せない」(spec)を、新しい色tokenを増やさずgradientのendRadius比だけで
/// 表現する(pearlの占める面積を広げ、accentは縁のごく薄い滲みに留める)。
private struct PictriHomeDockCenterButton: View {
    /// 最外周(台座)の直径。
    let diameter: CGFloat
    var kind: PictriDockCenterKind = .camera

    private var outerRingDiameter: CGFloat { diameter * 0.86 }
    private var innerRingDiameter: CGFloat { diameter * 0.70 }
    private var lensDiameter: CGFloat { diameter * 0.58 }
    private var iconSize: CGFloat { max(23, min(26, diameter * 0.285)) }

    var body: some View {
        ZStack {
            // 1) 暗い台座:バーと同じスモークブラックで、ボタンがバーから
            // 自然にせり出しているように見せる(大きな山型Shapeは使わない)。
            Circle()
                .fill(
                    LinearGradient(
                        colors: [PictriDarkTheme.surfaceRaised.opacity(0.92), PictriDarkTheme.surfaceBase.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.32), lineWidth: 1.25)
                }
                .frame(width: diameter, height: diameter)

            // 2) 外周リング:太い1本ではなく、細い複数リングで奥行きを出す。
            Circle()
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                .frame(width: outerRingDiameter, height: outerRingDiameter)
                .overlay(
                    Circle()
                        .trim(from: 0.52, to: 0.98)
                        .stroke(Color.black.opacity(0.28), lineWidth: 1)
                        .frame(width: outerRingDiameter, height: outerRingDiameter)
                        .rotationEffect(.degrees(-90))
                )

            // 3) 内側リング:精密さを出すための、もう一段暗いリング。
            Circle()
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.92))
                .frame(width: innerRingDiameter, height: innerRingDiameter)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }

            // 4) ラベンダー/パール系のガラス面:中央は柔らかなパール
            // ラベンダー、外周へ向かって少し濃い紫。左上に白い小さな反射、
            // 下側にわずかな深みを別レイヤーで重ねる(単純な円形
            // LinearGradientだけで済ませない)。
            lensFace
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }

    /// `kind == .camera`: 旧実装と同じ0.62(accentが早くから支配的、
    /// 「レンズ」らしい強い発色)。`kind == .home`: 0.95まで拡げ、pearlが
    /// ほぼ全面を占め、accentは縁にごく薄く滲む程度に抑える。
    private var faceEndRadiusMultiplier: CGFloat {
        kind == .camera ? 0.62 : 0.95
    }

    /// 下側の深みレイヤーのaccent opacity。Homeでは控えめに。
    private var faceDepthOpacity: Double {
        kind == .camera ? 0.30 : 0.14
    }

    private var lensFace: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PictriHomeBrandAccent.pearl, PictriHomeBrandAccent.accent],
                        center: UnitPoint(x: 0.40, y: 0.34),
                        startRadius: 1,
                        endRadius: lensDiameter * faceEndRadiusMultiplier
                    )
                )

            // 下側のわずかな深み。
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.clear, PictriHomeBrandAccent.accent.opacity(faceDepthOpacity)],
                        center: UnitPoint(x: 0.5, y: 1.05),
                        startRadius: lensDiameter * 0.1,
                        endRadius: lensDiameter * 0.75
                    )
                )

            // 左上の小さな反射。
            Circle()
                .trim(from: 0.56, to: 0.94)
                .stroke(Color.white.opacity(0.42), lineWidth: 1.2)
                .rotationEffect(.degrees(-90))

            Circle().strokeBorder(Color.black.opacity(0.16), lineWidth: 0.75)

            Image(systemName: kind == .camera ? "camera.fill" : "house.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(PictriHomeBrandAccent.onAccent)
        }
        .frame(width: lensDiameter, height: lensDiameter)
    }
}
