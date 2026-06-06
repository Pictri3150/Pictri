# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-06-07（Memories Explore Stage 2 完了）

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

---

## 次の候補タスク

### 候補 A — Memories Explore モード 最小実装（★最推奨）

**目的:** 固定グリッド（Collectモード）を残しつつ、撮影済み写真を空間的に並べて眺められる Explore モードを追加する。「埋める楽しさ」と「旅を振り返る静けさ」を両立させる。

**変更対象:** `MemoriesView.swift` のみ（詳細は下の設計セクションを参照）

**最小実装スコープ（Stage 1）:**
- ヘッダー右上にモード切替ボタン（Collect / Explore）を追加
- Explore モードでは `memoryStore.memoryPhotos` を元に撮影済み写真を横スクロールカルーセルで表示
- 中央写真を大きく、両端を小さくする `scaleEffect`（GeometryReader 使用）

**リスク:** 低〜中（`MemoriesView.swift` 1ファイル内。Store / Model 変更なし）

**ユーザーに見える変化:** 撮影した写真を「旅のアルバム」として眺める体験が生まれる

**コミットメッセージ案:**
```
Add explore mode to memories view
```

---

### 候補 B — 旧モデル・旧サンプルデータ削除

**目的:** `QuestModels.swift` と `QuestSampleData.swift` に残る未使用コードを削除してコードベースをクリーンにする。

**変更対象:** `QuestModels.swift` / `QuestSampleData.swift`

**削除候補:**
- `QuestModels.swift`: `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot`
- `QuestSampleData.swift`: `mockRecentPosts` / `mockPrefectures` / `mockKanagawaSpots` / `mockMapDots` / `mockKanagawaDots`

**必須手順:** `grep -rn` で全 Swift ファイルから参照ゼロを確認してから削除

**リスク:** 低

**ユーザーに見える変化:** なし（コード整理のみ）

**コミットメッセージ案:**
```
Remove unused legacy model types and sample data
```

---

### 候補 C — コアフロー実機テスト確認

**目的:** コード上の接続は確認済みだが、実機での end-to-end 動作がまだ未確認。App Store 提出前に必須。

**変更対象:** なし（実機テストのみ）

**確認すべき項目:**
1. Map でスポットタップ → SpotDetailView が開く
2. `heroStatusChip` が正しい状態を表示
3. 現地（または `developerUnlockMode = true`）で「この場所で撮る」が押せる
4. Camera 遷移 → 2枚撮影 → 保存 → Memories に反映
5. Home のスポット進捗が更新される

**リスク:** なし

---

## その他の候補（いつでも実施可）

### Step 3-C — Home セクション名の改善
`HomeView.swift` のみ（Text 2行）— 「最近のシェア」→「フレンドの記録」 / 「最近埋まった場所」→「保存した場所」

### Step 1-B-6 — SharedComponents.swift 分割
`ContentView.swift` を root coordinator のみ（~60行）にする。`AppTab` / `JQUI` / `JQFloatingTabBar` 等を新ファイルへ移動。

---

## Memories 次フェーズ設計: Collect + Explore 2モード構成

### 1. 現在の MemoriesView.swift の役割

| 型 | 役割 |
|---|-----|
| `MemoriesView` | ヘッダー / 県チップ / 県カード一覧（現在これが Collect モード全体） |
| `PrefectureMemorySummaryCard` | 県ごとのサマリーカード（5枚プレビュータイル + 進捗） |
| `PrefecturePreviewTile` | サマリー内の小タイル（実写真サムネイル表示済み） |
| `PrefectureMemoryDetailView` | 県詳細画面（3列グリッド） |
| `FixedMemorySpotCell` | 撮影済み / 未撮影スポットのグリッドセル |
| `FixedEmptySpotCell` | スポット枠のプレースホルダー |
| `MemoryVisualStyle` | スポット別カラーグラデーション定義 |

---

### 2. Collect モードとして残すべきもの（変更禁止）

- **県別フィルタ**: `prefectureChips` による切り替え
- **固定グリッド枠**: 全スポット数分のセルが常に表示される（撮影していない枠は空）
- **未訪問プレースホルダー**: `FixedEmptySpotCell` と `mappin` アイコン
- **撮影済みセルで埋まる体験**: 撮るたびにセルが写真で埋まっていく達成感
- **進捗表示**: "X / 24 スポット" カウント

この体験がピクトリの「行った場所だけが見える」コア価値。絶対に削除しない。

---

### 3. Explore モードとして追加したいもの

**コンセプト:** 撮影済み写真だけを「旅の記録」として空間的に並べ、静かに眺めるモード。スタンプ収集ではなく、アルバムを開く感覚。

**UI イメージ:**
```
← [スポット名A] [スポット名B★中央・大] [スポット名C] →
                      ↑ 大きく表示
```
- 中央写真: 大きく（例: `.scaleEffect(1.0)`）
- 両端: 少し小さく（例: `.scaleEffect(0.82)`）
- ドラッグ / スワイプで移動
- 写真がない場合は表示しない（Collect と違い、撮影済みのみ）
- タップで県詳細 or 写真単体の拡大詳細へ

**データソース:** `memoryStore.memoryPhotos`（既存）+ `memoryStore.image(for: spot)`（既存）

---

### 4. 最初に実装する最小安全タスク（Stage 1）

`MemoriesView.swift` のみで完結する最小実装:

1. `@State private var viewMode: MemoriesViewMode = .collect` を追加
2. `enum MemoriesViewMode { case collect, explore }` を追加
3. ヘッダー右上にモード切替ボタンを追加（テキストまたは SF Symbol）
4. `exploreCarousel` computed var を新規追加:
   - `memoryStore.memoryPhotos` から spotId ごとに写真を列挙
   - `ScrollView(.horizontal)` + `HStack` で横スクロール
   - `GeometryReader` で中央からの距離を計算し `.scaleEffect` を適用
5. `body` で `viewMode == .collect ? collectBody : exploreBody` に切り替え

既存の Collect モードは一切変更しない。Explore モードを分岐として追加するだけ。

---

### 5. MemoriesView.swift だけで実装できる範囲

| 機能 | MemoriesView.swift のみで可能か |
|-----|-------------------------------|
| モード切替 State / enum 追加 | ✅ 可能 |
| 横スクロールカルーセル | ✅ 可能 |
| GeometryReader による中央スケール | ✅ 可能（SwiftUI 標準） |
| 写真の読み込み（`memoryStore.image`） | ✅ 可能（既存 API） |
| タップで PrefectureMemoryDetailView へ | ✅ 可能（既存 NavigationLink 活用） |
| 本格的な 2D 空間配置（Watch ホーム風） | ❌ 複雑。別ファイル分離が望ましい |

---

### 6. Store / Model 変更が必要になる可能性

**基本実装（Stage 1〜3）では変更不要:**
- `memoryStore.memoryPhotos: [QuestMemoryPhoto]` — 保存済み写真のリスト（既存）
- `memoryStore.image(for: spot) -> UIImage?` — 実際の写真（既存）

**拡張時に検討が必要になる可能性:**
- 写真に撮影日時（timestamp）を付けてソートしたい場合 → `QuestMemoryPhoto` に `savedAt: Date` フィールド追加が必要（現在は不明）
- 写真のメタデータ（スポット名・撮影日）をオーバーレイ表示したい場合 → `QuestMemoryPhoto.spotId` から `mockQuestSpots` を引けば対応可能（Model 変更不要）

---

### 7. 実装ステップ（3〜5段階）

| Stage | 内容 | 対象ファイル | リスク |
|-------|-----|------------|--------|
| **Stage 1** | モード切替ボタン + 基本横スクロールカルーセル | `MemoriesView.swift` のみ | 低 |
| **Stage 2** | GeometryReader による中央スケール演出 | `MemoriesView.swift` のみ | 低〜中 |
| **Stage 3** | タップで写真拡大詳細 or 県詳細へ遷移 | `MemoriesView.swift` のみ | 低 |
| **Stage 4** | アニメーション・snap scroll 調整 | `MemoriesView.swift` のみ | 中 |
| **Stage 5** | 本格的な 2D 空間配置（Watch 風） | 新ファイル分離推奨 | 高 |

Stage 1〜4 は `MemoriesView.swift` 1ファイルで完結可能。Stage 5 は設計上の複雑度が上がるため、必要になったときに判断する。
