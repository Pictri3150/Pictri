# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-06-05（Step 3-D 完了 / Mapスポット詳細ステータス改善）

> **プロダクト名:** ピクトリ（Pictri）— UI 上の表示名。内部プロジェクト名 JapanQuest はコード・Xcode 設定に残存中。

---

## 完了済みタスク

- ~~Step 3-A: Home Hero カードを実データで動的に~~ → `ebfd099` 完了
- ~~Step 3-B: EmptyFeedCard を Map-first な空状態に改善~~ → `8ea9e0e` 完了
- ~~Step 3-G: UI 表示名を「ピクトリ」に変更~~ → `ce2df41` 完了
- ~~Step 1-B-5: HomeView.swift 分割（Home + JQAccount 系）~~ → `74c68f6` 完了
- ~~Step 3-H: Home Hero カードの Map 導線改善~~ → `43e9fca` 完了
- ~~Step 3-I: Home「気になるスポット」セクション追加・強化~~ → `651d464` / `cc15bf9` 完了
- ~~Step 1-B-4: MapView.swift 分割~~ → `fab79d6` 完了
- ~~Step 3-E: コアフロー確認~~ → コード調査完了・破損なし・Swift変更なし（実機完全確認は別途必要）
- ~~Step 1-B-3: CameraView.swift 分割~~ → `4d6e29b` 完了
- ~~Step 3-F: Camera 保存フィードバック UI 改善~~ → `103f968` 完了
- ~~Step 2-A: developerUnlockMode デフォルト false 化~~ → `7232f65` 完了
- ~~Camera 保存後体験改善（primary CTA 格上げ）~~ → `f591d33` 完了
- ~~Step 3-D: Mapスポット詳細ステータス改善（heroStatusChip 3-state 対応）~~ → `31831c4` 完了

---

## 推奨作業順序の概要

```
Phase 3: 体験品質の改善（継続中）
  候補 A    旧モデル・旧サンプルデータ削除（★次の推奨：出荷前整理）
  候補 B    Memories 画面の UI 改善（★体験向上）
  候補 C    コアフロー実機テスト確認（★品質保証）

Phase 3（低リスク小改善）
  Step 3-C  Home セクション名の改善（いつでも可・2行変更のみ）

Phase 1: コード整理（継続）
  Step 1-B-6  SharedComponents.swift 分割（いつでも可）
```

---

## Phase 3: 体験品質の改善（継続）

### 候補 A — Step 1-B-7: 旧モデル・旧サンプルデータ削除（★推奨度: 高）

**目的:** `QuestModels.swift` と `QuestSampleData.swift` に残る死んだコードを削除し、App Store 提出前のコードベースを清潔にする。

**変更対象:** `QuestModels.swift` / `QuestSampleData.swift`（grep 確認後に削除）

**削除候補:**
- `QuestModels.swift`: `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot`
- `QuestSampleData.swift`: `mockRecentPosts` / `mockPrefectures` / `mockKanagawaSpots` / `mockMapDots` / `mockKanagawaDots`

**必須手順:** `grep -rn` で全 Swift ファイルから参照ゼロを確認してから削除

**リスク:** 低（事前確認で0参照を確認してから削除。誤削除リスクは小）

**ユーザーに見える変化:** なし（コード整理のみ）。ただし将来の機能追加時の混乱を防ぐ。

**推奨度:** ★★★（出荷前の品質整理として必要。参照確認さえすれば安全）

**コミットメッセージ案:**
```
Remove unused legacy model types and sample data
```

---

### 候補 B — Memories 画面の UI 改善（★推奨度: 高）

**目的:** `MemoriesView.swift` の体験を強化し、撮影済みの記録が「旅のアルバム」として感じられる画面にする。現状は県別サマリーカードと詳細ビューは存在するが、写真が増えてきたときの見え方・達成感の表現が薄い。

**変更対象:** `MemoriesView.swift` のみ

**変更候補（着手前に現状調査して決定）:**
- 県別サマリーカードのヒーロービジュアル強化（撮影済み件数の見え方改善）
- 撮影済みスポット詳細カードのレイアウト改善（写真・スポット名・日付の情報階層整理）
- 空状態（まだ記録がない）のメッセージ改善（Map-first 導線への誘導）
- 「保存した記録」としての静けさ・高級感の強化

**リスク:** 低〜中（`MemoriesView.swift` 1ファイル内。`QuestMemoryStore` のロジックには触らない）

**ユーザーに見える変化:** 撮影後に「Memories」を見たときの満足感が上がる。記録が増えるほど「ここに来た」実感が得られる。

**推奨度:** ★★★（コアフロー後半の体験を直接改善。保存した写真が「見せたい記録」に見える）

**コミットメッセージ案:**
```
Improve memories view layout and visual quality
```

---

### 候補 C — コアフロー実機テスト確認（★推奨度: 高）

**目的:** Step 3-E でコード上の接続は確認済みだが、実機での end-to-end 動作（地図でスポット選択 → 現地撮影 → Memories 反映）がまだ未確認。App Store 提出前に必須。

**変更対象:** Swift コード変更なし。実機テストのチェックリスト確認のみ。

**確認すべき項目:**
1. Map でスポットをタップ → `QuestSpotDetailView` が開く
2. `heroStatusChip` が正しい状態を表示（未撮影 / 撮影済み）
3. 現地（または developerUnlockMode = true）で「この場所で撮る」ボタンが押せる
4. Camera 画面に遷移し、spotId が正しく渡る
5. 2枚撮影 → 保存 → 「Memoriesで確認する」CTA が表示される
6. Memories タブを開いて、撮影した写真が反映されている
7. Home の Hero カードのスポット進捗が更新されている

**リスク:** なし（コード変更なし。確認のみ）

**ユーザーに見える変化:** なし（品質保証のみ）。ただし App Store 提出判断に直接影響。

**推奨度:** ★★★（出荷前の必須確認。実機テスト未完了のまま提出できない）

**コミットメッセージ案:**
```
（コード変更なしのため、コミット不要）
```

---

### Step 3-C: Home セクション名の改善（低リスク小改善）

**目的:** 「最近のシェア」「最近埋まった場所」という SNS 的・スタンプラリー的な文言を、ピクトリらしい「旅の記録」「場所の発見」に寄せる。

**変更対象:** `HomeView.swift` のみ（Text 2行）
- `recentShareSection` 見出し: 「最近のシェア」→「フレンドの記録」
- `recentMemorySection` 見出し: 「最近埋まった場所」→「保存した場所」

**リスク:** 最低（Text 変更2行のみ。レイアウト・ロジック変更なし）

**ユーザーに見える変化:** ホーム画面のトーンが「ゲーム・SNS」→「旅の記録アプリ」に寄る。小さいが積み重ねで印象が変わる。

**推奨度:** ★★（低リスクで体験品質に効く。候補 A / B / C の前後どちらでも実施可）

**コミットメッセージ案:**
```
Update home section labels to reflect journey context
```

---

## Phase 2: App Store 必須修正

### ~~Step 2-A: developerUnlockMode デフォルト false 化~~（完了）

- `MapView.swift` / `CameraView.swift` 各1行: `= true` → `= false`
- 開発者向けトグルは `#if DEBUG` 内に残存
- コミット: `7232f65`

---

## Phase 1: コード整理（継続）

### ~~Step 1-B-3: CameraView.swift 分割~~（完了）

- `CameraView.swift` を新規作成（1043行）
- ContentView.swift: 1231行 → 186行（-1045行）
- 移動した型（4型）: `QuestCameraView` / `QuestDualCapturePhase` / `QuestDemoPhotoMaker` / `QuestDualPhotoComposer`
- コミット: `4d6e29b`

---

### Step 1-B-6: SharedComponents.swift 分割

**目的:** ContentView.swift を root coordinator のみ（目標 ~60行）にする

**対象型:**
- `AppBackground`
- `JQUI`（定数 enum）
- `JQFloatingTabBar`
- `JQFloatingTabItem`
- `AppTab`（enum）

**リスク:** 低〜中
- `AppTab` は全 View のタブ切り替えに使用される。移動後に全ファイルからアクセスできることを確認（同一モジュールなので問題ないはず）
- `JQUI` の定数は Map・Camera から参照されるため、移動後のビルドエラーに注意

**Definition of Done:**
- `SharedComponents.swift` が存在する
- `ContentView.swift` が 70行以下になっている
- Build Succeeded

**コミットメッセージ案:**
```
Extract shared UI components into SharedComponents.swift
```

---

## タスク間の依存関係

```
候補 A — 1-B-7 (旧モデル削除)
  ← いつでも実施可能（独立） ★推奨度: 高・出荷前整理

候補 B — Memories UI 改善
  ← いつでも実施可能（独立） ★推奨度: 高・体験向上

候補 C — コアフロー実機テスト
  ← Step 3-D 完了済み（現状の実装を確認できる）★推奨度: 高・品質保証

Step 3-C — Homeセクション名
  ← いつでも実施可能（独立） ★推奨度: 中・低リスク

1-B-6 (SharedComponents)
  ← 1-B-3 完了済み → いつでも可能（優先度は他より低い）
```
