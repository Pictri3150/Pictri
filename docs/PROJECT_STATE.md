# PROJECT_STATE.md — ピクトリ（Pictri）現在の実装状況

最終更新: 2026-06-04

> **プロダクト名:** ピクトリ（Pictri）— *picture trip* に由来  
> **内部プロジェクト名:** JapanQuest（Xcode・Bundle ID・型名はそのまま）

---

## ビルド状態

| 項目 | 状態 |
|-----|------|
| Xcode Build | **Succeeded** |
| ブランチ | `main` |
| 最新コミット | `fab79d6` — Extract Map views from ContentView |
| 最新Swiftコード変更 | `fab79d6` — Extract Map views from ContentView |
| ワーキングツリー | クリーン |

---

## コミット履歴（直近）

```
fab79d6  Extract Map views from ContentView
cc15bf9  Enhance next spot card on home screen
651d464  Add next spot prompt to home screen
1c894c7  Update project state after home hero navigation improvement
43e9fca  Improve map navigation from home hero card
1f35a15  Fix project state commit references
4eac84a  Update project state after HomeView extraction
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
- ContentView.swift: 2576行 → 2586行（+10行）
- コミット: `"Show spot progress in home hero card"`

### Step 3-B: EmptyFeedCard Map-first 改善（完了）
- アイコン: `camera.circle` → `mappin.and.ellipse`
- 見出し: 「まだ7日以内のシェアがありません」→「まだフレンドの記録がありません」
- サブテキスト: 撮影促進 → 「地図でスポットを見つけて、現地で写真を残すと...」
- コミット: `"Update empty home state for map-first journey"`

### Step 3-G: UI 表示名を「ピクトリ」に変更（完了）
- `HomeView.topBar` の `Text("JapanQuest")` → `Text("ピクトリ")`
- 変更は `ContentView.swift` 1行のみ
- Xcode プロジェクト名・Bundle Identifier・ファイル名・型名は変更していない
- コミット: `"Rename app display name to Pictri in home top bar"`

### Step 1-B-5: HomeView.swift 分割（完了）
- `HomeView.swift` を新規作成（975行）
- ContentView.swift: 2586行 → 1613行（-973行）
- 移動した型（13型）: `HomeView` / `HomeMemoryTile` / `EmptyFeedCard` / `HomeLargePostCard` / `HomePostDetailSheet` / `JQAccountSheetView` / `JQAccountSection` / `JQAccountSectionButton` / `JQAccountStat` / `JQAccountMenuRow` / `JQFriendMiniRow` / `JQRequestMiniRow`
- `AppBackground` / `JQUI` は今回移動しなかった（ContentView.swift に残存）
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

---

## 現在のファイル構成

### Swift ファイル（全体）

| ファイル | 行数 | 状態 |
|---------|-----|------|
| `ContentView.swift` | 1231行 | 分割進行中（Camera が残存） |
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
| Camera | QuestCameraView, QuestDualCapturePhase, QuestDemoPhotoMaker, QuestDualPhotoComposer | ~1043行 | 分割予定（Step 1-B-3、後回し） |
| Shared | AppBackground | ~19行 | SharedComponents.swift へ移動予定 |

### MapView.swift 内のドメイン（分割済み）

| ドメイン | 型 | 行数 | 備考 |
|---------|---|-----|------|
| Map | QuestMapView, QuestSpotDetailView | ~382行 | 分割済み |

### HomeView.swift 内のドメイン（分割済み）

| ドメイン | 型 | 行数 | 備考 |
|---------|---|-----|------|
| Home | HomeView, HomeMemoryTile, EmptyFeedCard, HomeLargePostCard, HomePostDetailSheet, nextSpotSection | ~720行 | 分割済み |
| JQAccount | JQAccountSheetView, JQAccountSection, JQAccountSectionButton, JQAccountStat, JQAccountMenuRow, JQFriendMiniRow, JQRequestMiniRow | ~333行 | 分割済み |

---

## 各画面の現状

### Home（実装済み・動作確認未実施）
- トップバー: **「ピクトリ」表示済み**（Step 3-G 完了）
- Hero カード: **「地図でスポットを探す」Map導線強化済み**（Step 3-H）/ 撮るボタン / **スポット進捗を実データ反映済み**（0件時・達成時で文言切替）
- 最近のシェア: フィードポスト一覧（モックデータ）/ **空状態は Map-first 文言・アイコンに更新済み**
- 最近埋まった場所: メモリーグリッド（実データ反映済み）
- アカウントシート: Home 右上から `JQAccountSheetView` をシートで表示
- 未改善: 「最近のシェア」「最近埋まった場所」のセクション名

### Map（実装済み・MapView.swift 分割済み・動作確認未実施）
- **`MapView.swift` に分割済み**（Step 1-B-4 完了）
- 神奈川のみ表示（他県は未実装）
- `QuestMapKitView` で MapKit レンダリング
- スポットタップ → `QuestSpotDetailView` へ NavigationStack で遷移
- スポット詳細からカメラ画面へ遷移可能
- `developerUnlockMode = true` のため、GPS に関わらずアンロック状態

### Camera（実装済み・動作確認未実施）
- 内カメ → 外カメの2枚連続撮影フロー（`QuestDualCapturePhase`）
- `developerUnlockMode = true` のため、現地にいなくても撮影可能
- `QuestDemoPhotoMaker`（カラーパネル生成）と `QuestDualPhotoComposer`（合成）が内蔵
- 保存後に `QuestMemoryStore` へ追加され、Memories タブに反映される
- 画面内に開発者モード Toggle が表示されている（line 1843）

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

| フロー | 状態 |
|-------|------|
| Home → Map タブ遷移 | 未確認 |
| Map でスポット選択 | 未確認 |
| Map → Camera へ activeCameraSpotId を渡す | 未確認 |
| Camera で2枚撮影 → 保存 | 未確認 |
| 保存後に Memories に反映 | 未確認 |
| Home フィードにポストが表示 | 未確認 |
| Account シートの開閉 | 未確認 |

---

## 既知の課題

### App Store 提出前に必須の修正
1. **`developerUnlockMode` デフォルトが `true`**
   - `QuestSpotDetailView`（line 1280）と `QuestCameraView`（line 1549）の両方で `@AppStorage("developerUnlockMode") private var developerUnlockMode = true`
   - ユーザーが現地にいなくてもスポットをアンロック・撮影できてしまう
   - デフォルトを `false` に変更し、開発者向けトグルは隠す必要がある

2. **カメラ権限なしの場合のフォールバック未確認**
   - AVFoundation のエラーハンドリングが十分かは未確認

### コードの課題
3. **旧モデル型が QuestModels.swift に残存**
   - `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot` は View からは参照されていないが、`QuestSampleData.swift` 内でのみ使われている（`mockRecentPosts` 等）
   - `mockRecentPosts` / `mockKanagawaSpots` 等の定数が View から使われているか未確認
   - 未使用なら Models + SampleData から削除可能

4. **Map は神奈川のみ**
   - 他県のスポットデータは `mockQuestSpots` に含まれているが、Map 画面は `kanagawa` フィルタのみ

5. **ContentView.swift が 1231 行**
   - Camera（~1043行）が未分割（Home+JQAccount は HomeView.swift 分割済み、Map は MapView.swift 分割済み）
