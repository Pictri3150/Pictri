import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - CAMERA LAYOUT CLEANUP ROUND「2 MODES ONLY」
//
// 2つのCamera Style(標準/デジカメ)を表す最小限の型。既存Memory保存
// (QuestMemoryPhoto/QuestMemoryStore)には一切追加フィールドを持たせない
// (Schema migration不要を優先する、という今回の明示的な指示に従う)。
// styleは撮影セッション中のView側の一時的な選択でしかなく、実際の効果は
// 「撮影1回ごとに1回だけ」適用される画像処理(PictriCameraStyleProcessor)
// として現れる。ライブpreview全体へ毎frame適用するような重い処理は行わない。
//
// 「風景」モードは今回のCamera Layout Cleanup Roundで完全に削除した
// (UI selector・enum case・3x3 grid overlay・関連processing branchすべて)。
// 既存ユーザーが`@AppStorage("pictriLastCameraStyle")`に旧"scenery"文字列を
// 保存している可能性があるため、`PictriCameraStyle(rawValue:)`が
// 未知の文字列に対して確実に`.standard`へfallbackすること
// (CameraView.swiftの`cameraStyle`computed propertyのgetter、`?? .standard`)
// をこのenum定義自体では保証できないため、呼び出し側で保証している——
// クラッシュ・invalid rawValue・空状態にはならない。
// MARK: - Shared Photo Aspect Ratio (CAMERA IMAGING ROUND 2「PART 8」)
//
// Home Post / Camera Preview / Reviewの3箇所が同じ写真比率を表示するための、
// 唯一のsource of truth。以前は`0.78 * 0.517 / 0.600`(理論式、実際には
// 効いていなかった)→`313.56 / 432.83`(実測値)という2つのリテラルが
// CameraView.swiftとPictriCameraStyle.swiftへ別々に書かれていた。今回1つの
// named constantへ統合し、3箇所すべてがこれだけを参照する。
//
// Home本体ファイル(PictriHomeCarouselLayoutMetrics.swift)はCAMERA / POST
// IMAGING ROUNDのFreeze方針により不変のまま——この値はHome側の実際の
// 描画結果(cardWidth 313.56pt / cardHeight 432.83pt、heroHeightBoost適用後)を
// DEBUG計測harnessで実測して得た値をCamera側でリテラルとして再現したもの
// (計測方法・生データはscratchpad/camera_imaging_round/03_POST_GEOMETRY.txt
// 参照)。Homeのレイアウトを将来変更する場合は、この値も併せて再測定・
// 更新する必要がある。
nonisolated enum PictriPhotoGeometry {
    static let displayAspectRatio: CGFloat = 313.56 / 432.83
}

enum PictriCameraStyle: String, CaseIterable, Identifiable {
    case standard
    case digicam

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "標準"
        case .digicam: return "デジカメ"
        }
    }

    var accessibilityLabel: String {
        "\(displayName)モード"
    }

    /// デジカメモードだけ、flash controlを撮影コントロールの一部として扱う。
    var showsFlashControl: Bool {
        self == .digicam
    }
}

/// CAMERA / POST IMAGING ROUND「PART 13 — LIVE/FULL RECIPE CONSISTENCY」。
/// Digicamの見た目を決める全パラメータを1つのmodelへ集約する。Live Preview
/// (QuestDigicamLiveFrameProcessor、低解像度frame・軽量recipe)と最終撮影
/// (PictriCameraStyleProcessor.applyDigicamLook、フル解像度・フルrecipe)が
/// 別々のmagic numberを持たないよう、両方がこの1つのmodelだけを参照する。
///
/// PART 10/14/18(DIGICAM_PROFILE.md)研究結果に基づく値の転換:
/// - bloom: 0.55/radius7 → 0.22/radius4(「フィルターアプリ感」の主因だった
///   ため大幅に弱める。実際のコンパクト機は晴天順光でここまで滲まない)。
/// - vignette: 0.10 → 0.035(film/トイカメラの記号であり、コンパクトデジカメの
///   通常撮影ではほぼ目立たない特徴のため、ほぼ検知できない程度まで弱める)。
/// - saturation/contrastはRound 4の値を維持(実機評価で「標準との差が
///   分かる」水準として確定済みのため、今回はゼロベース評価の結果として
///   「妥当」と判断し、変更しない)。
nonisolated struct PictriDigicamProfile {
    var saturation: Double
    var contrast: Double
    var brightness: Double
    var highlightAmount: Double
    var shadowAmount: Double
    var colorMatrixR: CIVector
    var colorMatrixG: CIVector
    var colorMatrixB: CIVector
    var colorMatrixBias: CIVector
    var bloomIntensity: Double
    var bloomRadius: Double
    var sharpenAmount: Double
    var noiseAlpha: Double
    var vignetteIntensity: Double
    var vignetteRadius: Double

    /// 最終撮影(フル解像度)用。全effect込み。
    static let full = PictriDigicamProfile(
        saturation: 1.16,
        contrast: 1.20,
        brightness: 0.015,
        highlightAmount: 1.15,
        shadowAmount: -0.08,
        colorMatrixR: CIVector(x: 1.03, y: 0, z: 0, w: 0),
        colorMatrixG: CIVector(x: 0, y: 1.01, z: 0.01, w: 0),
        colorMatrixB: CIVector(x: 0.01, y: 0, z: 0.97, w: 0),
        colorMatrixBias: CIVector(x: 0, y: 0, z: 0.004, w: 0),
        bloomIntensity: 0.22,
        bloomRadius: 4.0,
        sharpenAmount: 0.45,
        noiseAlpha: 0.06,
        vignetteIntensity: 0.035,
        vignetteRadius: 1.8
    )

    /// Live Preview(低解像度・毎frame)用の軽量版。色/コントラスト/色転びのみ
    /// (bloom・sharpen・noise・vignetteは省略——30fps近辺を維持するための
    /// PART 12パフォーマンス要件。それでも色の傾向は最終写真とほぼ一致する)。
    static let liveFast = PictriDigicamProfile(
        saturation: full.saturation,
        contrast: full.contrast,
        brightness: full.brightness,
        highlightAmount: full.highlightAmount,
        shadowAmount: full.shadowAmount,
        colorMatrixR: full.colorMatrixR,
        colorMatrixG: full.colorMatrixG,
        colorMatrixB: full.colorMatrixB,
        colorMatrixBias: full.colorMatrixBias,
        bloomIntensity: 0,
        bloomRadius: 0,
        sharpenAmount: 0,
        noiseAlpha: 0,
        vignetteIntensity: 0,
        vignetteRadius: 1.8
    )
}

/// 撮影1回ごとに1回だけ適用する軽量な画像処理。Core Imageの標準filterのみを
/// 使用し、private APIは使わない。
enum PictriCameraStyleProcessor {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func apply(_ style: PictriCameraStyle, to image: UIImage) -> UIImage {
        switch style {
        case .standard:
            // 「iPhone Cameraの自然な色を尊重。強いfilter禁止」— 無加工のまま返す。
            return image
        case .digicam:
            return applyDigicamLook(to: image) ?? image
        }
    }

    /// CIImage段階でPictriDigicamProfileを適用する共有コア(crop/UIImage変換は
    /// 呼び出し側の責務)。Live Preview(QuestDigicamLiveFrameProcessor)と
    /// 最終撮影(applyDigicamLook)の両方がこの1つの関数だけを呼ぶ。
    nonisolated static func applyProfile(_ profile: PictriDigicamProfile, to ciImage: CIImage) -> CIImage? {
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = Float(profile.saturation)
        colorControls.contrast = Float(profile.contrast)
        colorControls.brightness = Float(profile.brightness)
        guard let colorOutput = colorControls.outputImage else { return nil }

        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = colorOutput
        highlightShadow.highlightAmount = Float(profile.highlightAmount)
        highlightShadow.shadowAmount = Float(profile.shadowAmount)
        guard let highlightShadowOutput = highlightShadow.outputImage else { return nil }

        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = highlightShadowOutput
        colorMatrix.rVector = profile.colorMatrixR
        colorMatrix.gVector = profile.colorMatrixG
        colorMatrix.bVector = profile.colorMatrixB
        colorMatrix.biasVector = profile.colorMatrixBias
        guard var current = colorMatrix.outputImage else { return nil }

        if profile.bloomIntensity > 0 {
            let bloom = CIFilter.bloom()
            bloom.inputImage = current
            bloom.intensity = Float(profile.bloomIntensity)
            bloom.radius = Float(profile.bloomRadius)
            guard let bloomOutput = bloom.outputImage else { return nil }
            current = bloomOutput
        }

        if profile.sharpenAmount > 0 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = current
            sharpen.sharpness = Float(profile.sharpenAmount)
            guard let sharpenOutput = sharpen.outputImage else { return nil }
            current = sharpenOutput
        }

        if profile.noiseAlpha > 0 {
            current = applyDigitalNoise(to: current, extent: ciImage.extent, alpha: profile.noiseAlpha)
        }

        if profile.vignetteIntensity > 0 {
            let vignette = CIFilter.vignette()
            vignette.inputImage = current
            vignette.intensity = Float(profile.vignetteIntensity)
            vignette.radius = Float(profile.vignetteRadius)
            guard let vignetteOutput = vignette.outputImage else { return nil }
            current = vignetteOutput
        }

        return current
    }

    /// 2000年代〜2010年代のコンパクトデジカメを思わせる見た目。研究結果
    /// (17_DIGICAM_RESEARCH.md)に基づき、bloom/vignetteはPictriDigicamProfile.full
    /// で大幅に弱めた値を使う。全てCore Imageの標準filterのみ(private API
    /// 不使用)、撮影1回につき1回だけ実行。
    private static func applyDigicamLook(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent

        guard let output = applyProfile(.full, to: ciImage) else { return nil }
        return render(output.cropped(to: extent), orientation: image.imageOrientation, scale: image.scale)
    }

    /// 極めて低いopacityのデジタルノイズをCIRandomGenerator + CISourceOverCompositing
    /// で合成する。film grainのような塊感ではなく、センサーノイズらしい細かい粒立ちに
    /// なるよう、alphaを`CIColorMatrix`で指定値まで落としてから重ねる。
    nonisolated private static func applyDigitalNoise(to image: CIImage, extent: CGRect, alpha: Double) -> CIImage {
        guard let noiseGenerator = CIFilter(name: "CIRandomGenerator"),
              let noiseImage = noiseGenerator.outputImage else {
            return image
        }

        let alphaMatrix = CIFilter.colorMatrix()
        alphaMatrix.inputImage = noiseImage.cropped(to: extent)
        alphaMatrix.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        alphaMatrix.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        alphaMatrix.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        alphaMatrix.aVector = CIVector(x: alpha, y: alpha, z: alpha, w: 0)

        guard let noiseAlphaOutput = alphaMatrix.outputImage else { return image }

        let composite = CIFilter.sourceOverCompositing()
        composite.inputImage = noiseAlphaOutput
        composite.backgroundImage = image

        return composite.outputImage ?? image
    }

    private static func render(
        _ ciImage: CIImage,
        orientation: UIImage.Orientation,
        scale: CGFloat
    ) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }
}

// MARK: - Shutter tactile feedback
//
// CAMERA ROUND 2「SHUTTER POLISH」+「HAPTICS」。押した瞬間にスケールダウンする
// tactileなbutton style。既存の`.disabled`状態はSwiftUIが自動的に処理するため
// ここでは追わない(isEnabledに応じた見た目自体は呼び出し側のCircle().fillが担う)。
struct PictriShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 「Shutter・Side completed・Mode switch・Save success」の4箇所だけに軽いhapticを
/// 許可する(過剰な連続hapticは禁止)。private APIは使わず標準のUIFeedbackGeneratorのみ。
enum PictriCameraHaptics {
    static func shutterTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func sideCompleted() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func modeSwitch() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func saveSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Two-Sided Capture / Review Card
//
// PictriHomeMemoryCard(Home Recentの投稿Card)と同じ「単一rotation3DEffect +
// scaleEffect(x:-1)の鏡像補正 + Reduce Motion時はaffine squeeze」という技法を
// Camera Review画面向けに再利用する。Home側のファイル自体は一切変更しない
// (Home Freeze遵守)。corner radiusはPictriHomeCardTheme.cornerRadiusを共有し、
// Post本体とのgeometry一貫性を保つ。
struct PictriCameraTwoSidedReviewCard: View {
    let frontLabel: String
    let backLabel: String
    /// 表 = 外カメラ(場所)の生画像。裏 = 内カメラ(自分)の生画像。
    /// Home側のoutrOnlyImage/selfieImageと同じ意味付け。
    let frontImage: UIImage?
    let backImage: UIImage?
    var onRetakeFront: (() -> Void)?
    var onRetakeBack: (() -> Void)?
    /// 片面だけ撮り直した直後は、撮り直した面を先に見せたい。既定はtrue(表から)。
    var initialSideIsFront: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showFront = true
    @State private var isFlipped = false
    @State private var reducedFlipSqueeze: CGFloat = 1

    private var flipDuration: Double { reduceMotion ? 0.001 : 0.5 }
    private let reducedFlipHalfDuration: Double = 0.18

    private var canFlip: Bool { frontImage != nil && backImage != nil }

    private var outerFlipDegrees: Double {
        reduceMotion ? 0 : (isFlipped ? 180 : 0)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if showFront {
                    photoLayer(frontImage)
                } else {
                    photoLayer(backImage)
                }
            }
            .transition(.opacity)

            sideChip
                .padding(12)

            if let retake = showFront ? onRetakeFront : onRetakeBack {
                retakeButton(action: retake)
                    .padding(12)
            }
        }
        // CAMERA URGENT CORRECTION ROUND: 撮影中のviewport(CameraView.
        // homeCardDisplayAspect)と同じ比率にし、「撮影中に見た形」と
        // 「確認画面で見る形」が食い違わないようにする。写真そのもの
        // (raw 1080:1920)は.scaledToFill()で無変更のままこの枠に収める。
        // CAMERA LAYOUT CLEANUP ROUND: 写真の周囲/裏側に見えていた白いoutline
        // (stroke)を削除した。Reviewは「写真そのもの」だけを見せ、別レイヤーの
        // 縁取りは持たない(shadowのみ、cameraPanelと同じ最小構成)。
        // CAMERA / POST IMAGING ROUND「PART 4 — 3-surface consistency」。
        // CameraView.homeCardDisplayAspectと同じ実測リテラル(313.56/432.83、
        // iPhone 17 Proでheroターゲット比率を実測して導出。理論式ではなく
        // `HomeView.heroCap`実測値が根拠、詳細はCameraView.swift該当コメント
        // 参照)を使う。Camera Preview / Review / Home Postの3つのratioを
        // 常に一致させる。
        .aspectRatio(PictriPhotoGeometry.displayAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous))
        .scaleEffect(x: (reduceMotion ? reducedFlipSqueeze : (showFront ? 1 : -1)), y: 1)
        .rotation3DEffect(.degrees(outerFlipDegrees), axis: (x: 0, y: 1, z: 0))
        .shadow(color: PictriDarkTheme.shadowColor, radius: 14, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: PictriHomeCardTheme.cornerRadius, style: .continuous))
        .onTapGesture { flip() }
        .accessibilityAddTraits(canFlip ? .isButton : [])
        .accessibilityLabel(
            canFlip
                ? (showFront ? "\(frontLabel)の写真。タップすると\(backLabel)を表示" : "\(backLabel)の写真。タップすると\(frontLabel)に戻る")
                : (showFront ? "\(frontLabel)の写真" : "\(backLabel)の写真")
        )
        .onAppear {
            if !initialSideIsFront {
                showFront = false
                isFlipped = true
            }
        }
    }

    @ViewBuilder
    private func photoLayer(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                PictriDarkTheme.surfaceOverlay
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
        }
    }

    private var sideChip: some View {
        Text(showFront ? frontLabel : backLabel)
            .font(PictriTypography.mono(11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.42))
            .clipShape(Capsule())
    }

    private func retakeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.42))
                .clipShape(Circle())
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .accessibilityLabel(showFront ? "\(frontLabel)を撮り直す" : "\(backLabel)を撮り直す")
    }

    private func flip() {
        guard canFlip else { return }
        if reduceMotion {
            withAnimation(.easeInOut(duration: reducedFlipHalfDuration)) {
                reducedFlipSqueeze = 0.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + reducedFlipHalfDuration) {
                showFront.toggle()
                isFlipped.toggle()
                withAnimation(.easeInOut(duration: reducedFlipHalfDuration)) {
                    reducedFlipSqueeze = 1
                }
            }
            return
        }
        withAnimation(.easeInOut(duration: flipDuration)) {
            isFlipped.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + flipDuration / 2) {
            showFront.toggle()
        }
    }
}
