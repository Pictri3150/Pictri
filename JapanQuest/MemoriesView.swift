import SwiftUI
import UIKit

// MARK: - View Mode

enum MemoriesViewMode {
    case collect
    case vlog
}

// MARK: - Memories

struct MemoriesView: View {
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var entitlementStore: QuestEntitlementStore
    @Binding var pendingExploreSpotId: String?
    /// Visual Direction Consolidation: Vlogが独立tabになったため、このViewは
    /// 呼び出し元(ContentView)がどちらのtabから開いたかを`initialMode`で受け取り、
    /// 1つの実装(NavigationStack・player state・Vlog生成ロジックを共有)のまま
    /// Memories archiveとVlog storyの2つの入口として振る舞う。既存のVlog生成
    /// ロジック(QuestVlogDayGrouping等)は複製していない。
    let initialMode: MemoriesViewMode
    @State private var viewMode: MemoriesViewMode
    @State private var navigationPath: [QuestPrefecture] = []
    @State private var playingScript: PictriVlogScript?
    @State private var showVlogPaywall = false
    @State private var showAIComingSoonAlert = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(pendingExploreSpotId: Binding<String?>, initialMode: MemoriesViewMode = .collect) {
        self._pendingExploreSpotId = pendingExploreSpotId
        self.initialMode = initialMode
        self._viewMode = State(initialValue: Self.resolveInitialMode(initialMode))
    }

    /// `-pictriMemoriesMode collect|vlog` でDEBUG QA時だけ強制的に上書きできる。
    /// 通常は呼び出し元のtab(initialMode)がそのままSource of Truth。
    private static func resolveInitialMode(_ initialMode: MemoriesViewMode) -> MemoriesViewMode {
        #if DEBUG
        return PictriVisualReview.memoriesMode ?? initialMode
        #else
        return initialMode
        #endif
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Collect/Vlogとも同じpaperシェルへ統一する(写真1枚1枚の中の黒は
                // 当然そのまま、暗いのは写真自体だけにする)。
                PictriFinalTheme.paper.ignoresSafeArea()

                if viewMode == .collect {
                    collectBody
                } else {
                    vlogBody
                }
            }
            .navigationDestination(for: QuestPrefecture.self) { prefecture in
                PrefectureMemoryDetailView(prefecture: prefecture)
            }
        }
        .fullScreenCover(item: $playingScript) { script in
            PictriVlogPlayerView(script: script)
        }
        .sheet(isPresented: $showVlogPaywall) {
            PictriPaywallSheet(entitlementStore: entitlementStore)
        }
        .onAppear {
            openPendingVlogEntryIfNeeded()
            openDebugPrefectureDetailIfRequested()
        }
        .task {
            await openDebugVlogDayIfRequested()
        }
    }

    private var vlogDays: [VlogDay] {
        QuestVlogDayGrouping.groupedByDay(memoryStore.memoryPhotos)
    }

    private var todayVlogDay: VlogDay? {
        let todayKey = QuestVlogDayGrouping.todayKey()
        return vlogDays.first { $0.dateKey == todayKey }
    }

    private var pastVlogDays: [VlogDay] {
        let todayKey = QuestVlogDayGrouping.todayKey()
        return vlogDays.filter { $0.dateKey != todayKey }
    }

    /// Camera保存直後は、今日撮った記憶がその場でVlogへ育っていくことを示すため、
    /// 単一写真のdetailではなくVlogタブの「今日」セクションへ導く
    /// (以前のExplore Detail単写真sheetはVlog導入に伴い廃止した)。
    private func openPendingVlogEntryIfNeeded() {
        guard let spotId = pendingExploreSpotId else { return }
        pendingExploreSpotId = nil

        guard memoryStore.memoryPhotos.contains(where: { $0.spotId == spotId }) else { return }
        viewMode = .vlog
    }

    /// `-pictriVlogDay <yyyy-MM-dd>` でその日のVlog再生画面を直接スクショ確認できる
    /// ようにする。DEBUG限定。既存の「今日のVlogを見る」タップと同じ
    /// LocalDeterministicVlogGeneratorの経路を使う。
    /// `.task`から呼ぶ。アプリ起動直後の最初のonAppearと同じフレームで
    /// playingScriptを立てると、NavigationStackがfullScreenCoverの提示元として
    /// まだ確立していないことがあり、提示が飛ぶ(何も開かない)ことがあった
    /// (再現性のあるSwiftUIの起動直後presentation timing問題)。`.task`は最初の
    /// レンダリングパスの外側で実行されるため、Task.yield()を1回挟んで
    /// 「次のrun loop」まで確実に待ってから状態を立てることで、この競合を回避する。
    /// Production側のタップ経路(todayVlogCard等)は同期的なplayDay(_:)のままで
    /// 未変更――このawaitはQA専用のこの関数だけに閉じている。
    private func openDebugVlogDayIfRequested() async {
        #if DEBUG
        guard let dayKey = PictriVisualReview.vlogDebugDayKey,
              let day = vlogDays.first(where: { $0.dateKey == dayKey }) else {
            return
        }
        viewMode = .vlog
        await Task.yield()
        guard playingScript == nil else { return }
        playDay(day)
        #endif
    }

    /// `-pictriMemoriesDetail <prefectureId>` でPrefecture Memoriesを直接スクショ確認できる
    /// ようにする。DEBUG限定。既存のprefecture行タップ(NavigationLink(value:))と同じ
    /// navigationPathへ積むだけなので、通常の戻る導線もそのまま機能する。
    private func openDebugPrefectureDetailIfRequested() {
        #if DEBUG
        guard navigationPath.isEmpty,
              let prefectureId = PictriVisualReview.memoriesDetailPrefectureId else {
            return
        }
        // Part Bの修正と同じSource of Truth(questPrefectureShapes優先)に揃える。
        // mockQuestPrefectures限定のままだと、このQA導線だけ大阪等へ遷移できない
        // 状態が残ってしまう。
        guard let prefecture = mockQuestPrefectures.first(where: { $0.id == prefectureId })
            ?? questPrefectureShapes.first(where: { $0.id == prefectureId }).map({ shape in
                QuestPrefecture(
                    id: shape.id,
                    name: shape.name,
                    englishName: shape.id,
                    totalSpotCount: mockQuestSpots.filter { $0.prefectureId == shape.id }.count
                )
            }) else {
            return
        }
        viewMode = .collect
        navigationPath = [prefecture]
        #endif
    }

    // MARK: - Collect (PICTRI_FINAL_DESIGN_SPEC.md「F. MEMORIES INDEX」)
    //
    // 「ここまで日本を色づけてきた」履歴画面。to-doリストのMapとは対を成す。
    // 47県を同一roundedカードで並べるだけのdashboardにはせず、
    // 日本 → 県 → 場所 → 写真、の階層をこの一覧自体で感じられるようにする。
    // 統計カード・パーセンテージ・チャート・streakは使わず、件数は常にinline textのみ。

    /// 単一Source of Truth原則の修正(Visual Foundation Part B)。以前は
    /// mockQuestPrefectures(spotデータが最初から用意されていた4県だけの静的配列)を
    /// 基準にしていたため、Anywhere Capture/Curated Spot拡張で新たにvisitedになった
    /// 県(大阪等)がCollectの行から欠落する実害があった(Map/VlogはvisitedPrefectureIds
    /// を直接見るため正しく反映されており、Collectだけが取り残されていた)。
    /// questPrefectureShapes(47都道府県の実データ、Mapと同じSource)を基準にし、
    /// mockQuestPrefecturesにエントリがあればその実データ(englishName/totalSpotCount)を
    /// 使い、無ければshapeの情報から最小限のQuestPrefectureを組み立てる
    /// (「history, not a to-do list」の方針・行の見た目・並びロジックは無変更)。
    private var visitedPrefectures: [QuestPrefecture] {
        let visitedIds = memoryStore.visitedPrefectureIds
        return questPrefectureShapes
            .filter { visitedIds.contains($0.id) }
            .map { shape in
                mockQuestPrefectures.first { $0.id == shape.id }
                    ?? QuestPrefecture(
                        id: shape.id,
                        name: shape.name,
                        englishName: shape.id,
                        totalSpotCount: mockQuestSpots.filter { $0.prefectureId == shape.id }.count
                    )
            }
    }

    /// dormant側は日本全体(questPrefectureShapes、47都道府県の実データ)を基準にする。
    /// mockQuestPrefectures(スポットが用意されている4県のみ)を基準にすると
    /// 「あと40」のような文言が成立しないため。
    private var dormantPrefectureNames: [String] {
        questPrefectureShapes
            .filter { !memoryStore.visitedPrefectureIds.contains($0.id) }
            .map(\.name)
    }

    private var totalMemoryCount: Int {
        memoryStore.memoryPhotos.count
    }

    private var collectBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 30) {
                memoriesHeader

                if totalMemoryCount == 0 {
                    collectEmptyState
                } else {
                    // Visual Direction Consolidation: 日本地図(indexMapSection)は
                    // Mapタブと役割が重複していたため削除した。「場所を見る」はMap、
                    // 「時間・写真を振り返る」はMemoriesという役割分離に合わせ、ここは
                    // 「今どこまで集まっているか」の要約テキストだけに留める
                    // (memoriesHeaderの「N県・N枚 集めた」がその役割を担う)。
                    prefectureRows
                    dormantClosingBlock
                }

                Spacer(minLength: JQUI.bottomBarReserve)
            }
            .padding(.horizontal, JQUI.sidePadding)
            .padding(.top, JQUI.screenTopPadding)
        }
    }

    private var collectEmptyState: some View {
        PictriEmptyState(
            systemImage: "map",
            title: "まだ写真がありません",
            message: "Mapでスポットを訪れて\n最初の記録を残しましょう",
            isLight: true
        )
        .padding(.horizontal, 8)
        .padding(.top, 40)
    }

    private var prefectureRows: some View {
        VStack(spacing: 0) {
            PictriHairline()
            ForEach(visitedPrefectures) { prefecture in
                NavigationLink(value: prefecture) {
                    PrefectureMemoryRow(prefecture: prefecture)
                }
                .buttonStyle(.plain)

                PictriHairline()
            }
        }
    }

    /// Design Spec「Closing dormant block: dashed border, 「まだ白地図の県、あと40」,
    /// dormant prefecture chips, 「つぎはどこへ？ 〜」」。
    private var dormantClosingBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("まだ白地図の県、あと\(dormantPrefectureNames.count)")
                .font(PictriTypography.body(13, weight: .bold))
                .foregroundStyle(PictriFinalTheme.inkSoft)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dormantPrefectureNames, id: \.self) { name in
                        Text(name)
                            .font(PictriTypography.body(12, weight: .medium))
                            .foregroundStyle(PictriFinalTheme.inkFaint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay {
                                Capsule()
                                    .strokeBorder(PictriFinalTheme.dormantDot, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            }
                    }
                }
            }

            Text("つぎはどこへ？")
                .font(PictriTypography.body(13, weight: .semibold))
                .foregroundStyle(PictriFinalTheme.inkSoft)
        }
        .padding(16)
        .overlay {
            RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous)
                .strokeBorder(PictriFinalTheme.dormantDot, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Vlog
    //
    // Product Concept「その日に現地で撮った写真が、その日の旅の短い映像になる」。
    // camera roll全体から選ぶgeneric AI video editorにはしない――Vlog対象は常に
    // 「Pictriで現地撮影して、その日に保存されたMemory」だけ(QuestVlogGenerating.swift)。
    // 「今日」を必ず先頭に置き、過去日付をその下に続ける(検索・film library的な
    // grid UIにはしない)。

    private var vlogBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                memoriesHeader

                if memoryStore.memoryPhotos.isEmpty {
                    vlogEmptyState
                } else {
                    todaySection

                    if !pastVlogDays.isEmpty {
                        pastVlogSection
                    }
                }

                Spacer(minLength: JQUI.bottomBarReserve)
            }
            .padding(.horizontal, JQUI.sidePadding)
            .padding(.top, JQUI.screenTopPadding)
        }
        .alert("AI Vlogは近日公開", isPresented: $showAIComingSoonAlert) {
            Button("今日のVlogを見る") {
                if let todayVlogDay {
                    playDay(todayVlogDay)
                }
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("公開まではいつものVlogをお楽しみください")
        }
    }

    /// Core Invariant 10「Free Vlog対象はその日のPictri Memory最大3件」の防衛的な適用点。
    /// 通常はFREEユーザーの1日の保存数自体がQuestDailyCaptureAllowanceで3件までに
    /// 制限されているため、実運用でこのcapに達することは無いはずだが、将来のtier変更
    /// (downgrade)等のedge caseでも必ずここでcapされるようにする
    /// (LocalDeterministicVlogGenerator自体はtierを知らない、呼び出し側の責務)。
    private func playDay(_ day: VlogDay) {
        if entitlementStore.tier == .free, day.photos.count > 3 {
            let capped = VlogDay(dateKey: day.dateKey, date: day.date, photos: Array(day.photos.prefix(3)))
            playingScript = LocalDeterministicVlogGenerator().makeScript(for: capped)
        } else {
            playingScript = LocalDeterministicVlogGenerator().makeScript(for: day)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日")
                .font(PictriTypography.mono(11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PictriFinalTheme.inkFaint)

            if let todayVlogDay {
                todayVlogCard(day: todayVlogDay)

                if entitlementStore.tier == .premium {
                    premiumGenerateButton(day: todayVlogDay)
                } else {
                    freeUpsellLink
                }
            } else {
                todayEmptyCard
            }
        }
    }

    /// Design方針「1枚でも簡易Vlogは成立してよい」。枚数に応じて文言だけ変え、
    /// 1枚の時から常にタップで再生できる状態にする(「3枚撮らないと使えない」と
    /// 感じさせない)。
    private func todayVlogCard(day: VlogDay) -> some View {
        Button {
            playDay(day)
        } label: {
            HStack(spacing: 16) {
                photoStack(photos: day.photos)

                VStack(alignment: .leading, spacing: 4) {
                    Text("今日のVlog")
                        .font(PictriTypography.display(16))
                        .foregroundStyle(PictriFinalTheme.ink)

                    Text(todayCaptionText(count: day.photos.count))
                        .font(PictriTypography.body(12, weight: .medium))
                        .foregroundStyle(PictriFinalTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.onAccent)
                    .frame(width: 40, height: 40)
                    .background(PictriFinalTheme.accent)
                    .clipShape(Circle())
            }
            .padding(14)
            .background(PictriFinalTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous)
                    .stroke(PictriFinalTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("今日のVlogを再生、\(day.photos.count)枚")
    }

    private func todayCaptionText(count: Int) -> String {
        switch count {
        case 1:
            return "あと2枚撮ると育つ・今すぐ見られます"
        case 2:
            return "あと1枚でもっと育つ・今すぐ見られます"
        default:
            return "\(count)枚のVlogが完成"
        }
    }

    /// 「巨大なlocation status card」等と同じ理由で、写真そのもの(PhotoPrint系)を
    /// 積み重ねるだけにし、統計・進捗バーは使わない。最大3枚だけ少しずつ角度・
    /// 位置をずらして「重なった記憶」に見せる。
    private func photoStack(photos: [QuestMemoryPhoto]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(photos.prefix(3).enumerated()), id: \.element.id) { index, photo in
                MiniMemoryPrint(photo: photo)
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(Double(index) * 7 - 7))
                    .offset(x: CGFloat(index) * 7, y: CGFloat(index) * -5)
            }
        }
        .frame(width: 74, height: 68, alignment: .topLeading)
    }

    private var todayEmptyCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "camera")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(PictriFinalTheme.inkFaint)
                .frame(width: 58, height: 58)
                .background(PictriFinalTheme.dormant)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("今日はまだ写真がありません")
                    .font(PictriTypography.body(13, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text("撮ると、その日のVlogが育ちはじめます")
                    .font(PictriTypography.body(11, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PictriFinalTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous)
                .strokeBorder(PictriFinalTheme.dormantDot, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    /// Product Requirement(今回追加)「課金導線は2箇所」の2つ目
    /// 「Premium AI Vlogを生成しようとしたとき」。PREMIUM tierだけに表示する。
    /// PremiumAIVlogGenerator未実装のため、実際に生成が成功したふりはせず、
    /// alert経由で正直に「近日公開」と伝えた上でlocal generatorへ戻す。
    private func premiumGenerateButton(day: VlogDay) -> some View {
        Button {
            if let script = PremiumAIVlogGenerator().makeScript(for: day) {
                playingScript = script
            } else {
                showAIComingSoonAlert = true
            }
        } label: {
            Text("AIでVlogをつくる")
                .font(PictriTypography.body(13, weight: .bold))
                .foregroundStyle(PictriFinalTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay {
                    RoundedRectangle(cornerRadius: PictriFinalTheme.radiusControl, style: .continuous)
                        .stroke(PictriFinalTheme.ink, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    /// Product Requirement「課金導線は2箇所」の2つ目をFREE側からも辿れるようにする、
    /// 控えめなテキストリンク(「典型的AI UI」にならないよう、装飾は一切付けない)。
    private var freeUpsellLink: some View {
        Button {
            showVlogPaywall = true
        } label: {
            Text("AIでもっと作り込む(Premium)")
                .font(PictriTypography.body(11, weight: .medium))
                .foregroundStyle(PictriFinalTheme.inkFaint)
                .underline()
        }
        .buttonStyle(.plain)
        .padding(.leading, 2)
    }

    private var pastVlogSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("過去")
                .font(PictriTypography.mono(11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PictriFinalTheme.inkFaint)
                .padding(.bottom, 8)

            PictriHairline()
            ForEach(pastVlogDays) { day in
                Button {
                    playDay(day)
                } label: {
                    VlogDayRow(day: day)
                }
                .buttonStyle(.plain)

                PictriHairline()
            }
        }
    }

    // Home/AccountのPictriEmptyState(isLight: false)をそのまま使う。以前は独自実装
    // (背景カードなしで浮いたアイコン+テキスト)だったため、他の空状態と質感が違って見えていた。
    private var vlogEmptyState: some View {
        PictriEmptyState(
            systemImage: "film",
            title: "まだVlogがありません",
            message: "Mapでスポットを訪れて\n最初の記録を残しましょう",
            isLight: true
        )
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Header (shared between modes)

    // Visual Direction Consolidation: Collect⇄Vlogの切り替えは独立tab(AppTab.vlog)に
    // 委譲したため、画面内のmodeToggleは削除した(Memories = 「時間・写真を振り返る」
    // Archive、Vlog = 「一日の物語」という役割分離を、tab自体で明確に伝えるため)。
    private var memoriesHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewMode == .collect ? "おもいで" : "Vlog")
                .font(PictriTypography.display(22))
                .foregroundStyle(PictriFinalTheme.ink)

            Text("\(visitedPrefectures.count)県・\(totalMemoryCount)枚 集めた")
                .font(PictriTypography.body(11.5, weight: .medium))
                .foregroundStyle(PictriFinalTheme.inkSoft)
        }
    }
}

// MARK: - Vlog Day Row (Vlog history)

private struct VlogDayRow: View {
    let day: VlogDay

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: day.date)
    }

    /// PrefectureMemoryRowと同じ「場所(area)」単位の名前表示に揃える。
    private var placeNamesText: String {
        var seen = Set<String>()
        var ordered: [String] = []
        for photo in day.photos {
            let spot = mockQuestSpots.first(where: { $0.id == photo.spotId }) ?? QuestSpot.synthesized(for: photo)
            if seen.insert(spot.areaName).inserted {
                ordered.append(spot.areaName)
            }
        }
        return ordered.joined(separator: "・")
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dateText)
                    .font(PictriTypography.display(15))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text(placeNamesText)
                    .font(PictriTypography.body(11, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(day.photos.count)枚")
                .font(PictriTypography.mono(11, weight: .regular))
                .foregroundStyle(PictriFinalTheme.inkSoft)

            Image(systemName: "play.circle.fill")
                .font(.system(size: 19))
                .foregroundStyle(PictriFinalTheme.accent)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dateText)のVlog、\(day.photos.count)枚")
    }
}

// MARK: - Prefecture Memory Row (Memories Index)

/// Design Spec「Prefecture rows below, hairline-separated: prefecture shape 38 in its
/// color · name (display 15) · place names (11 faint, single line, ellipsis) ·
/// two 44px prints · caret」。
private struct PrefectureMemoryRow: View {
    let prefecture: QuestPrefecture
    @EnvironmentObject var memoryStore: QuestMemoryStore

    private var photos: [QuestMemoryPhoto] {
        memoryStore.memoryPhotos.filter { $0.prefectureId == prefecture.id }
    }

    /// スポット単位ではなく「場所(area)」単位の名前を並べる(Section G/Hの
    /// 「場所」の粒度に合わせる)。出現順を保ったまま重複だけ除く。
    private var placeNamesText: String {
        var seen = Set<String>()
        var ordered: [String] = []
        for photo in photos {
            let spot = mockQuestSpots.first(where: { $0.id == photo.spotId }) ?? QuestSpot.synthesized(for: photo)
            if seen.insert(spot.areaName).inserted {
                ordered.append(spot.areaName)
            }
        }
        return ordered.joined(separator: "・")
    }

    private var previewPhotos: [QuestMemoryPhoto] {
        Array(photos.prefix(2))
    }

    var body: some View {
        HStack(spacing: 14) {
            PictriPrefectureShapeIcon(prefectureId: prefecture.id, color: PictriFinalTheme.memoryColor(for: prefecture.id))
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(prefecture.name)
                    .font(PictriTypography.display(15))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text(placeNamesText)
                    .font(PictriTypography.body(11, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkFaint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(previewPhotos) { photo in
                    MiniMemoryPrint(photo: photo)
                        .frame(width: 44, height: 44)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PictriFinalTheme.inkFaint)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prefecture.name)、\(placeNamesText)")
    }
}

/// 44px/72pxのような極小サイズ専用の簡易プリント。PictriPhotoPrint(印刷物としての
/// paper mat・shadow)は5pt paddingだけでもこのサイズではmatが写真本体を圧迫するため、
/// ここでは「印刷物」の意匠を角丸+ink hairline 1本に簡略化する。
///
/// GeometryReaderで実測したサイズをImageへ直接frameで渡す。呼び出し側の
/// `.frame(width:height:)`だけに委ねる(=`Image().resizable().scaledToFill()`が
/// 外側からのframeだけでサイズを決める)実装だと、このViewが兄弟Viewより前に
/// 並ぶVStack内でVStackの理想サイズ計算が壊れ、前にある兄弟Viewの幅が0になって
/// 消えることがある(CameraView.reviewViewで確認済みの同種のSwiftUIレイアウト
/// バグ、詳細はCameraView.swiftの該当コメントを参照)。GeometryReader経由で
/// 「確定済みの具体的なサイズ」だけをImageに渡すことでこれを回避する。
private struct MiniMemoryPrint: View {
    let photo: QuestMemoryPhoto
    @EnvironmentObject var memoryStore: QuestMemoryStore

    var body: some View {
        GeometryReader { proxy in
            Group {
                // Anywhere Capture Phase: spotId経由(curated Spot前提)ではなく、
                // QuestMemoryPhoto自身から直接読む(memoryStore.image(for: photo:))。
                // curated Spotに属さないMemoryでも常に正しく画像を表示できる。
                if let image = memoryStore.image(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    PictriFinalTheme.dormant
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(PictriFinalTheme.line, lineWidth: 1)
            }
        }
    }
}

/// 都道府県shapeを、渡された正方形枠へ自動フィットさせて描く。Map/Homeの
/// 「さいきん色づいた場所」と同じQuestPrefectureGeometry.points(for:) +
/// PictriCollectionPrefecturePathを再利用し、Memories専用の簡略化shapeは作らない。
struct PictriPrefectureShapeIcon: View {
    let prefectureId: String
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            if let shape = questPrefectureShapes.first(where: { $0.id == prefectureId }) {
                let points = QuestPrefectureGeometry.points(for: shape)
                let xs = points.map(\.x)
                let ys = points.map(\.y)
                let minX = xs.min() ?? 0
                let minY = ys.min() ?? 0
                let width = max((xs.max() ?? 1) - minX, 1)
                let height = max((ys.max() ?? 1) - minY, 1)
                let pad: CGFloat = 2
                let scale = min((proxy.size.width - pad * 2) / width, (proxy.size.height - pad * 2) / height)
                let offsetX = (proxy.size.width - width * scale) / 2 - minX * scale
                let offsetY = (proxy.size.height - height * scale) / 2 - minY * scale

                PictriCollectionPrefecturePath(points: points, scale: scale, offsetX: offsetX, offsetY: offsetY)
                    .fill(color)
            }
        }
    }
}

// MARK: - Prefecture Memories (Design Spec「G. PREFECTURE MEMORIES」)

/// 「場所」単位でのグルーピング。1スポット=1写真が基本のデータモデルの上に、
/// Design SpecのPlace section(「場所」)の粒度(QuestSpot.areaName)をかぶせるだけの
/// 表示用の集約で、新しい永続データは持たない。
fileprivate struct MemoryPlace: Identifiable, Hashable {
    let areaName: String
    let prefectureId: String
    let photos: [(spot: QuestSpot, photo: QuestMemoryPhoto)]

    var id: String { "\(prefectureId)_\(areaName)" }

    var mostRecentDateText: String {
        photos.first?.photo.createdAtText ?? ""
    }

    /// photosがtuple配列(=非Hashable)のため、同一性はidだけで判定する
    /// (このView用途では十分。永続比較やequality semanticsには使わない)。
    static func == (lhs: MemoryPlace, rhs: MemoryPlace) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PrefectureMemoryDetailView: View {
    let prefecture: QuestPrefecture
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @Environment(\.dismiss) private var dismiss
    @State private var debugPushedPlace: MemoryPlace?

    private var photos: [QuestMemoryPhoto] {
        memoryStore.memoryPhotos.filter { $0.prefectureId == prefecture.id }
    }

    private var completedCount: Int {
        #if DEBUG
        if let override = PictriVisualReview.prefectureCountOverride(for: prefecture.id) {
            return override
        }
        #endif
        return photos.count
    }

    /// Design Spec「place sections」。areaNameでグルーピングし、そのarea内の写真を
    /// 新しい順に並べる。areaの並び順自体は、直近に撮った写真を含むareaが上に来るよう
    /// 「そのarea内で一番新しい写真の日時」でソートする。
    private var places: [MemoryPlace] {
        var byArea: [String: [(spot: QuestSpot, photo: QuestMemoryPhoto)]] = [:]
        var order: [String] = []

        for photo in photos {
            let spot = mockQuestSpots.first(where: { $0.id == photo.spotId }) ?? QuestSpot.synthesized(for: photo)
            if byArea[spot.areaName] == nil {
                byArea[spot.areaName] = []
                order.append(spot.areaName)
            }
            byArea[spot.areaName]?.append((spot, photo))
        }

        return order.map { areaName in
            MemoryPlace(areaName: areaName, prefectureId: prefecture.id, photos: byArea[areaName] ?? [])
        }
    }

    /// Design Spec「back + mono span (2026.05 — 08)」。撮影日の最古〜最新をYYYY.MM表記で。
    private var monoSpanText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let dates = photos.compactMap { formatter.date(from: $0.createdAtText) }
        guard let earliest = dates.min(), let latest = dates.max() else { return "" }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy.MM"
        let earliestText = monthFormatter.string(from: earliest)
        let latestText = monthFormatter.string(from: latest)
        return earliestText == latestText ? earliestText : "\(earliestText) — \(String(latestText.suffix(2)))"
    }

    private var remainingSpotCount: Int {
        max(prefecture.totalSpotCount - completedCount, 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            PictriFinalTheme.paper.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    detailHeader
                    prefectureSummary

                    VStack(spacing: 0) {
                        PictriHairline()
                        ForEach(places) { place in
                            NavigationLink {
                                PlaceMemoryDetailView(prefecture: prefecture, place: place)
                            } label: {
                                PlaceMemorySection(place: place)
                            }
                            .buttonStyle(.plain)

                            PictriHairline()
                        }
                    }

                    if remainingSpotCount > 0 {
                        Text("\(prefecture.name)で、まだ行っていない場所もある")
                            .font(PictriTypography.body(12, weight: .medium))
                            .foregroundStyle(PictriFinalTheme.inkFaint)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, JQUI.sidePadding)
                .padding(.top, JQUI.screenTopPadding)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $debugPushedPlace) { place in
            PlaceMemoryDetailView(prefecture: prefecture, place: place)
        }
        .onAppear {
            openDebugPlaceDetailIfRequested()
        }
    }

    /// `-pictriMemoriesPlaceDetail <areaName>` でPlace Memoriesを直接スクショ確認できる
    /// ようにする。DEBUG限定。既存のplace行タップ(NavigationLink)とは別経路
    /// (debugPushedPlace)を使うため、通常のタップ導線には一切影響しない。
    private func openDebugPlaceDetailIfRequested() {
        #if DEBUG
        guard debugPushedPlace == nil,
              let areaName = PictriVisualReview.memoriesDetailAreaName,
              let match = places.first(where: { $0.areaName == areaName }) else {
            return
        }
        debugPushedPlace = match
        #endif
    }

    private var detailHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.ink)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("戻る")

            Spacer()

            Text(monoSpanText)
                .font(PictriTypography.mono(11, weight: .regular))
                .foregroundStyle(PictriFinalTheme.inkFaint)
        }
    }

    private var prefectureSummary: some View {
        HStack(spacing: 16) {
            PictriPrefectureShapeIcon(prefectureId: prefecture.id, color: PictriFinalTheme.memoryColor(for: prefecture.id))
                .frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 4) {
                Text(prefecture.name)
                    .font(PictriTypography.display(24))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text("\(places.count)か所・\(completedCount)枚 集めた")
                    .font(PictriTypography.body(13, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)
            }

            Spacer(minLength: 0)
        }
    }
}

/// Design Spec「place name (13/900) + 「5枚」+ mono date; a row of up to four 72px
/// prints (first rotated −1.4°) with 「+n」 overflow」。
private struct PlaceMemorySection: View {
    let place: MemoryPlace
    @EnvironmentObject var memoryStore: QuestMemoryStore

    private var displayDate: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy/MM/dd HH:mm"
        let output = DateFormatter()
        output.dateFormat = "yyyy.MM.dd"
        return input.date(from: place.mostRecentDateText).map { output.string(from: $0) } ?? ""
    }

    private var previewPhotos: [(spot: QuestSpot, photo: QuestMemoryPhoto)] {
        Array(place.photos.prefix(4))
    }

    private var overflowCount: Int {
        max(place.photos.count - 4, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(place.areaName)
                    .font(PictriTypography.body(13, weight: .black))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text("\(place.photos.count)枚")
                    .font(PictriTypography.body(12, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)

                Spacer()

                Text(displayDate)
                    .font(PictriTypography.mono(10, weight: .regular))
                    .foregroundStyle(PictriFinalTheme.inkFaint)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PictriFinalTheme.inkFaint)
            }

            HStack(spacing: 8) {
                ForEach(Array(previewPhotos.enumerated()), id: \.element.photo.id) { index, item in
                    MiniMemoryPrint(photo: item.photo)
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(index == 0 ? -1.4 : 0))
                        .overlay(alignment: .bottomTrailing) {
                            if index == previewPhotos.count - 1 && overflowCount > 0 {
                                Text("+\(overflowCount)")
                                    .font(PictriTypography.mono(11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.black.opacity(0.45))
                                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                    .padding(4)
                            }
                        }
                }
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(place.areaName)、\(place.photos.count)枚")
    }
}

// MARK: - Place Memories (Design Spec「H. PLACE MEMORIES」)

struct PlaceMemoryDetailView: View {
    let prefecture: QuestPrefecture
    fileprivate let place: MemoryPlace
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var entitlementStore: QuestEntitlementStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playingScript: PictriVlogScript?

    private var heroItem: (spot: QuestSpot, photo: QuestMemoryPhoto)? {
        place.photos.first
    }

    private var remainingItems: [(spot: QuestSpot, photo: QuestMemoryPhoto)] {
        Array(place.photos.dropFirst())
    }

    /// Memory Flip Phase A「表 = その場所 / 裏 = そのときの自分」を実データでも成立させる。
    /// Phase初回実装時の監査で、保存されているimageNameは外カメラ写真ではなく
    /// 「外カメラ+内カメラinsetをQuestDualPhotoComposer.composeで焼き込み済みのcomposite
    /// 1枚」だと判明した(insetの下の外カメラ画素は上書きされ復元不可能=分類C)。
    /// そのため表に内カメラの人物insetが写り込んだままで「場所だけ」が成立していなかった。
    /// 今回、CameraView保存時にcompose前の生backImage/frontImageも
    /// QuestMemoryPhoto.outerOnlyImageName/selfieImageNameとして追加保存するようにした
    /// (既存imageName/compositeは無変更、大規模migrationはしない)。
    /// 新規Memoryはouter-only/selfieを優先、旧Memory(nilの場合)は今まで通りcomposite
    /// およびそこからのcropへgraceful fallbackする。
    private func frontImage(for item: (spot: QuestSpot, photo: QuestMemoryPhoto)) -> UIImage? {
        memoryStore.outerOnlyImage(for: item.spot) ?? memoryStore.image(for: item.spot)
    }

    private func backImage(for item: (spot: QuestSpot, photo: QuestMemoryPhoto)) -> UIImage? {
        if let selfie = memoryStore.selfieImage(for: item.spot) {
            return selfie
        }
        guard let composite = memoryStore.image(for: item.spot) else { return nil }
        return QuestDualPhotoComposer.cropInnerCamera(from: composite)
    }

    private func shortDateText(_ createdAtText: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy/MM/dd HH:mm"
        let output = DateFormatter()
        output.dateFormat = "MM.dd EEE"
        output.locale = Locale(identifier: "en_US_POSIX")
        return input.date(from: createdAtText).map { output.string(from: $0) } ?? ""
    }

    /// 裏面の「その日のVlogへ」導線が指す先。place.photos(この場所だけ)ではなく、
    /// 既存のQuestVlogDayGrouping経由でmemoryStore.memoryPhotos全体からその日を
    /// 引き直す(Vlogは県・場所をまたいだ「その日全部」が対象のため)。
    private func vlogDay(for item: (spot: QuestSpot, photo: QuestMemoryPhoto)) -> VlogDay? {
        let input = DateFormatter()
        input.dateFormat = "yyyy/MM/dd HH:mm"
        guard let date = input.date(from: item.photo.createdAtText) else { return nil }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let key = dayFormatter.string(from: date)
        return QuestVlogDayGrouping.groupedByDay(memoryStore.memoryPhotos).first { $0.dateKey == key }
    }

    private func playVlogDay(_ day: VlogDay) {
        let capped: VlogDay
        if entitlementStore.tier == .free, day.photos.count > 3 {
            capped = VlogDay(dateKey: day.dateKey, date: day.date, photos: Array(day.photos.prefix(3)))
        } else {
            capped = day
        }
        playingScript = LocalDeterministicVlogGenerator().makeScript(for: capped)
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    /// `-pictriMemoryFlipShowBack true` QAスクショ専用(DEBUG限定)。Releaseでは
    /// PictriVisualReview自体が存在しないため、参照はここだけに閉じる。
    private var debugStartsFlipped: Bool {
        #if DEBUG
        return PictriVisualReview.memoryFlipShowBackInitially
        #else
        return false
        #endif
    }

    /// heroの写真が初期viewport内でfooterまで見えるよう、写真の高さ上限を
    /// containerの実測高さから逆算する。UIScreen.main等の固定値を持たず、
    /// GeometryReaderが返す「今まさに使える高さ」だけを根拠にする(iPhone 17 Pro/SE
    /// どちらでも同じ計算式で成立させるため、device-size分岐を書かない)。
    /// 差し引く内訳: header(戻る行+県名+場所名、top padding込み)・VStack spacing 2本・
    /// footer band・grid行の存在をほのめかす一部・タブバー分の呼吸。実測に基づき
    /// 調整した単一の定数(reservedChrome)として持つ。
    private func heroMaxPhotoHeight(containerHeight: CGFloat) -> CGFloat {
        let reservedChrome: CGFloat = JQUI.screenTopPadding + 96 + 18 + 60 + 92
        return max(200, containerHeight - reservedChrome)
    }

    var body: some View {
        GeometryReader { containerGeo in
            ZStack(alignment: .top) {
                PictriFinalTheme.paper.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        detailHeader

                        if let heroItem {
                            PictriMemoryFlipCard(
                                frontImage: frontImage(for: heroItem),
                                backImage: backImage(for: heroItem),
                                photoAspectRatio: 4.0 / 5.0,
                                cornerRadius: PictriFinalTheme.radiusPhotoPrint,
                                footer: PictriMemoryFlipCard.Footer(
                                    placeName: heroItem.spot.name,
                                    dateText: shortDateText(heroItem.photo.createdAtText),
                                    vlogAction: vlogDay(for: heroItem).map { day in { playVlogDay(day) } }
                                ),
                                printMargin: 6,
                                rotationDegrees: -0.6,
                                maxPhotoHeight: heroMaxPhotoHeight(containerHeight: containerGeo.size.height),
                                startsFlippedForDebug: debugStartsFlipped
                            )
                            .frame(maxWidth: .infinity)
                        }

                        if !remainingItems.isEmpty {
                            LazyVGrid(columns: gridColumns, spacing: 8) {
                                ForEach(remainingItems, id: \.photo.id) { item in
                                    PictriMemoryFlipCard(
                                        frontImage: frontImage(for: item),
                                        backImage: backImage(for: item),
                                        photoAspectRatio: 1,
                                        cornerRadius: PictriFinalTheme.radiusPhotoPrint,
                                        footer: nil,
                                        printMargin: 3,
                                        startsFlippedForDebug: debugStartsFlipped
                                    )
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, JQUI.sidePadding)
                    .padding(.top, JQUI.screenTopPadding)
                }
            }
        }
        .fullScreenCover(item: $playingScript) { script in
            PictriVlogPlayerView(script: script)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.ink)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("戻る")

                Spacer()

                Text("\(place.photos.count)枚")
                    .font(PictriTypography.body(12, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)
            }

            Text(prefecture.name)
                .font(PictriTypography.body(10.5, weight: .medium))
                .foregroundStyle(PictriFinalTheme.inkFaint)
                .padding(.leading, 2)

            Text(place.areaName)
                .font(PictriTypography.display(17))
                .foregroundStyle(PictriFinalTheme.ink)
                .padding(.leading, 2)
        }
    }

}

/// スポットごとの写真プレースホルダー配色(実写真がまだ無い場合のフォールバック専用、
/// HomeView/MapViewからも参照される共有enum)。以前はシステム標準色(.blue/.green/.red等)
/// をそのまま使っており、PictriThemeのindigo/teal/warmと無関係な「サンプルアプリ」的な
/// 見た目になっていたため、全パターンをブランドカラーの組み合わせへ差し替えた。
enum MemoryVisualStyle {
    /// 以前はaccent(sky blue)が9パターン中4回登場し、写真プレースホルダー全体が
    /// 青っぽく見えていた。写真・思い出の基調色であるlavenderに置き換えることで、
    /// 「青いアプリ」感を減らしつつ、意味的にも「記憶の余韻」の色として自然にした。
    static func gradient(for spot: QuestSpot) -> LinearGradient {
        switch spot.gridIndex % 9 {
        case 0:
            return LinearGradient(colors: [PictriLightTheme.lavender.opacity(0.60), .black], startPoint: .top, endPoint: .bottom)
        case 1:
            return LinearGradient(colors: [PictriTheme.teal.opacity(0.58), .black], startPoint: .top, endPoint: .bottom)
        case 2:
            return LinearGradient(colors: [PictriTheme.warm.opacity(0.58), .black], startPoint: .top, endPoint: .bottom)
        case 3:
            // 旧: 単体の紫リテラル → 「紫を主役から外す」方針により、lavender(=copper)
            // と同じ色相のwarm copper darkへ置き換えた。
            return LinearGradient(
                colors: [PictriLightTheme.lavender.opacity(0.55), Color(red: 0.30, green: 0.20, blue: 0.13), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 4:
            return LinearGradient(
                colors: [PictriTheme.teal.opacity(0.46), Color(red: 0.09, green: 0.26, blue: 0.24), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        case 5:
            return LinearGradient(
                colors: [PictriTheme.warm.opacity(0.5), Color(red: 0.40, green: 0.17, blue: 0.19), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        case 6:
            return LinearGradient(
                colors: [PictriLightTheme.lavender.opacity(0.46), PictriTheme.teal.opacity(0.32), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 7:
            return LinearGradient(
                colors: [PictriTheme.warm.opacity(0.46), PictriLightTheme.lavender.opacity(0.28), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color(red: 0.28, green: 0.32, blue: 0.44), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
