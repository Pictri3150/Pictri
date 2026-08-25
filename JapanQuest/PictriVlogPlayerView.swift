import SwiftUI

// MARK: - Pictri Vlog Player
//
// 「生成できたふりは禁止」の方針に沿い、これは架空の動画ファイルではなく、実際に
// その場でscene(写真)を自動再生する本物のSwiftUI体験そのものをVlogとして扱う。
// PictriVlogScript(LocalDeterministicVlogGenerator等が作る「脚本」)を受け取り、
// crossfade + 控えめなKen Burns風zoomで1枚ずつ見せる。TikTokテンプレのような
// 派手なtransition・BGM・テロップアニメーションは使わない(Product方針#7「普通の
// video editorにしない」)。
struct PictriVlogPlayerView: View {
    let script: PictriVlogScript
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var sceneIndex = 0
    @State private var isZoomed = false
    @State private var playTask: Task<Void, Never>?

    private var currentScene: PictriVlogScript.Scene? {
        script.scenes.indices.contains(sceneIndex) ? script.scenes[sceneIndex] : nil
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: script.day.date)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let currentScene {
                sceneImage(currentScene)
                    .id(currentScene.id)
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
            }

            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                captionFooter
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .statusBarHidden()
        .onAppear { play() }
        .onDisappear {
            playTask?.cancel()
        }
        .onTapGesture { advance() }
    }

    private func sceneImage(_ scene: PictriVlogScript.Scene) -> some View {
        Group {
            // Anywhere Capture Phase: curated Spotに属さないMemory(scene.spotがnil)でも
            // 常に写真を表示できるよう、photo自身から直接読む(memoryStore.image(for: photo:))。
            if let image = memoryStore.image(for: scene.photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // ink反転(dark premium統一)後、ink単体は明るいivoryになったため、
                // 画像なしフォールバックは明示的に暗いdormantを使う。
                PictriFinalTheme.dormant
            }
        }
        .scaleEffect(isZoomed ? 1.08 : 1.0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .onAppear {
            isZoomed = false
            withAnimation(.linear(duration: scene.duration)) {
                isZoomed = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(script.scenes.indices, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(index <= sceneIndex ? 0.92 : 0.30))
                        .frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.30))
                    .clipShape(Circle())
            }
            .padding(.leading, 10)
            .accessibilityLabel("閉じる")
        }
    }

    private var captionFooter: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(currentScene?.spot?.name ?? currentScene?.photo.resolvedAreaName ?? "—")
                .font(PictriTypography.body(17, weight: .bold))
                .foregroundStyle(.white)

            Text(dayLabel)
                .font(PictriTypography.mono(12, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.3), value: sceneIndex)
    }

    private func play() {
        playTask?.cancel()
        playTask = Task {
            while !Task.isCancelled {
                guard let scene = currentScene else { break }
                try? await Task.sleep(nanoseconds: UInt64(scene.duration * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await MainActor.run { advance() }
            }
        }
    }

    private func advance() {
        guard sceneIndex < script.scenes.count - 1 else {
            dismiss()
            return
        }
        sceneIndex += 1
    }
}
