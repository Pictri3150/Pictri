import SwiftUI

// MARK: - Color Bloom Transition
//
// 撮影完了の瞬間、「場所の輪郭または写真領域から色が静かに広がる」ことだけを表現する
// 最小限の演出。紙吹雪やバッジのようなゲーム演出ではなく、baseとrevealedの2レイヤーを
// 円形マスクでクロスフェードするだけの小さな部品。マスクの半径はこのView自身の
// サイズ(=呼び出し側が渡した写真フレーム領域)を基準にするため、画面全体ではなく
// 渡された領域の中だけで完結する。
//
// Reduce Motion時は円形の広がりを見せず、即座に色を切り替えた上で軽いフェードのみ行う。

struct ColorBloomTransition<Base: View, Revealed: View>: View {
    let isRevealed: Bool
    let reduceMotion: Bool
    @ViewBuilder var base: () -> Base
    @ViewBuilder var revealed: () -> Revealed

    @State private var revealProgress: CGFloat = 0

    private static var animationDuration: Double { 0.75 }
    private static var fadeDuration: Double { 0.35 }

    var body: some View {
        GeometryReader { proxy in
            let maxDiameter = hypot(proxy.size.width, proxy.size.height) + 16

            ZStack {
                base()

                revealed()
                    .opacity(reduceMotion ? revealProgress : 1)
                    .mask {
                        if reduceMotion {
                            Rectangle()
                        } else {
                            Circle()
                                .frame(width: maxDiameter * revealProgress, height: maxDiameter * revealProgress)
                                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        }
                    }
            }
        }
        .onAppear {
            revealProgress = isRevealed ? 1 : 0
        }
        .onChange(of: isRevealed) { _, newValue in
            guard newValue else {
                revealProgress = 0
                return
            }
            if reduceMotion {
                withAnimation(.easeInOut(duration: Self.fadeDuration)) {
                    revealProgress = 1
                }
            } else {
                withAnimation(.easeOut(duration: Self.animationDuration)) {
                    revealProgress = 1
                }
            }
        }
    }
}

#Preview("Color Bloom Transition") {
    ColorBloomTransition(
        isRevealed: true,
        reduceMotion: false,
        base: {
            RoundedRectangle(cornerRadius: CJTokens.Radius.large, style: .continuous)
                .fill(CJTokens.Color.sand.opacity(0.4))
        },
        revealed: {
            RoundedRectangle(cornerRadius: CJTokens.Radius.large, style: .continuous)
                .fill(CJTokens.Color.mutedGreen)
        }
    )
    .frame(width: 260, height: 340)
    .padding(40)
    .background(CJTokens.Color.backgroundWarm)
}
