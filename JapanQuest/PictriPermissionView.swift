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

struct PictriPermissionBlock: View {
    let kind: PictriPermissionKind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(kind.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(kind.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Button {
                openSettings()
            } label: {
                Text("設定を開く")
            }
            .buttonStyle(.pictriPrimary)
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
