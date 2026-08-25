import SwiftUI
import UIKit

// MARK: - Permission Block
//
// カメラ・位置情報の権限が使えない状態を、ユーザーに黙って偽の写真を
// 撮らせたりせず、はっきり説明して「設定を開く」まで導くための共通ビュー。
// CameraView から権限拒否・シミュレーター未対応・位置情報拒否の3パターンで使う。

// 撮影を完全に止める2状態(カメラ/位置情報の権限拒否)だけがここを使う。
// 「範囲外」「シミュレーター」は撮影を完全には止めないため、CameraView側の
// PictriStatusCard 1枚に集約し、ここでは扱わない(重ね書き防止)。
enum PictriPermissionKind {
    case cameraDenied
    case locationDenied

    var systemImage: String {
        switch self {
        case .cameraDenied: return "camera.metering.unknown"
        case .locationDenied: return "location.slash.fill"
        }
    }

    /// Visual Foundation Part C。二次画面向けの控えめなイラストアクセント
    /// (PictriFinalTheme.secondaryXxx、「訪問実績」を語らない場所専用)。
    /// カメラ拒否=暖色寄りのcoral、位置情報拒否=静かなlavenderで役割を分ける。
    var accentColor: Color {
        switch self {
        case .cameraDenied: return PictriFinalTheme.secondaryCoral
        case .locationDenied: return PictriFinalTheme.secondaryLavender
        }
    }

    var title: String {
        switch self {
        case .cameraDenied:
            return "カメラの使用が許可されていません"
        case .locationDenied:
            return "位置情報が必要です"
        }
    }

    var message: String {
        switch self {
        case .cameraDenied:
            return "設定からカメラを許可してください。外の景色と、あなたの表情を一緒に残します。"
        case .locationDenied:
            return "現地に行ったことを確認するために使います。正確な住所は誰にも表示されません。"
        }
    }
}

/// Visual Foundation Part C。以前は`.system(size:)`の生フォント+白黒ボタンで、
/// Home/Camera本体の他の画面と地続きに見えなかった(=「よくあるAI生成アプリ」感の
/// 出どころの1つ)。暗いカメラviewport上のオーバーレイという文脈(paper基調へは
/// 変えられない)は維持しつつ、PictriTypography・secondaryアクセント色・
/// Camera本体の保存ボタンと同じviolet Capsuleボタンへ揃えた。構造(icon→title→
/// message→button)・アニメーション・タップ動線は無変更。
struct PictriPermissionBlock: View {
    let kind: PictriPermissionKind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 68, height: 68)
                .overlay {
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(kind.accentColor)
                }
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(kind.title)
                    .font(PictriTypography.display(18))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(kind.message)
                    .font(PictriTypography.body(13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Button {
                openSettings()
            } label: {
                Text("設定を開く")
                    .font(PictriTypography.body(15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(PictriFinalTheme.onAccent)
                    .background(PictriFinalTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 220)
            .frame(minHeight: 44)
            .accessibilityLabel("設定アプリを開いて権限を許可する")
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 26)
        .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
        .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.97))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                appeared = true
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}
