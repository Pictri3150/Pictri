import SwiftUI
import UIKit

// MARK: - Permission Block
//
// カメラ・位置情報の権限が使えない状態を、ユーザーに黙って偽の写真を
// 撮らせたりせず、はっきり説明して「設定を開く」まで導くための共通ビュー。
// CameraView から権限拒否・シミュレーター未対応・位置情報拒否の3パターンで使う。

enum PictriPermissionKind {
    case cameraDenied
    case cameraUnavailable
    case locationDenied
    case outOfRange(spotName: String, distanceText: String)

    var systemImage: String {
        switch self {
        case .cameraDenied: return "camera.metering.unknown"
        case .cameraUnavailable: return "camera.metering.none"
        case .locationDenied: return "location.slash.fill"
        case .outOfRange: return "figure.walk"
        }
    }

    var title: String {
        switch self {
        case .cameraDenied:
            return "カメラの使用が許可されていません"
        case .cameraUnavailable:
            return "シミュレーターではカメラを使用できません"
        case .locationDenied:
            return "位置情報が必要です"
        case .outOfRange(let spotName, _):
            return "\(spotName)の近くで撮影できます"
        }
    }

    var message: String {
        switch self {
        case .cameraDenied:
            return "設定からカメラを許可してください。外の景色と、あなたの表情を一緒に残します。"
        case .cameraUnavailable:
            return "実機で開くとカメラが起動します。ここではデモ画像で操作を確認できます。"
        case .locationDenied:
            return "現地に行ったことを確認するために使います。正確な住所は誰にも表示されません。"
        case .outOfRange(_, let distanceText):
            return "現在地から \(distanceText)。近づくとシャッターが解放されます。"
        }
    }

    var showsSettingsButton: Bool {
        switch self {
        case .cameraDenied, .locationDenied:
            return true
        case .cameraUnavailable, .outOfRange:
            return false
        }
    }
}

struct PictriPermissionBlock: View {
    let kind: PictriPermissionKind
    var isCompact: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            Image(systemName: kind.systemImage)
                .font(.system(size: isCompact ? 30 : 40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(kind.title)
                    .font(.system(size: isCompact ? 16 : 19, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(kind.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if kind.showsSettingsButton {
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
        }
        .padding(.horizontal, 26)
        .padding(.vertical, isCompact ? 18 : 26)
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
