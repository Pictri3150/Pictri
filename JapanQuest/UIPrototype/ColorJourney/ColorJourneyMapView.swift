import SwiftUI

// MARK: - Color Journey Map Overview
//
// Apple標準地図を全面表示せず、簡略化した日本地図シェイプ(47県のポリゴンを
// 共有スケールで合成)を主役にする「収集地図」。数字クラスタやピンは置かず、
// 訪問済み県だけを色で塗り分ける。神奈川は視覚的にもタップ対象としても
// 明確にする。下部には「次に色づけられる場所」を1件だけ表示する。

struct ColorJourneyMapView: View {
    /// 神奈川の輪郭をMap⇄SpotDetailで同一要素として連続させるための共有ID。
    /// ColorJourneySpotDetailView側も同じ文字列を参照する。
    static let kanagawaGeometryID = "colorJourney.kanagawaShape"

    let prefectureStates: [CJPrefectureColorState]
    let nextTarget: CJNextColorTarget

    /// 外部(ColorJourneyFlowView)から選択状態/タップ処理/名前空間を注入したい場合に使う。
    /// 何も渡さなければ従来通り内部@Stateだけで完結し、静的な`-pictriPrototypeScreen map`
    /// 単体表示やPreviewの見た目・挙動は一切変わらない。
    var externalIsKanagawaSelected: Bool?
    var onTapKanagawa: (() -> Void)?
    var kanagawaGeometryNamespace: Namespace.ID?

    init(
        prefectureStates: [CJPrefectureColorState],
        nextTarget: CJNextColorTarget,
        externalIsKanagawaSelected: Bool? = nil,
        onTapKanagawa: (() -> Void)? = nil,
        kanagawaGeometryNamespace: Namespace.ID? = nil
    ) {
        self.prefectureStates = prefectureStates
        self.nextTarget = nextTarget
        self.externalIsKanagawaSelected = externalIsKanagawaSelected
        self.onTapKanagawa = onTapKanagawa
        self.kanagawaGeometryNamespace = kanagawaGeometryNamespace
    }

    @State private var internalIsKanagawaSelected = false

    private var isKanagawaSelected: Bool {
        externalIsKanagawaSelected ?? internalIsKanagawaSelected
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            // mapAreaへ残りの縦スペースをすべて渡す。以前はSpacer(minLength:)を
            // nextTargetCardの直前に置いていたため、aspectRatio(.fit)の地図が
            // 幅基準の小さいサイズのまま浮き、下に大きな空白が生まれていた。
            // 「地図を主役にする」方針上、この空白は許容できない問題だったため、
            // mapArea自体をmaxHeight: .infinityにして残りスペースをすべて使わせる。
            mapArea
                .frame(maxHeight: .infinity)
                .padding(.top, CJTokens.Spacing.md)
            nextTargetCard
        }
        .background(CJTokens.Color.backgroundWarm.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("PicTri")
                    .font(CJTokens.Typography.wordmark)
                    .foregroundStyle(CJTokens.Color.textPrimary)
                Spacer()
            }
            Text("色づいた場所を集める地図")
                .font(CJTokens.Typography.caption)
                .foregroundStyle(CJTokens.Color.textSecondary)
        }
        .padding(.horizontal, CJTokens.Spacing.md)
        .padding(.top, CJTokens.Spacing.sm)
    }

    /// QuestJapanMapMetrics.canvasWidth/Height(本番のカード内表示向けに決められた
    /// 名目キャンバスサイズ)には、実際の陸地の外側に相当な余白が含まれている。
    /// このプロトタイプは地図そのものを主役にしたいため、名目キャンバスではなく
    /// 47県全ポイントの実バウンディングボックスを使ってフィットさせる。
    /// これにより、コンテナの縦横どちらが効いても陸地が最大限まで拡大される。
    private var mapBounds: (minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) {
        // 沖縄は本土から大きく離れた位置に簡略配置されているため、バウンディングボックスに
        // 含めると縦方向の余白だけが不自然に増え、本土(このプロトタイプの主題である
        // 神奈川・東京を含む)が縮んでしまう。描画は維持しつつ、フィット計算からは除外する。
        let allPoints = prefectureStates
            .filter { $0.id != "okinawa" }
            .flatMap(\.points)
        let xs = allPoints.map(\.x)
        let ys = allPoints.map(\.y)
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        let width = max((xs.max() ?? 1) - minX, 1)
        let height = max((ys.max() ?? 1) - minY, 1)
        return (minX, minY, width, height)
    }

    /// 日本の陸地バウンディングボックス(幅299.6×高さ339.5、比率0.88)は、
    /// このプロトタイプのMap overviewコンテナ(縦長・比率0.5前後)とは根本的に
    /// 縦横比が合わない。scaleを"完全にfit"(=全体が収まるが上下に大きな余白)に
    /// してしまうと、地図が主役どころか小さく浮いて見えてしまう
    /// ("地図を主役にする"方針に反する)。かといって"完全にfill"だと
    /// 西日本の大部分が切れてしまう。fitとfillの中間(55%寄り)にブレンドし、
    /// 関東・本州の主要部を保ったまま余白を大幅に削減する。
    private static let fillBlendFactor: CGFloat = 0.55

    private var mapArea: some View {
        GeometryReader { proxy in
            let bounds = mapBounds
            let fitScale = min(proxy.size.width / bounds.width, proxy.size.height / bounds.height)
            let fillScale = max(proxy.size.width / bounds.width, proxy.size.height / bounds.height)
            let scale = fitScale + (fillScale - fitScale) * Self.fillBlendFactor
            let offsetX = (proxy.size.width - bounds.width * scale) / 2 - bounds.minX * scale
            let offsetY = (proxy.size.height - bounds.height * scale) / 2 - bounds.minY * scale

            ZStack {
                ForEach(prefectureStates) { state in
                    prefecturePiece(state, scale: scale, offsetX: offsetX, offsetY: offsetY)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .padding(.horizontal, CJTokens.Spacing.sm)
    }

    /// 最小タップ領域(44pt)を下回らないよう、県ポリゴン自体の画面上バウンディングボックスを
    /// 元に少し広げたヒット領域を作る。神奈川のように細い部分がある形状でも、
    /// 見た目のポリゴンより広い範囲でタップを拾えるようにするため。
    private func screenBounds(for points: [CGPoint], scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGRect {
        let xs = points.map { $0.x * scale + offsetX }
        let ys = points.map { $0.y * scale + offsetY }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    @ViewBuilder
    private func prefecturePiece(
        _ state: CJPrefectureColorState,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> some View {
        let isKanagawa = state.id == "kanagawa"
        let isSelected = isKanagawa && isKanagawaSelected
        let shape = ColoredPrefectureCanvasShape(
            points: state.points,
            scale: scale,
            offsetX: offsetX,
            offsetY: offsetY
        )
        let fillColor = state.accentColor?.opacity(0.85) ?? CJTokens.Color.sand.opacity(0.28)
        let strokeColor = isSelected ? CJTokens.Color.textPrimary : CJTokens.Color.borderSoft
        let strokeWidth: CGFloat = isSelected ? 2 : 1

        let visibleShape = shape
            .fill(fillColor)
            .overlay { shape.stroke(strokeColor, lineWidth: strokeWidth) }
            // 選択中は軽く浮いた印象を出す(拡大+影)。常時ではなく選択中だけの一時的な強調。
            .scaleEffect(isSelected ? 1.05 : 1)
            .shadow(color: isSelected ? CJTokens.Color.textPrimary.opacity(0.18) : .clear, radius: isSelected ? 10 : 0, y: isSelected ? 4 : 0)

        Group {
            if isKanagawa, let namespace = kanagawaGeometryNamespace {
                visibleShape.matchedGeometryEffect(id: Self.kanagawaGeometryID, in: namespace)
            } else {
                visibleShape
            }
        }
        .overlay {
            if isKanagawa {
                // ポリゴン本体より広い、最低44pt四方の透明なヒット領域を重ねる。
                let bounds = screenBounds(for: state.points, scale: scale, offsetX: offsetX, offsetY: offsetY)
                let hitWidth = max(bounds.width + 16, 44)
                let hitHeight = max(bounds.height + 16, 44)
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: hitWidth, height: hitHeight)
                    .contentShape(Rectangle())
                    .position(x: bounds.midX, y: bounds.midY)
                    .onTapGesture {
                        if let onTapKanagawa {
                            onTapKanagawa()
                        } else {
                            withAnimation(.easeOut(duration: 0.2)) {
                                internalIsKanagawaSelected.toggle()
                            }
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isKanagawa ? .isButton : [])
        .accessibilityLabel(
            isKanagawa
                ? "神奈川、タップして詳細"
                : "\(state.name)、\(state.accentColor == nil ? "まだ" : "色づいた場所")"
        )
    }

    private var nextTargetCard: some View {
        HStack(spacing: CJTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("次に色づけられる場所")
                    .font(CJTokens.Typography.caption)
                    .foregroundStyle(CJTokens.Color.textSecondary)

                Text(nextTarget.spotName)
                    .font(CJTokens.Typography.stateLine)
                    .foregroundStyle(CJTokens.Color.textPrimary)

                Text("\(nextTarget.prefectureName)・\(nextTarget.areaName)")
                    .font(CJTokens.Typography.caption)
                    .foregroundStyle(CJTokens.Color.textSecondary)
            }

            Spacer(minLength: CJTokens.Spacing.xs)

            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CJTokens.Color.mutedGreen)
        }
        .padding(CJTokens.Spacing.md)
        .background(CJTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: CJTokens.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CJTokens.Radius.medium, style: .continuous)
                .stroke(CJTokens.Color.borderSoft, lineWidth: 1)
        }
        .padding(.horizontal, CJTokens.Spacing.md)
        .padding(.bottom, CJTokens.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Color Journey Map") {
    ColorJourneyMapView(
        prefectureStates: ColorJourneyPreviewData.allPrefectureColorStates,
        nextTarget: ColorJourneyPreviewData.nextColorTarget
    )
}

#Preview("Color Journey Map - Narrow") {
    ColorJourneyMapView(
        prefectureStates: ColorJourneyPreviewData.allPrefectureColorStates,
        nextTarget: ColorJourneyPreviewData.nextColorTarget
    )
    .frame(width: 375, height: 700)
}
