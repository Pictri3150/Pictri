# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-06-07（Memories Explore 日付フォーマット改善 完了）

> **プロダクト名:** ピクトリ（Pictri）— UI 上の表示名。内部プロジェクト名 JapanQuest はコード・Xcode 設定に残存中。

---

## 完了済みタスク

- ~~Step 1-A: レガシーファイル削除~~ → 完了
- ~~Step 1-B-1: MemoriesView.swift 分割~~ → 完了
- ~~Step 1-B-2: 旧 Account 系 死にコード削除~~ → 完了
- ~~Step 1-B-3: CameraView.swift 分割~~ → `4d6e29b` 完了
- ~~Step 1-B-4: MapView.swift 分割~~ → `fab79d6` 完了
- ~~Step 1-B-5: HomeView.swift 分割~~ → `74c68f6` 完了
- ~~Step 2-A: developerUnlockMode デフォルト false 化~~ → `7232f65` 完了
- ~~Step 3-A: Home Hero カードにスポット進捗を実データ反映~~ → 完了
- ~~Step 3-B: EmptyFeedCard を Map-first な空状態に改善~~ → 完了
- ~~Step 3-E: コアフロー確認（コード上）~~ → 完了（実機確認は別途必要）
- ~~Step 3-F: Camera 保存フィードバック UI 改善~~ → `103f968` 完了
- ~~Step 3-G: UI 表示名を「ピクトリ」に変更~~ → `ce2df41` 完了
- ~~Step 3-H: Home Hero カードの Map 導線改善~~ → `43e9fca` 完了
- ~~Step 3-I: Home「気になるスポット」セクション追加~~ → `cc15bf9` 完了
- ~~Camera 保存後体験改善（primary CTA 格上げ）~~ → `f591d33` 完了
- ~~Step 3-D: QuestSpotDetailView の heroStatusChip を3-state 対応に~~ → `31831c4` 完了
- ~~Memories UI 改善: サマリータイルで実写真・ヘッダー文言・mappin アイコン~~ → `e09368a` 完了
- ~~候補 A — Memories Explore モード Stage 1: コレクト/探索切り替え・横スクロールカルーセル~~ → `dbb2b0c` 完了
- ~~Memories Explore Stage 2: スナップスクロール・カード影・垂直配置改善~~ → `6693d59` 完了
- ~~Memories Explore 日付フォーマット改善: `formattedDate` で `"M月d日"` 表示~~ → `730e530` 完了

---

## 次の候補タスク

### 候補 A — Memories Explore Stage 3: カードタップ時の詳細/拡大体験

**目的:** Explore カードに触れても何も起きない「死んだUI」状態を解消。旅の記録を深掘りできる体験へ。

**変更対象:** `MemoriesView.swift` のみ
- `ExplorePhotoCard` を `NavigationLink` で包み、既存の `PrefectureMemoryDetailView` へ遷移
- または `.sheet` でカード内写真のフルスクリーン表示（新 View 追加が必要）

**ユーザーに見える変化:** カードをタップ → 県の固定グリッド詳細へ遷移できる。「旅を深掘りする」体験が生まれる。

**リスク:** 低（`NavigationLink` + 既存 `PrefectureMemoryDetailView` の活用なら数行）〜中（フルスクリーン新 View を作る場合）

**ピクトリ独自性:** 中。「旅の記録を選んで深掘りできる」ことで Collect と Explore の連携が生まれる。

**推奨度:** ★★★（Explore モードの自然な次ステップ）

---

### 候補 B — Memories Collect 側の達成感強化

**目的:** 「撮るたびにグリッドが埋まる」体験をより視覚的に強くする。県コンプリート時や一定枚数達成時に何かが変わる感覚を追加。

**変更対象:** `MemoriesView.swift`（`PrefectureMemorySummaryCard` 周辺）
- `completedCount == prefecture.totalSpotCount` 時にカードの見た目を変える（例: ボーダー強調・バッジ表示）
- 「達成率バー」または「残り N スポット」テキストの追加

**ユーザーに見える変化:** 県を撮り切ったカードが特別な見た目になる。コンプリートの達成感が視覚化される。

**リスク:** 低（既存 `completedCount` と `totalSpotCount` を使うだけ。Store / Model 変更不要）

**ピクトリ独自性:** 高。「行った場所だけが埋まる」がピクトリのコア価値。その達成感の強化は直接プロダクト価値に効く。

**推奨度:** ★★★★（Collect がコア体験なので強化インパクトが大きい）

---

### 候補 C — コアフロー実機テスト確認

**目的:** コード上の接続は確認済みだが、実機での end-to-end 動作が未確認。App Store 提出前に必須。

**変更対象:** なし（実機テストのみ）

**確認すべき項目:**
1. Map でスポットタップ → SpotDetailView が開く
2. `heroStatusChip` が正しい状態を表示
3. 現地（または `developerUnlockMode = true`）で「この場所で撮る」が押せる
4. Camera 遷移 → 2枚撮影 → 保存 → Memories に反映
5. Home のスポット進捗が更新される

**ユーザーに見える変化:** なし（品質保証）

**リスク:** なし（実機テストのみ）

**ピクトリ独自性:** 間接的。コアフローが壊れていないことを確認し、提出品質を担保する。

**推奨度:** ★★（提出前に必須。今すぐでなくてもよいが先送り厳禁）

---

### 候補 D — 旧モデル・旧サンプルデータ削除

**目的:** `QuestModels.swift` と `QuestSampleData.swift` に残る未使用コードを削除してコードベースをクリーンにする。

**変更対象:** `QuestModels.swift` / `QuestSampleData.swift`
- 削除候補: `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot`
- 削除候補: `mockRecentPosts` / `mockPrefectures` / `mockKanagawaSpots` / `mockMapDots` / `mockKanagawaDots`
- 必須手順: `grep -rn` で全 Swift ファイルから参照ゼロを確認してから削除

**ユーザーに見える変化:** なし（コード整理のみ）

**リスク:** 低（参照ゼロを確認してから削除すれば安全）

**ピクトリ独自性:** 直接貢献しない（内部品質向上）

**推奨度:** ★（いつでも可。今は不急）

---

## その他の候補（いつでも実施可）

### Step 3-C — Home セクション名の改善
`HomeView.swift` のみ（Text 2行）— 「最近のシェア」→「フレンドの記録」 / 「最近埋まった場所」→「保存した場所」

### Step 1-B-6 — SharedComponents.swift 分割
`ContentView.swift` を root coordinator のみ（~60行）にする。`AppTab` / `JQUI` / `JQFloatingTabBar` 等を新ファイルへ移動。

---

## Memories モード構成（現在の実装状態）

### Collect モード（完成済み・変更禁止）

| 型 | 役割 | 状態 |
|---|-----|------|
| `MemoriesView.collectBody` | ヘッダー / 県チップ / 県カード一覧 | ✅ 完成 |
| `PrefectureMemorySummaryCard` | 県ごとサマリーカード（5枚タイル + 進捗） | ✅ 完成 |
| `PrefecturePreviewTile` | サムネイル表示タイル | ✅ 完成 |
| `PrefectureMemoryDetailView` | 県詳細（3列固定グリッド） | ✅ 完成 |
| `FixedMemorySpotCell` | 撮影済み / 未撮影グリッドセル | ✅ 完成 |
| `FixedEmptySpotCell` | 未訪問プレースホルダー | ✅ 完成 |

**絶対に壊さないもの:** 固定グリッド枠・未訪問プレースホルダー・進捗カウント・gridIndex によるソート

### Explore モード（Stage 1/2/日付改善 完了）

| Stage | 内容 | コミット |
|-------|-----|---------|
| Stage 1 | モード切替・横スクロールカルーセル・ExplorePhotoCard | `dbb2b0c` |
| Stage 2 | スナップスクロール・カード影・垂直配置 | `6693d59` |
| 日付改善 | `formattedDate`（`"M月d日"` 表示） | `730e530` |
| Stage 3 | タップで詳細遷移 | 未実装 |
| Stage 4（将来） | 本格的な 2D 空間配置 | 別ファイル分離推奨 |
