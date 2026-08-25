# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-08-22（Visual Direction Consolidation 完了）

> **プロダクト名:** PicTri — UI 上の表示名。内部プロジェクト名 JapanQuest はコード・Xcode 設定に残存中。

---

## 2026-08-22 夜間セッション後の次の候補タスク

- **Camera Aperture Iris Openingの修正**: `PictriOpeningLabConcepts.swift`の
  `PictriOpeningConceptC_ApertureIris.bladeShape`にジオメトリバグあり(外周コーナー計算が
  誤っており巨大な棘状に破綻する)。着想としては3案中最もPicTri適合度が高いため、
  修正できれば次点候補として再評価する価値がある。
- **Home Memory Flip統合の実写真QA**: 今夜`QuestMemoryStore`に追加した
  `outerOnlyImage(for post:)`/`selfieImage(for post:)`と、`HomeFeedPostRow`側の
  flip統合(`flipBackImage`/`photoLayer`)は、実際にdual capture写真を撮影した状態での
  目視確認がまだ。Simulatorで一度Camera撮影を実施し、Homeで裏返る挙動を確認する。
- **developerUnlockModeのデフォルト値確認**: CLAUDE.md記載のルール通り、
  App Store提出前に`false`へ変更されているか要再確認。
- **今夜の変更のコミット**: ユーザー指示によりコミットはしていない。差分をレビューの上、
  意味のある単位に分けてコミットする。

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
- ~~候補 A — Camera 文言修正・cameraBootView 削除: 「保存してシェア」→「メモリーに保存」, Memoriesで→メモリーで, 未使用コード削除~~ → 完了
- ~~Home Social Layer Stage 1: いいね・コメントUI・プロフィールSheet・投稿詳細依存排除・「保存した場所」セクション削除~~ → `9d8c2ea` / `2353c6e` 完了
- ~~Home Social Layer Stage 2: いいね footer 移動・like count・daysLeftText 削除・EmptyFeedCard コピー修正・FriendProfileSheet モック除去・JQAccountMenuRow chevron 削除~~ → `465efa8` 完了
- ~~Memories Explore Stage 4: ExplorePhotoDetailSheet 品質強化（グラデーション stop 改善・caption fade-in・fallback アイコン・close button・「コレクトで見る」導線）~~ → `2441295` 完了

---

## 次の候補タスク

---

### 候補 A — Home / Memories 実機 QA

**目的:** 実装が進んだ Home フィード・Memories Explore・Account シートを実機で動作確認し、未確認フローを埋める。コード変更は不要。

**変更対象:** なし（実機確認のみ）

**確認すべきポイント:**
- Home フィードにモック投稿が表示されるか
- いいね・コメントが正しく動くか
- Explore カードタップ → 詳細シート → 「コレクトで見る」の流れが壊れていないか
- Account シートの開閉・フレンド追加が動くか

**ユーザーに見える変化:** なし（品質担保のみ）

**リスク:** なし

**ピクトリ独自性:** 直接貢献しないが、体験の破綻を未然に防ぐ。

**推奨度:** ★★★（コード変更なしで品質を上げられる。次の実装前に実施を強く推奨）

---

### 候補 B — 旧モデル・旧サンプルデータ削除

**目的:** `QuestModels.swift` と `QuestSampleData.swift` に残る未使用コードを削除し、コードベースをクリーンにする。

**変更対象:** `QuestModels.swift` / `QuestSampleData.swift`
- 削除候補: `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot`
- 削除候補: `mockRecentPosts` / `mockPrefectures` / `mockKanagawaSpots` / `mockMapDots` / `mockKanagawaDots`
- 必須手順: `grep -rn` で全 Swift ファイルから参照ゼロを確認してから削除

**ユーザーに見える変化:** なし（コード整理のみ）

**リスク:** 低（参照ゼロ確認後に削除すれば安全）

**ピクトリ独自性:** 直接貢献しない（内部品質向上）

**推奨度:** ★★（実機 QA の後、次の機能実装前に済ませておくと安全）

---

### 候補 C — Camera / Map 細部レビュー

**目的:** Camera 保存フロー・Map SpotDetail の細部体験を見直す。特に「撮影後の達成感」と「スポット詳細からCamera起動の流れ」に磨く余地がある。

**変更対象:** `CameraView.swift` または `MapView.swift`（1ファイルずつ）

**改善候補の例:**
- Camera 保存後の「メモリーで確認する」CTA のサイズ・余白
- SpotDetailView の写真プレビューが空の場合の見え方
- SpotDetail → Camera 起動の中間状態（ローディング感など）

**ユーザーに見える変化:** 撮影後の手応え・スポット詳細の完成度が上がる

**リスク:** 低〜中（Map と Camera はコアフロー本線。変更は慎重に1箇所ずつ）

**ピクトリ独自性:** 高。「地図で見つける → 現地で撮る」の体験価値が直接上がる。

**推奨度:** ★★（実機 QA 後に進むと判断しやすい。急ぎではないが価値は高い）

---

### 候補 D — Memories 空間 UI の設計検討（実装なし）

**目的:** Explore Stage 5 に向けた「写真が時空間に浮かぶ」UI のコンセプトと技術的アプローチを整理する。今回は設計と方針決定のみ、コード変更は行わない。

**変更対象:** なし（設計・議論のみ）

**検討内容:**
- カルーセルを脱した 2D / 3D 配置の方向性
- `SwiftUI ScrollView` vs `UICollectionView` のトレードオフ
- `MemoriesView.swift` の分割が前提になるかどうか
- ピクトリらしい「旅の記憶が育つ空間」の定義

**ユーザーに見える変化:** なし（設計フェーズ）

**リスク:** なし（設計のみ）

**ピクトリ独自性:** 最高。Memories が「世界にないアルバム体験」になる基盤設計。

**推奨度:** ★★（A / B の後、次の大きな方向性を決めるフェーズとして価値が高い）

---

## その他の候補（いつでも実施可）

### Step 1-B-6 — SharedComponents.swift 分割
`ContentView.swift` を root coordinator のみ（~60行）にする。`AppTab` / `JQUI` / `JQFloatingTabBar` 等を新ファイルへ移動。リスク低、UIへの影響なし。

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
| Stage 4 | 詳細シート品質強化（グラデーション stop・caption fade-in・fallback アイコン・close button・「コレクトで見る」導線） | `2441295` |
| Stage 5（将来） | 本格的な 2D / 3D 空間配置。別ファイル分離推奨 | 未実装 |
