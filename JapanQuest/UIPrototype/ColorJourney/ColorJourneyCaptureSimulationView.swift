import SwiftUI

// MARK: - Color Journey Capture Simulation
//
// Production CameraViewは一切使わない・変更しない、Prototype専用の撮影シミュレーション。
// AVFoundationは扱わず、外カメラ領域を大きく・内カメラ領域を小さく見せるPicTriの
// 構図だけを模したプレースホルダーで、ready→capturing→completedの3段階を表現する。
// 遷移そのもの(段階の切り替え)はColorJourneyPrototypeStoreが持ち、このViewは
// 現在のstoreの状態を描画するだけに徹する。

struct ColorJourneyCaptureSimulationView: View {
    let spotName: String
    let phase: ColorJourneyPrototypeStore.Step
    let reduceMotion: Bool
    let onShutter: () -> Void
    let onClose: () -> Void

    private var isCaptured: Bool {
        phase == .captureCompleted
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: CJTokens.Spacing.md)
            photoFrame
                .padding(.horizontal, CJTokens.Spacing.lg)
            Spacer(minLength: CJTokens.Spacing.md)
            footer
        }
        .background(CJTokens.Color.backgroundWarm.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("撮影")
                    .font(CJTokens.Typography.screenLabel)
                    .foregroundStyle(CJTokens.Color.textSecondary)
                Text(spotName)
                    .font(CJTokens.Typography.placeName)
                    .foregroundStyle(CJTokens.Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CJTokens.Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(CJTokens.Color.surface)
                    .clipShape(Circle())
                    .overlay { Circle().stroke(CJTokens.Color.borderSoft, lineWidth: 1) }
            }
            .accessibilityLabel("閉じる")
        }
        .padding(.horizontal, CJTokens.Spacing.md)
        .padding(.top, CJTokens.Spacing.sm)
    }

    /// 「場所の輪郭または写真領域から色が静かに広がる」演出のスコープそのもの。
    /// ColorBloomTransitionへ渡すbase/revealedのサイズは、このphotoFrame自身の
    /// サイズに限定される(画面全体には広がらない)。
    private var photoFrame: some View {
        ColorBloomTransition(
            isRevealed: isCaptured,
            reduceMotion: reduceMotion,
            base: { backCameraPlaceholder(captured: false) },
            revealed: { backCameraPlaceholder(captured: true) }
        )
        .aspectRatio(4 / 5, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            frontCameraPlaceholder
                .padding(CJTokens.Spacing.sm)
        }
        .overlay(alignment: .bottom) {
            if isCaptured {
                capturedStateLine
                    .padding(.bottom, CJTokens.Spacing.md)
            }
        }
    }

    /// 外カメラ(景色)側。PicTriの「外を大きく」という方向性を、実カメラなしで
    /// 面積比だけで再現する。抽象グラデーションではなく単色+アイコンのみ。
    private func backCameraPlaceholder(captured: Bool) -> some View {
        RoundedRectangle(cornerRadius: CJTokens.Radius.large, style: .continuous)
            .fill(captured ? CJTokens.Color.mutedGreen : CJTokens.Color.sand.opacity(0.35))
            .overlay {
                if !captured {
                    Image(systemName: "mountain.2")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(CJTokens.Color.textSecondary.opacity(0.5))
                }
            }
    }

    /// 内カメラ(表情)側。外カメラより明確に小さく配置し、Productionの
    /// 「外を大きく・内を小さく」という2枚撮りの考え方をシミュレーションでも維持する。
    private var frontCameraPlaceholder: some View {
        RoundedRectangle(cornerRadius: CJTokens.Radius.small, style: .continuous)
            .fill(CJTokens.Color.surface)
            .frame(width: 56, height: 74)
            .overlay {
                Image(systemName: "face.smiling")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(CJTokens.Color.textSecondary.opacity(0.6))
            }
            .overlay {
                RoundedRectangle(cornerRadius: CJTokens.Radius.small, style: .continuous)
                    .stroke(CJTokens.Color.surface, lineWidth: 2)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
            .accessibilityHidden(true)
    }

    private var capturedStateLine: some View {
        VisitStateBadge(text: "色づきました", tone: .colored)
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .captureReady:
            shutterButton

        case .capturing:
            ProgressView()
                .tint(CJTokens.Color.textSecondary)
                .frame(height: 64)
                .accessibilityLabel("処理中")

        default:
            // captureCompleted: ColorJourneyPrototypeStoreが短時間後に自動でspotVisitedへ
            // 進めるため、ここでは何も操作を要求しない(次へ、のような追加ボタンは置かない)。
            Color.clear.frame(height: 64)
        }
    }

    private var shutterButton: some View {
        Button(action: onShutter) {
            Circle()
                .stroke(CJTokens.Color.coral, lineWidth: 5)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .fill(CJTokens.Color.coral)
                        .frame(width: 58, height: 58)
                }
        }
        .accessibilityLabel("シャッターを切る")
    }
}

#Preview("Capture - Ready") {
    ColorJourneyCaptureSimulationView(
        spotName: "専修大学",
        phase: .captureReady,
        reduceMotion: false,
        onShutter: {},
        onClose: {}
    )
}

#Preview("Capture - Capturing") {
    ColorJourneyCaptureSimulationView(
        spotName: "専修大学",
        phase: .capturing,
        reduceMotion: false,
        onShutter: {},
        onClose: {}
    )
}

#Preview("Capture - Completed") {
    ColorJourneyCaptureSimulationView(
        spotName: "専修大学",
        phase: .captureCompleted,
        reduceMotion: false,
        onShutter: {},
        onClose: {}
    )
}
