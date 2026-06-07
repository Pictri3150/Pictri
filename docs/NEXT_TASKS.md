# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-06-07（QuestSpotDetailView ダークテーマ統一 完了）

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
- ~~候補 B — Memories Collect 達成感強化: 進捗バー・達成テキスト・コンプリート演出~~ → `7b1e38b` 完了
- ~~候補 A — Memories Explore Stage 3: Exploreカードタップで `ExplorePhotoDetailSheet` 表示~~ → `4d5b257` 完了
- ~~候補 B — コアフロー実機テスト確認: Home / Map / Camera / Memories の end-to-end 動作~~ → 実機確認済み（コード変更なし）
- ~~候補 B — QuestSpotDetailView ダークテーマ統一: 白背景廃止・黒基調統一・セマンティックカラー4種追加~~ → `5a284a9` 完了

---

## 次の候補タスク

### 候補 A — Camera 画面の文言・保存体験改善

**目的:** UIレビューで判明した Camera 画面の具体的な問題を解消する。「保存してシェア」という事実と異なるラベルを修正し、保存完了後の体験をピクトリらしい記録の瞬間として磨く。

**変更対象:** `CameraView.swift` のみ（`previewActions` / `cameraBottomArea` 周辺）
- `「保存してシェア」→「メモリーに保存」`（実態はローカル保存のみでシェアしていない）
- × ボタンの遷移先を `selectedTab = .home` → `selectedTab = .map`（MapからCameraに来た流れに合わせる）
- 保存後の体験強化（`hasSaved` 後のフィードバックをより印象的に）
- 死にコード `cameraBootView` の削除

**ユーザーに見える変化:** 保存ボタンの文言が正確になる。× ボタンがMapへ戻るようになる。保存の瞬間がより印象的になる。

**リスク:** 低（`CameraView.swift` 内完結。保存ロジック・撮影ロジックは変更なし）

**ピクトリ独自性:** 中〜高。「現地で撮る → メモリーに残す」がコア体験。その文言が「シェア」だと別サービスに見える。

**推奨度:** ★★★★（事実誤認の文言修正は即対応すべき。リスクが最低で効果が高い）

---

### 候補 B — Home 画面の死んだUI / SNS感の整理

**目的:** UIレビューで判明した Home 画面の問題を整理する。タップしても何も起きないメモリータイル、空実装のボタン、SNSライクな「いいね/送る」、ハードコードされたユーザー名を段階的に改善する。

**変更対象:** `HomeView.swift` のみ

**優先改善項目:**
- `HomeMemoryTile` にタップ → Memories タブ遷移（現在は完全に死んだUI）
- Hero カードの「撮る」ボタン削除（Map経由なしにCameraへ飛ぶのはコアフロー逸脱）
- `HomeLargePostCard` の `displayDate` / `displayPlace` の `.monospaced` フォントをピクトリらしい表現へ

**ユーザーに見える変化:** メモリータイルがタップできるようになる。Hero カードがMap-firstの導線に集中する。

**リスク:** 低〜中（`HomeView.swift` 内完結。Store変更不要。「撮る」ボタン削除は慎重に）

**ピクトリ独自性:** 中〜高。「地図で見つける」が起点のアプリで、Home から直接 Camera への抜け道を消す。

**推奨度:** ★★★（候補 A の次。1項目ずつ安全に進める）

---

### 候補 C — Memories Explore Stage 4: 写真詳細シートの品質強化

**目的:** Stage 3 で実装した `ExplorePhotoDetailSheet` の体験品質を高める。現状は必要最低限の実装であり、「旅の記憶を開く」感覚をさらに磨く余地がある。

**変更対象:** `MemoriesView.swift` のみ（`ExplorePhotoDetailSheet` 周辺）
- 写真が未保存の場合のフォールバック表示の改善
- シートを開いた瞬間のフェードイン演出（`.transition` / `.animation`）
- 「この県のコレクトを見る」テキストリンク（Collect モードへの切替導線）

**ユーザーに見える変化:** 写真詳細シートの完成度が上がり、旅の記憶を開いた瞬間の没入感が強まる。

**リスク:** 低（`MemoriesView.swift` 内の `ExplorePhotoDetailSheet` のみ。Store / Model 変更不要）

**ピクトリ独自性:** 中〜高。「旅の記憶を開く」という唯一無二の体験を磨く。

**推奨度:** ★★★（Stage 3 の自然な仕上げ。A / B の後でも前でも進められる）

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
| `PrefectureMemorySummaryCard` | 県ごとサマリーカード（5枚タイル + 進捗バー + 達成テキスト） | ✅ 完成（`7b1e38b`） |
| `PrefecturePreviewTile` | サムネイル表示タイル | ✅ 完成 |
| `PrefectureMemoryDetailView` | 県詳細（3列固定グリッド） | ✅ 完成 |
| `FixedMemorySpotCell` | 撮影済み / 未撮影グリッドセル | ✅ 完成 |
| `FixedEmptySpotCell` | 未訪問プレースホルダー | ✅ 完成 |

**追加済みの達成感表現（`7b1e38b`）:** 進捗バー・「あと N スポット」/「コンプリート」テキスト・コンプリート時のビジュアル強調

**絶対に壊さないもの:** 固定グリッド枠・未訪問プレースホルダー・進捗カウント・gridIndex によるソート

### Explore モード（Stage 1/2/3 + 日付改善 完了）

| Stage | 内容 | コミット |
|-------|-----|---------|
| Stage 1 | モード切替・横スクロールカルーセル・ExplorePhotoCard | `dbb2b0c` |
| Stage 2 | スナップスクロール・カード影・垂直配置 | `6693d59` |
| 日付改善 | `formattedDate`（`"M月d日"` 表示） | `730e530` |
| Stage 3 | カードタップ → `ExplorePhotoDetailSheet`（写真全面・スポット名・エリア名・日付） | `4d5b257` |
| Stage 4（将来） | 詳細シート品質強化・本格的な 2D 空間配置 | 別ファイル分離推奨 |
