# PROJECT_STATE.md — ピクトリ（Pictri）現在の実装状況

最終更新: 2026-06-05（Step 3-F 完了）

> **プロダクト名:** ピクトリ（Pictri）— *picture trip* に由来  
> **内部プロジェクト名:** JapanQuest（Xcode・Bundle ID・型名はそのまま）

---

## ビルド状態

| 項目 | 状態 |
|-----|------|
| Xcode Build | **Succeeded** |
| ブランチ | `main` |
| 最新コミット | `103f968` — Add camera save feedback UI |
| 最新Swiftコード変更 | `103f968` — Add camera save feedback UI |
| ワーキングツリー | クリーン |

---

## コミット履歴（直近）

```
103f968  Add camera save feedback UI
f51b31d  Update project state after CameraView extraction
4d6e29b  Extract Camera views from ContentView
6448f82  Record core flow verification results
3726de5  Improve spot detail view on map screen
4063000  Update project state after MapView extraction
```

---

## 完了済みステップ

### Step 1-A: レガシーファイル削除（完了）
- 削除ファイル: `Spot.swift` / `PhotoStore.swift` / `LocationManager.swift` / `StampRenderer.swift` / `CameraPicker.swift`
- `JapanQuestApp.swift` から `PhotoStore` 関連2行を削除
- `ContentView.swift` の重複 `captureControls` と死にコードを削除（101行削減）
- コミット: `"Fix build error and complete Step 1-A cleanup"`

### Step 1-B-1: MemoriesView.swift 分割（完了）
- `MemoriesView.swift` を新規作成（452行）
- ContentView.swift: 3457行 → 3005行
- 移動した型: `MemoriesView` / `PrefectureMemorySummaryCard` / `PrefecturePreviewTile` / `PrefectureMemoryDetailView` / `FixedMemorySpotCell` / `FixedEmptySpotCell` / `MemoryVisualStyle`
- コミット: `"Extract Memories views from ContentView"`

### Step 1-B-2: 旧 Account 系 死にコード削除（完了）
- 方針: AccountView.swift への分割ではなく、未使用のため削除
- 削除した型（8つ）: `AccountView` / `AccountSection` / `AccountSectionButton` / `AccountStat` / `AccountMenuRow` / `FriendRow` / `FriendRequestRow` / `AccountQuickMenuView`
- ContentView.swift: 3005行 → 2576行（429行削除）
- 残した型: `JQAccountSheetView` 系（現役）/ `AppBackground`（共有）
- コミット: `"Remove unused legacy account views"`

### Step 3-A: Home Hero カード スポット進捗表示（完了）
- `HomeView` に `completedSpotCount`（ユニーク spotId 数）と `kanagawaTotalSpotCount`（`mockQuestPrefectures` から取得）を追加
- Hero カードのサブテキストを動的に: 0件時「まず1箇所...」/ 1件以上「神奈川 X / 24 スポット」
- コミット: `"Show spot progress in home hero card"`

### Step 3-B: EmptyFeedCard Map-first 改善（完了）
- アイコン: `camera.circle` → `mappin.and.ellipse`
- 見出し: 「まだ7日以内のシェアがありません」→「まだフレンドの記録がありません」
- サブテキスト: 撮影促進 → 「地図でスポットを見つけて、現地で写真を残すと...」
- コミット: `"Update empty home state for map-first journey"`

### Step 3-G: UI 表示名を「ピクトリ」に変更（完了）
- `HomeView.topBar` の `Text("JapanQuest")` → `Text("ピクトリ")`
- 変更は `HomeView.swift` 1行のみ
- Xcode プロジェクト名・Bundle Identifier・ファイル名・型名は変更していない
- コミット: `"Rename app display name to Pictri in home top bar"`

### Step 1-B-5: HomeView.swift 分割（完了）
- `HomeView.swift` を新規作成（975行）
- ContentView.swift: 2586行 → 1613行（-973行）
- 移動した型（13型）: `HomeView` / `HomeMemoryTile` / `EmptyFeedCard` / `HomeLargePostCard` / `HomePostDetailSheet` / `JQAccountSheetView` / `JQAccountSection` / `JQAccountSectionButton` / `JQAccountStat` / `JQAccountMenuRow` / `JQFriendMiniRow` / `JQRequestMiniRow`
- pbxproj 変更不要（PBXFileSystemSynchronizedRootGroup 使用）
- コミット: `"Extract Home views from ContentView"`

### Step 3-H: Home Hero カード Map 導線改善（完了）
- Hero カード主文言: `"次の場所を見つける"` → `"次のスポットを地図で探す"`
- Map ボタン文言: `"Mapを開く"` → `"地図でスポットを探す"`
- 変更は `HomeView.swift` 2行のみ、レイアウト・遷移処理は変更なし
- コミット: `"Improve map navigation from home hero card"`

### Step 3-I: Home「気になるスポット」セクション追加（完了）
- `unvisitedKanagawaSpots` — 未訪問スポット最大2件を gridIndex 順で取得
- `nextSpotSection` — スポット名・エリア名カード + 「地図で見る」CTA（`selectedTab = .map`）
- カードにピンアイコン・ボーダー・視認性強化を追加
- 変更は `HomeView.swift` のみ
- コミット: `"Add next spot prompt to home screen"` / `"Enhance next spot card on home screen"`

### Step 1-B-4: MapView.swift 分割（完了）
- `MapView.swift` を新規作成（384行）
- ContentView.swift: 1613行 → 1231行（-382行）
- 移動した型（2型）: `QuestMapView` / `QuestSpotDetailView`
- pbxproj 変更不要（PBXFileSystemSynchronizedRootGroup 使用）
- コミット: `"Extract Map views from ContentView"`

### Step 3-E: コアフロー確認（完了・Swift変更なし）
- 調査対象: `ContentView.swift` / `MapView.swift` / `HomeView.swift` / `MemoriesView.swift` / `QuestMemoryStore.swift` / `QuestMapKitView.swift`
- 結果: 破損箇所なし。全ステップがコード上正しく接続されていることを確認
- Swift コード変更ゼロ（修正対象なし）
- コミットなし（差分なし）
- **実機での完全確認は別途必要**（Build Succeeded および重大エラーなしは確認済み）

### Step 1-B-3: CameraView.swift 分割（完了）
- `CameraView.swift` を新規作成（1043行）
- ContentView.swift: 1231行 → 186行（-1045行）
- 移動した型（4型）: `QuestCameraView` / `QuestDualCapturePhase` / `QuestDemoPhotoMaker` / `QuestDualPhotoComposer`
- import 調整: ContentView.swift から `import UIKit` / `import AVFoundation` を削除
- pbxproj 変更不要（PBXFileSystemSynchronizedRootGroup 使用）
- コミット: `"Extract Camera views from ContentView"`

### Step 3-F: Camera 保存フィードバック UI 改善（完了）
- 保存済みボタン背景を `.green` → `.white.opacity(0.14)` に変更（黒白基調に統一）
- `hasSaved = true` を `withAnimation` でラップ（スムーズな出現）
- 保存後に「Memoriesで確認する」ボタンを追加（`selectedTab = .memories` へ遷移）
- ヒントテキストを保存後に「Memoriesに保存しました」へ切り替え
- 変更ファイル: `CameraView.swift` のみ（+35行 / -7行）
- コミット: `"Add camera save feedback UI"`

---

## 現在のファイル構成

### Swift ファイル（全体）

| ファイル | 行数 | 状態 |
|---------|-----|------|
| `ContentView.swift` | 186行 | **分割完了**（Root / TabBar / JQUI / AppBackground のみ） |
| `CameraView.swift` | 1043行 | **分割済み**（Camera 関連View） |
| `HomeView.swift` | 1053行 | 分割済み（Home + JQAccount 系） |
| `MapView.swift` | 384行 | 分割済み（QuestMapView / QuestSpotDetailView） |
| `MemoriesView.swift` | 455行 | 分割済み |
| `JapanQuestApp.swift` | 10行 | 完了 |
| `QuestModels.swift` | 172行 | 要精査（旧モデルが残存） |
| `QuestSampleData.swift` | 618行 | 要精査（旧モックデータが残存） |
| `QuestMemoryStore.swift` | 267行 | 安定 |
| `QuestFriendStore.swift` | 54行 | 安定 |
| `QuestLocationManager.swift` | 90行 | 安定 |
| `QuestCameraService.swift` | 221行 | 安定 |
| `QuestCameraPreview.swift` | 46行 | 安定 |
| `QuestMapKitView.swift` | 411行 | 安定 |
| `QuestOverlayRenderer.swift` | 109行 | 安定 |
| `QuestProofBadge.swift` | 98行 | 安定 |
| `ShareSheet.swift` | 20行 | 安定 |

### ContentView.swift 内の残存ドメイン

| ドメイン | 型 | 行数 | 備考 |
|---------|---|-----|------|
| Root / TabBar / JQUI | ContentView, JQFloatingTabBar, JQFloatingTabItem, AppTab, JQUI | ~168行 | 最終的に残す |
| Shared | AppBackground | ~18行 | SharedComponents.swift へ移動予定（Step 1-B-6） |

### 各ファイルのドメイン（分割済み）

| ファイル | 収録ドメイン | 備考 |
|---------|------------|------|
| `CameraView.swift` | QuestCameraView, QuestDualCapturePhase, QuestDemoPhotoMaker, QuestDualPhotoComposer | Step 1-B-3 完了 |
| `MapView.swift` | QuestMapView, QuestSpotDetailView | Step 1-B-4 完了 |
| `HomeView.swift` | HomeView 系13型 + JQAccount 系 | Step 1-B-5 完了 |
| `MemoriesView.swift` | MemoriesView 系 + MemoryVisualStyle | Step 1-B-1 完了 |

---

## 各画面の現状

### Home（実装済み・動作確認未実施）
- トップバー: **「ピクトリ」表示済み**（Step 3-G 完了）
- Hero カード: **「地図でスポットを探す」Map導線強化済み**（Step 3-H）/ 撮るボタン / **スポット進捗を実データ反映済み**
- 最近のシェア: フィードポスト一覧（モックデータ）/ **空状態は Map-first 文言・アイコンに更新済み**
- 最近埋まった場所: メモリーグリッド（実データ反映済み）
- アカウントシート: Home 右上から `JQAccountSheetView` をシートで表示
- 未改善: 「最近のシェア」「最近埋まった場所」のセクション名

### Map（実装済み・MapView.swift 分割済み・動作確認未実施）
- `MapView.swift` に分割済み（Step 1-B-4 完了）
- 神奈川のみ表示（他県は未実装）
- `QuestMapKitView` で MapKit レンダリング
- スポットタップ → `QuestSpotDetailView` へ NavigationStack で遷移
- スポット詳細からカメラ画面へ遷移可能
- `developerUnlockMode = true` のため、GPS に関わらずアンロック状態

### Camera（実装済み・CameraView.swift 分割済み・動作確認未実施）
- `CameraView.swift` に分割済み（Step 1-B-3 完了）
- 内カメ → 外カメの2枚連続撮影フロー（`QuestDualCapturePhase`）
- `developerUnlockMode = true` のため、現地にいなくても撮影可能（Step 2-A で `false` 化予定）
- `QuestDemoPhotoMaker`（カラーパネル生成）と `QuestDualPhotoComposer`（合成）が内蔵
- 保存後に `QuestMemoryStore` へ追加され、Memories タブに反映される
- **保存後フィードバック UI 改善済み**（Step 3-F 完了）: 「Memoriesで確認する」ナビゲーション + 保存完了テキスト

### Memories（実装済み・動作確認未実施）
- `MemoriesView.swift` として分離済み
- 県別サマリーカード + 詳細ビュー
- `QuestMemoryStore` の実データを表示

### Account（実装済み・動作確認未実施）
- `JQAccountSheetView` がシートとして表示される
- フォロー中 / フォロワー / スポット統計
- フレンド追加・申請管理（ローカルのみ、Firebase 未接続）

---

## コアフローの確認状況

> 「コード上確認済み」= コードの接続を静的に確認。「実機確認済み」= 実機/シミュレーターで実際に動作確認。

| フロー | 状態 |
|-------|------|
| Home → Map タブ遷移 | コード上確認済み（実機確認は別途必要） |
| Map でスポット選択 → SpotDetailView 遷移 | コード上確認済み（実機確認は別途必要） |
| SpotDetailView → Camera へ activeCameraSpotId を渡す | コード上確認済み（実機確認は別途必要） |
| Camera に正しい spotId が渡る（binding chain） | コード上確認済み（実機確認は別途必要） |
| Camera で2枚撮影 → QuestMemoryStore.save() 呼び出し | コード上確認済み（実機確認は別途必要） |
| 保存後に Memories に自動反映（@Published + @EnvironmentObject） | コード上確認済み（実機確認は別途必要） |
| Home フィードにポストが表示 | 未確認 |
| Account シートの開閉 | 未確認 |

---

## 既知の課題

### App Store 提出前に必須の修正
1. **`developerUnlockMode` デフォルトが `true`**
   - `QuestSpotDetailView`（`MapView.swift`）と `QuestCameraView`（`CameraView.swift`）の両方で `@AppStorage("developerUnlockMode") private var developerUnlockMode = true`
   - ユーザーが現地にいなくてもスポットをアンロック・撮影できてしまう
   - デフォルトを `false` に変更し、開発者向けトグルは隠す必要がある（Step 2-A）

2. **カメラ権限なしの場合のフォールバック未確認**
   - AVFoundation のエラーハンドリングが十分かは未確認

### コードの課題
3. **旧モデル型が QuestModels.swift に残存**
   - `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot` は View からは参照されていないが、`QuestSampleData.swift` 内でのみ使われている
   - 未使用なら Models + SampleData から削除可能（Step 1-B-7）

4. **Map は神奈川のみ**
   - 他県のスポットデータは `mockQuestSpots` に含まれているが、Map 画面は `kanagawa` フィルタのみ
