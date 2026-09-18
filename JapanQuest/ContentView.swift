import SwiftUI
import CoreLocation
import Combine
import MapKit

#if DEBUG
/// DEBUGビルド限定・目視QA専用の起動引数を1箇所にまとめたもの。
/// 各画面(Map / Camera / Memories)はここだけを見ればよく、
/// `ProcessInfo.processInfo.arguments` を各ファイルで個別にパースしない。
/// Releaseビルドではこの型ごと存在しないため、本番機能として誤って残る心配がない。
enum PictriVisualReview {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    private static func value(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    static var startTab: AppTab? {
        switch value(for: "-pictriStartTab") {
        case "home": return .home
        case "map": return .map
        case "camera": return .camera
        case "vlog": return .vlog
        case "memories": return .memories
        default: return nil
        }
    }

    /// `-pictriDevUnlock true|false` で developerUnlockMode を明示的に上書きする。
    /// 引数なし(nil)の場合は既存値をそのまま維持する。
    static var devUnlockOverride: Bool? {
        switch value(for: "-pictriDevUnlock")?.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    static var memoriesMode: MemoriesViewMode? {
        switch value(for: "-pictriMemoriesMode") {
        case "vlog": return .vlog
        case "collect": return .collect
        default: return nil
        }
    }

    /// `-pictriEntitlement free|premium` でQuestEntitlementStoreの初期tierを
    /// 直接指定する。DEBUG限定。既存課金基盤が無いため、実StoreKit導入までの
    /// 暫定QA手段(詳細はQuestDailyCaptureAllowance.swiftを参照)。
    static var entitlementTierOverride: QuestEntitlementTier? {
        switch value(for: "-pictriEntitlement") {
        case "premium": return .premium
        case "free": return .free
        default: return nil
        }
    }

    /// `-pictriDailyCaptureUsed <n>` でFREEユーザーの「今日の使用済み回数」を
    /// タップなしで直接再現する(0=未使用、3=使い切り等)。DEBUG限定。
    /// UserDefaultsへは一切書き込まない(表示専用の上書き)。
    static var dailyCaptureUsedOverride: Int? {
        value(for: "-pictriDailyCaptureUsed").flatMap(Int.init)
    }

    /// `-pictriDailyCaptureDay <yyyy-MM-dd>` で、QuestDailyCaptureAllowanceが
    /// 「今日」とみなす日付をDEBUG限定で上書きする。実機の時計を変えずに日付境界
    /// (同日維持/翌日reset)をQAするための最小フック。
    static var dailyCaptureDayOverride: String? {
        value(for: "-pictriDailyCaptureDay")
    }

    /// `-pictriDailyCaptureRecordNow true` で、起動時に一度だけ実際の
    /// QuestDailyCaptureAllowance.recordCaptureSaved()を呼ぶ(表示専用の
    /// `-pictriDailyCaptureUsed`と異なり、本物のUserDefaults永続化経路を通す)。
    /// アプリ再起動後もquotaが保持されるかを、Camera実タップ無しでQAするための
    /// 手段(`-pictriDailyCaptureDay`と組み合わせれば日付境界もQA可能)。
    static var dailyCaptureRecordNowRequested: Bool {
        value(for: "-pictriDailyCaptureRecordNow") == "true"
    }

    static var mapSpotId: String? {
        value(for: "-pictriMapSpot")
    }

    /// `-pictriMapPrefecture <prefectureId>` で都道府県詳細画面を直接スクショ確認できるようにする。DEBUG限定。
    static var mapPrefectureId: String? {
        value(for: "-pictriMapPrefecture")
    }

    /// `-pictriMapArea <prefectureId>` でエリア探索画面を直接スクショ確認できるようにする。DEBUG限定。
    static var mapAreaPrefectureId: String? {
        value(for: "-pictriMapArea")
    }

    /// `-pictriMapDebugScale 1.5` で日本全体Map(PictriJapanCollectionMap)のpinch
    /// zoom状態を、実際にピンチ操作をせず直接再現する。DEBUG限定。GUI自動化(pinch
    /// gestureのシミュレート)が環境によって不安定なため、1.0x/1.5x/2.5x等の
    /// スクリーンショットを確実に取得するために追加した。Production初期状態は
    /// 常に1.0x(baseScale=1.0)のままで、このフラグは影響しない。
    static var mapDebugScale: CGFloat? {
        guard let raw = value(for: "-pictriMapDebugScale"), let parsed = Double(raw) else {
            return nil
        }
        return CGFloat(parsed)
    }

    /// `-pictriMapDebugFocus <prefectureId>` を`-pictriMapDebugScale`と組み合わせ、
    /// 指定した都道府県の重心がviewport中央付近へ来るようpanのoffsetも一緒に
    /// 再現する。DEBUG限定。省略時はcenter(0,0オフセット)のままscaleだけ適用する。
    static var mapDebugFocusPrefectureId: String? {
        value(for: "-pictriMapDebugFocus")
    }

    /// `-pictriWorldMapDebugRegion japan|korea|asia|world|tokyo` Map Round 2専用。
    /// 実際のpinch/pan gestureをSimulator上で連続再現するのは不安定なため、
    /// QA screenshot用にcamera regionを直接指定できるようにする。DEBUG限定。
    /// 省略時はProduction初期経路(`PictriWorldMapCamera.initial()`、現在地優先/
    /// 日本全体fallback)のまま、このフラグは一切影響しない。
    static var worldMapDebugRegionKey: String? {
        value(for: "-pictriWorldMapDebugRegion")
    }

    /// `-pictriWorldMapDebugSearchQuery <text>` Map Round 3専用。Simulatorでは
    /// 実際のtext入力(candidate補完を伴う)を自動化しにくいため、QA screenshot用に
    /// 検索queryとfocus状態を起動時に直接与える。DEBUG限定。省略時はProduction
    /// 初期状態(空queryのcompact capsule)のまま。
    static var worldMapDebugSearchQuery: String? {
        value(for: "-pictriWorldMapDebugSearchQuery")
    }

    /// `-pictriWorldMapDebugSelectSpot <spotId>` Map Round 3専用。実際にmarkerを
    /// tapせずにSpot選択状態(selected marker + compact Spot Card)を再現する。
    /// DEBUG限定。
    static var worldMapDebugSelectSpotId: String? {
        value(for: "-pictriWorldMapDebugSelectSpot")
    }

    /// `-pictriWorldMapDebugOpenDetail true` Map Round 4専用。
    /// `-pictriWorldMapDebugSelectSpot`と併用し、実際にPreview Cardをtapせずに
    /// Spot Detail sheetを直接開いた状態を再現する。DEBUG限定。
    static var worldMapDebugOpenDetail: Bool {
        value(for: "-pictriWorldMapDebugOpenDetail") == "true"
    }

    /// `-pictriMapAreaLevel prefecture|area|spots` でエリア探索Mapのズーム段階を
    /// 直接指定してスクショ確認できるようにする。DEBUG限定。
    /// 自動ピンチズームが難しいため、実際のズーム操作を経由せずに
    /// QuestMapKitViewの初期表示段階を直接差し替える。
    static var mapAreaLevel: QuestMapZoomLevel? {
        switch value(for: "-pictriMapAreaLevel") {
        case "prefecture": return .prefecture
        case "area": return .majorSpots
        case "spots": return .allSpots
        default: return nil
        }
    }

    /// `-pictriMapCategory nature|photogenic|landmark|cafe` でエリア探索Mapの
    /// カテゴリフィルタを直接適用してスクショ確認できるようにする。DEBUG限定。
    /// 自動タップが難しいため、フィルタチップを押した状態を起動時に再現する。
    static var mapCategory: QuestSpotCategory? {
        switch value(for: "-pictriMapCategory") {
        case "nature": return .nature
        case "photogenic": return .photogenic
        case "landmark": return .landmark
        case "cafe": return .cafe
        default: return nil
        }
    }

    /// `-pictriMapSelectedSpot <spotId>` でエリア探索Mapの選択中スポット表現(ピン強調・
    /// 下部カード強調)をタップなしで直接スクショ確認できるようにする。DEBUG限定。
    /// 指定spotIdが現在の県・フィルタ結果に含まれない場合は呼び出し側で無視される
    /// (このプロパティ自体は文字列をそのまま返すだけで、整合性チェックはしない)。
    static var mapSelectedSpotId: String? {
        value(for: "-pictriMapSelectedSpot")
    }

    /// `-pictriSeedVisitedSpot <spotId>` / `-pictriSeedVisitedSpots <id1,id2,id3>` で、
    /// 実際のCamera撮影を経ずに「保存済み」状態を再現し、Map/Home/Memoriesへの反映を
    /// 検証できるようにする。DEBUG限定。QuestMemoryStore側でverificationStatus=developer
    /// (DEV MODE表示)として扱われ、実撮影の記録と見分けがつくようにする。
    static var seedVisitedSpotIds: [String] {
        var ids: [String] = []
        if let single = value(for: "-pictriSeedVisitedSpot") {
            ids.append(single)
        }
        if let multi = value(for: "-pictriSeedVisitedSpots") {
            ids.append(contentsOf: multi.split(separator: ",").map { String($0) })
        }
        return ids
    }

    /// `-pictriSeedRealPhotos true` を`-pictriSeedVisitedSpot(s)`と併用すると、
    /// imageNameをnilにせず実際にQuestDemoPhotoMaker+QuestDualPhotoComposerで
    /// 生成した画像をDocumentsへ書き出し、outerOnlyImageName/selfieImageNameも
    /// 含めて本物のMemoryとして表示できるようにする(Physical Print/Memory Flip
    /// のQA用、Production dataには一切影響しない)。DEBUG限定。
    static var seedRealPhotos: Bool {
        value(for: "-pictriSeedRealPhotos") == "true"
    }

    /// `-pictriMemoryMode persisted|clean` でQuestMemoryStore起動時にUserDefaultsを
    /// 読むかどうかを制御する。DEBUG限定。未指定時は既存通りpersisted(UserDefaultsを読む)。
    /// cleanはUserDefaultsの中身を削除・変更しない。「読み込みと書き込みを無視する」だけの
    /// 表示専用モードで、アプリ同梱のmock seed状態から毎回同じ条件でQAできるようにする。
    static var memoryModeIsClean: Bool {
        value(for: "-pictriMemoryMode") == "clean"
    }

    /// `-pictriCameraSpot <spotId>` でCameraタブのactiveCameraSpotIdを直接指定する。DEBUG限定。
    /// `-pictriCameraScenario saved` と組み合わせて、任意スポットの保存済みCamera状態を
    /// タップなしで確認できるようにする。既存の`-pictriMapSpot`はMapのナビゲーション用で
    /// Camera側には影響しないため、役割を分けて別引数にしている。
    static var cameraSpotId: String? {
        value(for: "-pictriCameraSpot")
    }

    /// CAMERA ROUND 2「STEP 17 NESTED SPOT INTERACTIVE QA」専用。
    /// `-pictriCameraSpot <id> -pictriCameraSpotExplicit true`と
    /// `xcrun simctl location <device> set <lat,lon>`を組み合わせることで、
    /// 実際にMapで「ここで撮る」をタップした状態(activeCameraSpotIsExplicit=true)を
    /// UI操作なしで再現し、Selected Spot Priorityの実効果をSimulatorで確認できる
    /// ようにする。DEBUG限定、本番の`activeCameraSpotIsExplicit`の既定値(false)や
    /// 通常のMap導線には一切影響しない。
    static var cameraSpotIsExplicit: Bool {
        value(for: "-pictriCameraSpotExplicit") == "true"
    }

    /// `-pictriVlogDay <yyyy-MM-dd>` でその日のVlog再生画面を直接開けるようにする。DEBUG限定。
    static var vlogDebugDayKey: String? {
        value(for: "-pictriVlogDay")
    }

    /// `-pictriMemoriesDetail <prefectureId>` でMemories IndexからPrefecture Memoriesへ
    /// タップなしで直接遷移した状態をスクショ確認できるようにする。DEBUG限定。
    static var memoriesDetailPrefectureId: String? {
        value(for: "-pictriMemoriesDetail")
    }

    /// `-pictriMemoriesDetail <prefectureId>`と組み合わせ、Prefecture MemoriesからPlace
    /// Memoriesへさらに直接遷移する。`-pictriMemoriesPlaceDetail <areaName>`。DEBUG限定。
    static var memoriesDetailAreaName: String? {
        value(for: "-pictriMemoriesPlaceDetail")
    }

    /// `-pictriMemoryFlipShowBack true` でPictriMemoryFlipCardの初期表示を裏面に
    /// する(タップ操作なしで裏面をスクショ確認するため)。DEBUG限定、既存のタップ
    /// 導線・表示ロジックには一切影響しない。
    static var memoryFlipShowBackInitially: Bool {
        value(for: "-pictriMemoryFlipShowBack") == "true"
    }

    /// `-pictriHomeCommentsOpen <postId>` でHomeの指定投稿カードのコメント欄を
    /// 開いた状態で直接スクショ確認できるようにする。DEBUG限定。
    static var homeCommentsOpenPostId: String? {
        value(for: "-pictriHomeCommentsOpen")
    }

    /// `-pictriHomeProfile <username>` でHomeの指定ユーザーのFriendProfileSheetを
    /// 直接開いてスクショ確認できるようにする。DEBUG限定。
    static var homeProfileUsername: String? {
        value(for: "-pictriHomeProfile")
    }

    /// `-pictriColorScenario multiPrefecture` で、未訪問/一部訪問/全達成の3状態を
    /// 複数県で同時にプレビューできるようにする。DEBUG限定。
    /// memoryStore/UserDefaultsへは一切書き込まず、表示上のcompletedCountだけを
    /// 差し替える(PrefectureMemorySummaryCard / prefectureChipsの2箇所のみが参照)。
    /// 数値は各県のtotalSpotCount(kanagawa:24 / tokyo:30 / kyoto:28)の範囲内で
    /// 安全に選んでいる。kyotoはtotalSpotCountと一致させ「全達成」状態を再現する。
    static var prefectureCountOverrides: [String: Int]? {
        guard value(for: "-pictriColorScenario") == "multiPrefecture" else { return nil }
        return [
            "kanagawa": 9,
            "tokyo": 3,
            "kyoto": 28
        ]
    }

    static func prefectureCountOverride(for prefectureId: String) -> Int? {
        prefectureCountOverrides?[prefectureId]
    }

    /// `-pictriAccountSection profile|friends|add|requests` でJQAccountSheetViewを
    /// 指定タブを開いた状態で直接起動できるようにする。DEBUG限定。
    /// 「友達コード」カード(addタブ)など、通常操作では複数タップが必要な領域を
    /// スクショ確認するために追加した。既存のアカウントアイコンタップ導線は無変更。
    static var homeAccountSection: JQAccountSection? {
        switch value(for: "-pictriAccountSection") {
        case "friends": return .friends
        case "add": return .add
        case "requests": return .requests
        case "settings": return .settings
        default: return nil
        }
    }

    static var cameraScenario: PictriCameraVisualScenario? {
        switch value(for: "-pictriCameraScenario") {
        case "ready": return .ready
        case "review": return .review
        case "saved": return .saved
        default: return nil
        }
    }

    /// CAMERA ROUND 1 QA専用。`-pictriCameraReviewShowBack true`でReview画面の
    /// two-sided cardを最初から裏(内カメラ/selfie側)表示で確認できるようにする。
    /// Home側の`-pictriHomeFlipShowBack`と同じ考え方(DEBUG限定、既存の
    /// flip実装自体には触れない)。
    static var cameraReviewShowBack: Bool {
        value(for: "-pictriCameraReviewShowBack") == "true"
    }

    /// CAMERA ROUND 1 QA専用。`-pictriCameraStyle standard|scenery|digicam`で
    /// 起動直後のCamera Styleを直接指定する(標準/風景/デジカメのスクショ確認用)。
    static var cameraStyleOverride: PictriCameraStyle? {
        switch value(for: "-pictriCameraStyle") {
        case "standard": return .standard
        case "digicam": return .digicam
        default: return nil
        }
    }

    /// `-pictriCameraAutoSave true`。Anywhere Capture Phase「Spot Unlock
    /// Architecture」のQA専用。GUIタップ自動化がこの開発環境では信頼できないため、
    /// `xcrun simctl location`で設定した現在地に対して、currentCaptureTargetが
    /// 解決/確定し次第、実写真撮影を経ずに本番と同じ`memoryStore.save`経路で
    /// 自動保存する(CameraView.performSave参照)。DEBUG限定、Production buildには
    /// この分岐自体が存在しない。
    static var cameraAutoSave: Bool {
        value(for: "-pictriCameraAutoSave") == "true"
    }

    /// `-pictriShowPaywall true`。Visual Foundation Part C QA専用。
    /// PictriPaywallSheetは通常「もっと残す」ボタンからのタップでしか開けないため、
    /// GUIタップ自動化が不安定なこの開発環境でも見た目を確認できるようにする。
    /// DEBUG限定、Productionの提示条件(明示的なCTAからのみ)には一切影響しない。
    static var showPaywallOnAppear: Bool {
        value(for: "-pictriShowPaywall") == "true"
    }

    /// `-pictriColorScenario multiPrefecture` の時、日本全体Mapのプレビュー用に
    /// 実データとは別に「訪問済み」に見せる都道府県idの集合。既存の
    /// prefectureCountOverrides(神奈川/東京/京都の達成率プレビュー)とは別の目的で、
    /// Map全体の色づき具合を確認するための表示専用フラグ。memoryStoreへは一切書き込まない。
    static var mapPreviewVisitedPrefectureIds: Set<String>? {
        guard value(for: "-pictriColorScenario") == "multiPrefecture" else { return nil }
        return [
            "hokkaido", "aomori", "miyagi", "saitama", "chiba", "tokyo", "kanagawa",
            "niigata", "shizuoka", "aichi", "kyoto", "osaka", "hyogo", "hiroshima",
            "fukuoka", "kochi"
        ]
    }

    /// `-pictriShowCameraDebugControls true` の時だけ、Camera上部にQA用の
    /// developerUnlockModeトグルを表示する。通常のCamera UIには常に隠し、
    /// 見せる用のスクショに機械的なトグルが写り込まないようにする。
    /// 位置認証の解放そのものは引き続き `-pictriDevUnlock true/false` で行える。
    static var showCameraDebugControls: Bool {
        value(for: "-pictriShowCameraDebugControls") == "true"
    }

    /// `-pictriOpening true`。Cinematic Opening v1専用のプレビュー経路。
    /// ONの時だけJapanQuestApp.rootViewがPictriOpeningPreviewHarnessを表示し、
    /// Openingの完了ごとに(loop再生で)何度でも確認できるようにする。通常起動・
    /// 本番のCold Launch経路には一切影響しない。
    static var openingPreviewRequested: Bool {
        value(for: "-pictriOpening") == "true"
    }

    /// `-pictriRunCarouselMetricsSelfTest true` — v15 Phase 7専用。起動直後に
    /// `PictriHomeCarouselLayoutMetricsSelfTest.run()`を実行し、結果を
    /// consoleへ出力する(XCTestターゲットが存在しないプロジェクトのため、
    /// 既存のDEBUG launch flag QAパターンを踏襲した簡易自己検証)。
    static var carouselMetricsSelfTestRequested: Bool {
        value(for: "-pictriRunCarouselMetricsSelfTest") == "true"
    }

    /// `-pictriHomeCarouselDragFraction <value>` — v16 Carousel Engine
    /// QAスクショ専用(DEBUG限定)。実gestureを介さず、指定した
    /// itemStep倍率でCarouselのdragTranslationを直接固定し、drag中間状態を
    /// 画面上で確認できるようにする。
    static var homeCarouselDebugDragFraction: String? {
        value(for: "-pictriHomeCarouselDragFraction")
    }

    /// `-pictriReduceMotionOverride true|false` — v16 Carousel Engine
    /// QAスクショ専用(DEBUG限定)。実機のAccessibility設定を変更せずに
    /// Reduce Motion ON/OFF両方の描画を検証できるようにする。
    static var reduceMotionDebugOverride: Bool? {
        switch value(for: "-pictriReduceMotionOverride") {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    /// `-pictriAppearance dark|light` で起動時のAppearanceを直接指定する。DEBUG限定、
    /// QAスクショ専用。指定時はUserDefaultsへも書き込み、通常のAppearance設定行と
    /// 同じ永続化経路を通す(表示専用の別経路を作らない)。
    static var appearanceOverride: PictriAppearanceMode? {
        switch value(for: "-pictriAppearance") {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// `-pictriOpeningConcept a|b|c` でOpening Motion Lab(Phase 7)の各conceptを
    /// 個別に起動・録画できるようにする。DEBUG限定・QA専用。未指定時は本番のPictriOpeningView
    /// (最終採用版)のまま(この型ごと存在しないReleaseでは常に本番Openingのみ)。
    static var openingConcept: String? {
        value(for: "-pictriOpeningConcept")
    }

    /// `-pictriSeedDualMemory true` で、実カメラ操作なしに「外カメラ(場所)+内カメラ(自分)」
    /// を両方持つ本物のMemoryを1件だけ作る(Visual Reality Check Phase)。既存の
    /// QuestMemoryStore.save(image:target:outerOnlyImage:selfieImage:)という実際の保存経路を
    /// そのまま呼ぶだけで、QA専用の別経路は作らない。対象はmockQuestSpotsの実在Spot
    /// (hakone_ropeway、既存のRecentColoredPlace/Feedが参照している画像なしMemoryと同じ
    /// spotIdなのでupsertで置き換わる)。DEBUG限定・Simulatorのローカルdocuments領域のみへの
    /// 書き込みで、Production配布物には一切含まれない。
    static var seedDualMemoryRequested: Bool {
        value(for: "-pictriSeedDualMemory") == "true"
    }

    /// `-pictriHomeConcept a|b|c` でHome Concept Lab(Visual Reality Check Phase)の
    /// 3案を個別にスクリーンショット比較できるようにする。DEBUG限定・QA専用。
    /// 未指定時は採用済みのconceptがそのまま使われる(この型ごと存在しないReleaseでは
    /// 常に採用版のみ)。
    static var homeConceptOverride: String? {
        value(for: "-pictriHomeConcept")
    }

    // MARK: - Horizontal Memory Carousel(Home)QA専用フラグ
    //
    // `xcrun simctl`にはtouch/drag注入手段が無いため、Carouselのswipe中間状態・
    // Flipの表・裏・中間フレーム・Like/Comment状態を「実際の指操作なし」で
    // 静止画確認するための起動引数群。全てDEBUG限定・表示専用で、通常の
    // タップ/ドラッグ導線やLike/Commentのデータ経路には一切影響しない。

    /// `-pictriHomeScrollTo <postId>` でCarouselの初期スクロール位置を指定postへ
    /// 直接合わせる。何度もdragせずにside cardのdepth状態を確認するため。
    static var homeScrollToPostId: String? {
        value(for: "-pictriHomeScrollTo")
    }

    /// `-pictriHomeFlipShowBack <postId>` で指定postのCardだけを裏面(内カメラ)
    /// 表示の状態で起動する(tap操作なしで裏面をスクショ確認するため)。
    static var homeFlipShowBackPostId: String? {
        value(for: "-pictriHomeFlipShowBack")
    }

    /// `-pictriHomeFlipMidpoint <postId>` で指定postのCardをflip motionの
    /// 中間点(90度、エッジオン)で静止させる。実機のdrag/animation中間フレームは
    /// simctlでは再現できないため、ghosting/鏡像化の有無を静止画で確認する専用。
    static var homeFlipMidpointPostId: String? {
        value(for: "-pictriHomeFlipMidpoint")
    }

    /// `-pictriHomeLikedPosts <id1,id2>` で指定post群をliked状態で起動する
    /// (Memory SealのActive見た目をtapなしで確認するため)。
    static var homeLikedPostIds: Set<String>? {
        guard let raw = value(for: "-pictriHomeLikedPosts") else { return nil }
        return Set(raw.split(separator: ",").map(String.init))
    }

    /// `-pictriHomeCommentsAutoFocus true` を`-pictriHomeCommentsOpen`と組み合わせ、
    /// Comment Note展開直後にcomposerへ自動でfocusを当てる(keyboard表示状態を
    /// tapなしでスクショ確認するため)。
    static var homeCommentsAutoFocus: Bool {
        value(for: "-pictriHomeCommentsAutoFocus") == "true"
    }

    /// `-pictriHomeFeedCount 0|1|2` でHomeの表示投稿数を強制的に制限する
    /// (empty/1件/2件状態をQuestSampleData自体を変更せずにスクショ確認するため)。
    static var homeFeedCountOverride: Int? {
        value(for: "-pictriHomeFeedCount").flatMap(Int.init)
    }

    /// `-pictriHomeMode map|recent` v10専用: 実gestureのtapを介さず、Home起動時の
    /// `homeMode`をQA用に直接指定する(simctlにはtap自動化が無いため)。DEBUG限定、
    /// 指定が無い/不正な値の場合は通常の既定値(`.map`)のまま。
    static var homeModeOverride: PictriHomeMode? {
        switch value(for: "-pictriHomeMode") {
        case "map": return .map
        case "recent": return .recent
        default: return nil
        }
    }

    /// `-pictriMapProgressOverrides "tokyo:5:12,osaka:3,kyoto:15:15"` Round 8 QA専用、
    /// HOME WHITE MAP REDESIGNで10〜15件容量に対応させた。`県id:達成数[:総数]`形式
    /// (総数省略時は12、将来の10〜15件運用を見越した既定値)。Home Mapの都道府県
    /// ごとの「おすすめSpot達成数/総数」を実際のMemoryデータと無関係に強制表示する。
    /// 複数の状態を同時に1枚のスクリーンショットへ収めるためのDEBUG限定
    /// オーバーライドで、QuestMemoryStore/UserDefaults・本番RecommendedSpot
    /// catalogには一切書き込まない(表示のみの上乗せ)。
    static var mapProgressOverrides: [String: (completed: Int, total: Int)] {
        guard let raw = value(for: "-pictriMapProgressOverrides") else { return [:] }
        var result: [String: (completed: Int, total: Int)] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: ":")
            guard parts.count >= 2, let completed = Int(parts[1]) else { continue }
            let total = parts.count >= 3 ? (Int(parts[2]) ?? 12) : 12
            result[String(parts[0])] = (completed: completed, total: total)
        }
        return result
    }

    /// `-pictriHomeSeedExtraFeed true` で、双方向Swipe QA専用の追加投稿を
    /// (本番`mockQuestFeedPosts`自体は変更せず)一時的に足す。デフォルトの
    /// mockデータは有効投稿が2件しかなく、中央indexの両側にside cardが
    /// 実在する状態を検証できないため。DEBUGビルド限定、Releaseには一切含まれない。
    /// `-pictriHomeSeedAnywhereQA true` Round 8専用。Anywhere Memory Card rim
    /// (neutral silver/soft-white)をQAで確認するための1件だけの追加投稿。
    static var homeSeedAnywhereQARequested: Bool {
        value(for: "-pictriHomeSeedAnywhereQA") == "true"
    }

    static var homeSeedExtraFeedRequested: Bool {
        value(for: "-pictriHomeSeedExtraFeed") == "true"
    }

    /// `-pictriHomeSimulateSwipe next|previous` v6専用。Circular Carouselの
    /// wrap挙動を、実gestureが通るのと同じ`scrollPosition`書き換え経路で
    /// 1段階だけ進める(`-pictriHomeScrollTo`で起点を指定した上で使う)。
    static var homeSimulateSwipe: String? {
        value(for: "-pictriHomeSimulateSwipe")
    }

    /// `-pictriHomeSeedRealPhotos true` v6専用。Card material/rim/depth/
    /// backgroundをplaceholderの単色gradientだけで評価しないよう、
    /// 既存の`renderPlaceholderPhoto`(色調違いのみ)を使った3件の
    /// 「写真らしい」Memoryを一時的に追加する。新しい画像生成の仕組みは
    /// 追加しない(既存のDual Memory QA seedと同じ関数を色違いで呼ぶだけ)。
    static var homeSeedRealPhotosRequested: Bool {
        value(for: "-pictriHomeSeedRealPhotos") == "true"
    }
}

enum PictriCameraVisualScenario: Equatable {
    case ready
    case review
    case saved
}
#endif

struct ContentView: View {
    @State private var selectedTab: AppTab = ContentView.resolveInitialTab()
    @State private var activeCameraSpotId: String = ContentView.resolveInitialCameraSpotId()
    /// CAMERA ROUND 1「CRITICAL FIX — MAP SELECTED SPOT」。Source of Truthは
    /// ここ(ContentView)。MapView.swiftの「ここで撮る」導線でだけtrueになり、
    /// QuestCameraView自身がCameraを離れるたびに必ずfalseへ戻す(詳細はCameraView.swift参照)。
    @State private var activeCameraSpotIsExplicit: Bool = ContentView.resolveInitialCameraSpotIsExplicit()
    /// Round「WORLD INTERACTIVE MAP」: MapタブのInteractive World Mapの
    /// camera位置。`QuestMapView`自身はタブ切り替えのたびに作り直されるため、
    /// Source of TruthをContentView(常駐)へ上げ、Map→Home→Mapを繰り返しても
    /// 直前のcamera位置(pan/zoom)が保持されるようにする。
    @State private var mapCameraPosition: MapCameraPosition = PictriWorldMapCamera.initial()
    /// Camera保存直後に「メモリーで確認する」から遷移した時だけ使う一時的な受け渡し。
    /// MemoriesViewはこれを見て、保存した記憶をExplore Detailで直接開く。
    /// 通常のタブバー操作では常にnilのままなので、既存のCollect/Explore遷移には影響しない。
    @State private var pendingExploreSpotId: String?
    @StateObject private var memoryStore = QuestMemoryStore()
    @StateObject private var friendStore = QuestFriendStore()
    @StateObject private var locationManager = QuestLocationManager()
    @StateObject private var entitlementStore = QuestEntitlementStore()
    @StateObject private var dailyCaptureAllowance = QuestDailyCaptureAllowance()
    @StateObject private var appearanceStore = PictriAppearanceStore()

    /// Bottom Nav 5番目のタブ(自分のアイコン)から開くAccount sheet。
    /// タブ自体はscreenを持たず、既存のJQAccountSheetViewをここから直接開く。
    @State private var showAccountMenu = false
    /// Home側でComment Noteが展開されている間、Bottom Navを一時的に隠すための
    /// 共有state(キーボード表示時にBottom Navが挟まって見える問題への対応)。
    @State private var isBottomBarHidden = false

    /// Camera中はタブバーを没入型に隠す。閉じるボタンと保存後の自動遷移で
    /// 操作性は維持したまま、下部でのタブバーとの衝突を構造的になくす。
    /// v7 CONCEPT C PRODUCTION MIGRATION: Homeでは旧5-tab barを廃止し、
    /// HomeView自身が持つ`PictriHomeControlDock`(Map/Camera/Album)へ
    /// 置き換えたため、Home表示中もこの旧barを隠す。Map/Camera/Memoriesは
    /// 変更せず、引き続きこの旧barからHomeへ戻れる(最小安全変更)。
    /// MAP/ALBUM REFERENCE MIGRATION: Map(`.map`)/Album(`.memories`)もHomeと
    /// 同様、自分自身の`PictriHomeControlDock`(shared Dock)を持つようになった
    /// ため、この旧`JQFloatingTabBar`はそれらのtabでも隠す(画面ごとに2つの
    /// Dockが二重に表示されることを防ぐ、G06「shared Dock使用」に対応)。
    /// `.vlog`だけは今回のReference対象外(Memories内部のmode切り替えからのみ
    /// 到達する既存経路、DEBUG専用)のため、旧barのまま維持する。
    private var isTabBarVisible: Bool {
        selectedTab != .camera
            && selectedTab != .home
            && selectedTab != .map
            && selectedTab != .memories
            && !isBottomBarHidden
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            activeScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
                // appearanceStore.modeが変わるたびにView識別子を切り替え、
                // 静的トークン参照(PictriDarkTheme.xxx等)を含むsubtree全体を
                // 確実に作り直す(部分的な差分更新に頼らず、Dark⇄Lightの
                // 切り替えが画面全体へ即座に一貫して反映されるようにするため)。
                .id(appearanceStore.mode)

            // Camera中は即座に消す。アニメーションを付けると、消えかけのタブバーと
            // 切り替わった直後のCamera UIが一瞬重なって「崩れ」に見えるため、
            // 表示・非表示そのものはアニメーションさせない(中身の押下演出は別途維持)。
            if isTabBarVisible {
                // Visual Direction Consolidation: PictriDarkTheme自体がmode-aware
                // (Dark/Light Appearance)になったため、isDarkPreviewという個別の
                // 上書きフラグは廃止し、常に正準トークンを直接参照する。
                JQFloatingTabBar(
                    selectedTab: $selectedTab,
                    accountBadgeCount: friendStore.incomingRequests.count,
                    onAccountTap: { showAccountMenu = true }
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(AppBackground())
        .sheet(isPresented: $showAccountMenu) {
            JQAccountSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .environmentObject(memoryStore)
        .environmentObject(friendStore)
        .environmentObject(locationManager)
        .environmentObject(entitlementStore)
        .environmentObject(dailyCaptureAllowance)
        .environmentObject(appearanceStore)
        .preferredColorScheme(appearanceStore.mode.colorScheme)
        .onAppear {
            #if DEBUG
            if PictriVisualReview.dailyCaptureRecordNowRequested {
                dailyCaptureAllowance.recordCaptureSaved()
            }
            if PictriVisualReview.seedDualMemoryRequested {
                seedDualMemoryForQA()
            }
            if PictriVisualReview.homeSeedRealPhotosRequested {
                seedRealPhotoFeedForQA()
            }
            #endif
        }
    }

    #if DEBUG
    /// `-pictriSeedDualMemory true`専用。外カメラ(場所)・内カメラ(自分)それぞれ独立した
    /// 合成画像を描画し、本番と同じQuestDualPhotoComposer.composeで1枚のcompositeを作った上で、
    /// 本番と同じmemoryStore.save(...)を呼ぶ。新しいpersistence経路・新しいMemory概念は
    /// 一切追加しない(実カメラでの撮影を手で再現しているだけ)。
    private func seedDualMemoryForQA() {
        guard let spot = mockQuestSpots.first(where: { $0.id == "hakone_ropeway" }) else { return }

        let outer = Self.renderPlaceholderPhoto(
            size: CGSize(width: 1080, height: 1440),
            topColor: UIColor(red: 0.42, green: 0.58, blue: 0.62, alpha: 1),
            bottomColor: UIColor(red: 0.16, green: 0.22, blue: 0.20, alpha: 1),
            drawMountain: true
        )
        let selfie = Self.renderPlaceholderPhoto(
            size: CGSize(width: 720, height: 960),
            topColor: UIColor(red: 0.55, green: 0.38, blue: 0.30, alpha: 1),
            bottomColor: UIColor(red: 0.30, green: 0.20, blue: 0.16, alpha: 1),
            drawMountain: false
        )
        let composite = QuestDualPhotoComposer.compose(backImage: outer, frontImage: selfie, spot: spot)

        memoryStore.save(
            image: composite,
            target: .curatedSpot(spot),
            verificationStatus: .verified,
            outerOnlyImage: outer,
            selfieImage: selfie
        )
    }

    /// `-pictriHomeSeedRealPhotos true`専用(v6)。Home Circular Carouselの
    /// Card material/rim/depth/backgroundを単色placeholderだけで評価しない
    /// ため、既存の`renderPlaceholderPhoto`を色調違いで3回呼び、「写真らしい」
    /// Memoryを一時的に3件追加する。新しい画像生成手段・新しいpersistence経路は
    /// 追加せず、`seedDualMemoryForQA`と同じ`memoryStore.save(...)`経路のみを使う。
    /// 外部downloadは行わない。
    private func seedRealPhotoFeedForQA() {
        let palette: [(spotId: String, top: UIColor, bottom: UIColor, mountain: Bool)] = [
            ("enoshima_coast", UIColor(red: 0.86, green: 0.55, blue: 0.32, alpha: 1), UIColor(red: 0.32, green: 0.16, blue: 0.14, alpha: 1), false),
            ("minatomirai", UIColor(red: 0.20, green: 0.30, blue: 0.42, alpha: 1), UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1), false),
            ("hakone_shrine", UIColor(red: 0.55, green: 0.62, blue: 0.50, alpha: 1), UIColor(red: 0.18, green: 0.22, blue: 0.16, alpha: 1), true)
        ]
        for entry in palette {
            guard let spot = mockQuestSpots.first(where: { $0.id == entry.spotId }) else { continue }
            let photo = Self.renderPlaceholderPhoto(
                size: CGSize(width: 1080, height: 1440),
                topColor: entry.top,
                bottomColor: entry.bottom,
                drawMountain: entry.mountain
            )
            memoryStore.save(image: photo, target: .curatedSpot(spot), verificationStatus: .verified, outerOnlyImage: photo)
        }
    }

    /// 実写真の代わりに使う、QA専用の合成プレースホルダー画像。単色矩形ではなく、
    /// gradient + 簡単な地平線/人物シルエットを描き、Flip CardやPhotoPrintの見た目を
    /// 「壊れた空白カード」ではなく「写真らしい何か」として評価できるようにする。
    private static func renderPlaceholderPhoto(
        size: CGSize,
        topColor: UIColor,
        bottomColor: UIColor,
        drawMountain: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            let colors = [topColor.cgColor, bottomColor.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width / 2, y: 0),
                    end: CGPoint(x: size.width / 2, y: size.height),
                    options: []
                )
            }
            if drawMountain {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: size.height * 0.62))
                path.addLine(to: CGPoint(x: size.width * 0.38, y: size.height * 0.40))
                path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.55))
                path.addLine(to: CGPoint(x: size.width, y: size.height * 0.34))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
                cgContext.setFillColor(UIColor(white: 0.05, alpha: 0.35).cgColor)
                cgContext.addPath(path)
                cgContext.fillPath()
            } else {
                let circleRect = CGRect(
                    x: size.width * 0.5 - size.width * 0.28,
                    y: size.height * 0.30,
                    width: size.width * 0.56,
                    height: size.width * 0.56
                )
                cgContext.setFillColor(UIColor(white: 0.08, alpha: 0.30).cgColor)
                cgContext.fillEllipse(in: circleRect)
            }
        }
    }
    #endif

    /// DEBUGビルド限定・目視QA専用の起動引数対応。
    /// `-pictriStartTab home|map|camera|memories` でSimulator起動時に
    /// 直接そのタブを開けるようにし、自動タップに頼らずスクリーンショットを取得できるようにする。
    /// Releaseビルドでは常にhomeから始まる(このstatic funcごと存在しない)。
    private static func resolveInitialTab() -> AppTab {
        #if DEBUG
        if let devUnlockOverride = PictriVisualReview.devUnlockOverride {
            UserDefaults.standard.set(devUnlockOverride, forKey: "developerUnlockMode")
        }
        return PictriVisualReview.startTab ?? .home
        #else
        return .home
        #endif
    }

    /// `-pictriCameraSpot <spotId>` でCamera起動時のspotを直接指定する。DEBUG限定。
    /// 指定spotIdがmockQuestSpotsに存在しない場合は既存デフォルト(enoshima_coast)へ
    /// フォールバックする。通常操作(タブ間の実際のスポット選択)には一切影響しない。
    /// CAMERA ROUND 2 QA専用。`-pictriCameraSpotExplicit true`指定時のみtrueで
    /// 起動する(通常起動は常にfalse、Map「ここで撮る」導線とは無関係)。
    private static func resolveInitialCameraSpotIsExplicit() -> Bool {
        #if DEBUG
        return PictriVisualReview.cameraSpotIsExplicit
        #else
        return false
        #endif
    }

    private static func resolveInitialCameraSpotId() -> String {
        #if DEBUG
        if let spotId = PictriVisualReview.cameraSpotId,
           mockQuestSpots.contains(where: { $0.id == spotId }) {
            return spotId
        }
        #endif
        return "enoshima_coast"
    }

    @ViewBuilder
    private var activeScreen: some View {
        switch selectedTab {
        case .home:
            // Visual Direction Consolidation: HomeDarkViewはPictriAppearanceStoreによる
            // 正式なDark/Light切り替えに置き換わったため統合した(並存物は廃止)。
            HomeView(
                selectedTab: $selectedTab,
                isBottomBarHidden: $isBottomBarHidden,
                onAccountTap: { showAccountMenu = true }
            )

        case .map:
            // 同上。MapDarkViewもAppearance機構へ統合した。
            // MAP/ALBUM REFERENCE MIGRATION: root画面がHome同様のshared Dock/
            // top languageへ移行したため、onAccountTapもHomeと同じ経路
            // (既存JQAccountSheetView)へ橋渡しする。
            // Round「WORLD INTERACTIVE MAP / DIRECT HOME NAVIGATION」:
            // onHomeTapはAdaptive 3-slot Dockの「ホームへ戻る」slot用
            // (Cameraを経由せず1tapでHomeへ戻る、Navigation root causeの修正)。
            QuestMapView(
                selectedTab: $selectedTab,
                activeCameraSpotId: $activeCameraSpotId,
                activeCameraSpotIsExplicit: $activeCameraSpotIsExplicit,
                onAccountTap: { showAccountMenu = true },
                onHomeTap: { selectedTab = .home },
                worldMapCameraPosition: $mapCameraPosition
            )

        case .camera:
            QuestCameraView(
                selectedTab: $selectedTab,
                selectedSpotId: $activeCameraSpotId,
                pendingExploreSpotId: $pendingExploreSpotId,
                selectedSpotIsExplicit: $activeCameraSpotIsExplicit
            )

        case .vlog:
            MemoriesView(pendingExploreSpotId: $pendingExploreSpotId, initialMode: .vlog)

        case .memories:
            MemoriesView(
                pendingExploreSpotId: $pendingExploreSpotId,
                initialMode: .collect,
                selectedTab: $selectedTab,
                onAccountTap: { showAccountMenu = true },
                notificationBadgeCount: friendStore.incomingRequests.count
            )
        }
    }
}

/// PREMIUM REFRESH(2026-08-25、Home全面再設計に伴うBottom Nav改修):
/// 5 tabs(Home/Map/Camera/Memories/自分のアイコン)、Cameraが幾何学的にも
/// 完全に中央。旧: `.ultraThinMaterial`一枚+hairlineのみだったため、暗背景の
/// 上では「ただ薄いグレーの帯」に見え、安物のiOS標準タブバーの焼き直しに
/// 見えていた。今回は
/// 1) 下地に不透明に近いgraphiteのsolid fillを敷いた上でmaterialを重ね、
///    「奥行きのある固体」に見えるようにする、
/// 2) bar上端にごく薄いrim highlightを足し、光が縁を回り込む質感を出す、
/// 3) barの角丸・左右marginを強め、画面に貼り付いたiOS標準タブバーではなく
///    「浮いた1枚の板」に見えるようにする、
/// の3点で「安物のグレー」を解消した。Vlog/お知らせタブは仕様変更により
/// Bottom Navから外し、5番目を「自分のアイコン」(Account sheetへの入口)に
/// 差し替えた。AppTab列挙体自体は他画面からの参照が多く残るため変更せず、
/// このBarが表示するtab集合だけを絞っている(`.vlog`はMemories内部の
/// モード切り替えから引き続き到達可能、機能自体は失われていない)。
struct JQFloatingTabBar: View {
    @Binding var selectedTab: AppTab
    var accountBadgeCount: Int = 0
    var onAccountTap: () -> Void = {}

    private let tabs: [AppTab] = [
        .home,
        .map,
        .camera,
        .memories
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    if tab == .camera {
                        JQCentralCameraAction()
                    } else {
                        JQFloatingTabItem(tab: tab, isSelected: selectedTab == tab)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }

            Button(action: onAccountTap) {
                JQAccountTabItem(badgeCount: accountBadgeCount)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("アカウント")
            .accessibilityValue(accountBadgeCount == 0 ? "" : "フレンド申請\(accountBadgeCount)件")
        }
        .padding(.horizontal, 6)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .background(JQTabBarMaterial())
    }
}

/// Bar本体の質感(下地solid fill + material + 上端rim highlight + 外周shadow)。
/// 単一のMaterialだけに頼らず、solid fillを下敷きにすることで暗背景でも
/// 「薄く透けたグレー」に見えないようにしている。
/// SIGNATURE PHYSICAL WORLD CLOSURE: 3候補を実機比較。
/// A) MATTE MEMORY SHELF(採用): 上辺だけ大きく丸め、下辺はほぼ角(4pt)にする
///    ことで「画面下端から薄い棚が少しだけ立ち上がっている」物体に見える。
///    左右marginは維持したままedge-to-edgeにはしない。
/// B) FLOATING PHOTO DOCK: 全周14ptの低いradiusにした「板」。悪くはないが、
///    Aほど「棚」の物体感が出ず、単に角丸を弱めたrounded rectangleに見えた。
/// C) 前回のsymmetric pill(22pt全周): 最も無難だが、Originality上「良い
///    Tab Bar」止まりで「PicTriのTab Bar」という固有性が弱いと判断。
/// → Aを採用。
private struct JQTabBarMaterial: View {
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 28, style: .continuous)
    }
    var body: some View {
        shape
            .fill(PictriDarkTheme.surfaceOverlay.opacity(0.92))
            .background { shape.fill(PictriDarkTheme.glassMaterial) }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
    }
}

struct JQFloatingTabItem: View {
    let tab: AppTab
    let isSelected: Bool

    /// 選択時はfilled icon、非選択時は同じSF Symbolのoutline版に落とす。
    private var iconName: String {
        isSelected ? tab.iconName : tab.iconName.replacingOccurrences(of: ".fill", with: "")
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 19, weight: isSelected ? .bold : .regular))

            Text(tab.title)
                .font(PictriTypography.body(9.5, weight: .bold))

            Circle()
                .fill(isSelected ? PictriDarkTheme.accent : .clear)
                .frame(width: 4, height: 4)
        }
        .foregroundStyle(isSelected ? PictriDarkTheme.textPrimary : PictriDarkTheme.textFaint)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}

/// Bottom Nav 5番目、自分のアイコン(Account sheetへの入口)。
/// VISUAL REALITY CHECK: genericな`person.crop.circle`のSF Symbolは、他の
/// identity表示(Home card / Account header)が「色付き円+イニシャル」の
/// avatarで統一されているのに対して浮いて見えるため、同じavatar言語へ揃えた。
/// 選択強調はneon/badgeで目立たせず、極薄accent rimのみに留める。
struct JQAccountTabItem: View {
    let badgeCount: Int

    private var avatarAccent: Color {
        HomeFriendColor.accent(for: "keita_travel")
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(avatarAccent.opacity(0.9))
                    .frame(width: 21, height: 21)
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.75)
                    }
                    .overlay {
                        Text("K")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.72))
                    }

                if badgeCount > 0 {
                    Circle()
                        .fill(PictriDarkTheme.accent)
                        .frame(width: 7, height: 7)
                        .overlay {
                            Circle().strokeBorder(PictriDarkTheme.surfaceOverlay, lineWidth: 1)
                        }
                        .offset(x: 3, y: -2)
                }
            }

            Text("アカウント")
                .font(PictriTypography.body(9.5, weight: .bold))

            Circle()
                .fill(Color.clear)
                .frame(width: 4, height: 4)
        }
        .foregroundStyle(PictriDarkTheme.textFaint)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}

/// Bottom Navの幾何学的な中央(5 tabs中の3番目)に置く、唯一のPrimary Action。
/// VISUAL REALITY CHECK: 前回の「terracotta circle + glow ring」は、画像で見ると
/// 明確に「巨大orange circleのfloating action button」に見え、G14相当の要求
/// (glowで目立たせない・navと一体化)にFAILしていた。barの上に浮かせず、他の
/// tab itemと同じ高さに収め、barの素材に軽く沈んだ小さな「lens」だけを
/// terracottaにする(周囲にglow shadowを一切持たせない)。
struct JQCentralCameraAction: View {
    var body: some View {
        ZStack {
            // bar面へわずかに沈んだ窪み(depression)。glowではなく、内側だけ
            // ごく僅かに暗くすることで「同じ板の一部が凹んでいる」印象にする。
            Circle()
                .fill(PictriDarkTheme.surfaceBase.opacity(0.6))
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.28), lineWidth: 1)
                }
                .frame(width: 44, height: 44)

            Circle()
                .fill(PictriDarkTheme.accent)
                .frame(width: 30, height: 30)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.75)
                }
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PictriDarkTheme.onAccent)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentShape(Rectangle())
    }
}

enum AppTab: Hashable, CaseIterable {
    case home
    case map
    case camera
    case vlog
    case memories

    var title: String {
        switch self {
        case .home:
            return "ホーム"
        case .map:
            return "マップ"
        case .camera:
            return "カメラ"
        case .vlog:
            return "Vlog"
        case .memories:
            return "メモリー"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            return "house.fill"
        case .map:
            return "map.fill"
        case .camera:
            return "camera.fill"
        case .vlog:
            return "play.rectangle.fill"
        case .memories:
            return "square.grid.2x2.fill"
        }
    }
}

enum JQUI {
    static let sidePadding: CGFloat = 18
    static let screenTopPadding: CGFloat = 70
    static let panelHeight: CGFloat = 430
    static let panelCornerRadius: CGFloat = 34
    static let bottomBarReserve: CGFloat = 116
}

// MARK: - Shared

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                PictriTheme.backgroundTop,
                PictriTheme.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}


#Preview {
    ContentView()
}
