# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-06-05（docs 整理）

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

---

## 次の候補タスク

### 候補 A — Memories 画面の UI 改善（★最推奨）

**目的:** 保存した写真が「旅の記録」として感じられる画面にする。現状は構造はあるが、写真が増えたときの見え方・達成感の表現が薄い。

**変更対象:** `MemoriesView.swift` のみ

**変更候補（着手前に現状調査して決定）:**
- 県別サマリーカードのビジュアル改善
- 撮影済みスポットカードの情報階層整理（写真・スポット名・日付）
- 空状態メッセージの改善（Map 導線への誘導）
- 黒白基調・余白・高級感の強化

**リスク:** 低〜中（`MemoriesView.swift` 1ファイル内。`QuestMemoryStore` のロジックには触らない）

**ユーザーに見える変化:** 撮影後に Memories を見たときの満足感が向上する

**コミットメッセージ案:**
```
Improve memories view layout and visual quality
```

---

### 候補 B — 旧モデル・旧サンプルデータ削除

**目的:** `QuestModels.swift` と `QuestSampleData.swift` に残る未使用コードを削除してコードベースをクリーンにする。

**変更対象:** `QuestModels.swift` / `QuestSampleData.swift`

**削除候補:**
- `QuestModels.swift`: `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot`
- `QuestSampleData.swift`: `mockRecentPosts` / `mockPrefectures` / `mockKanagawaSpots` / `mockMapDots` / `mockKanagawaDots`

**必須手順:** `grep -rn` で全 Swift ファイルから参照ゼロを確認してから削除

**リスク:** 低（事前確認で 0 参照を確認してから削除）

**ユーザーに見える変化:** なし（コード整理のみ）

**コミットメッセージ案:**
```
Remove unused legacy model types and sample data
```

---

### 候補 C — コアフロー実機テスト確認

**目的:** Step 3-E でコード上の接続は確認済みだが、実機での end-to-end 動作がまだ未確認。App Store 提出前に必須。

**変更対象:** なし（実機テストのみ。Swift コード変更なし）

**確認すべき項目:**
1. Map でスポットタップ → `QuestSpotDetailView` が開く
2. `heroStatusChip` が正しい状態を表示（未撮影 / 撮影済み）
3. 現地（または `developerUnlockMode = true`）で「この場所で撮る」ボタンが押せる
4. Camera 画面に遷移し、spotId が正しく渡る
5. 2枚撮影 → 保存 → 「Memoriesで確認する」CTA が表示される
6. Memories タブで撮影した写真が反映されている
7. Home の Hero カードのスポット進捗が更新されている

**リスク:** なし

**ユーザーに見える変化:** なし（品質保証のみ）

---

## その他の候補（いつでも実施可）

### Step 3-C — Home セクション名の改善

**変更対象:** `HomeView.swift` のみ（Text 2行）
- 「最近のシェア」→「フレンドの記録」
- 「最近埋まった場所」→「保存した場所」

**リスク:** 最低（Text 変更2行のみ）

**コミットメッセージ案:**
```
Update home section labels to reflect journey context
```

### Step 1-B-6 — SharedComponents.swift 分割

**変更対象:** `ContentView.swift`（`AppBackground` / `JQUI` / `JQFloatingTabBar` / `JQFloatingTabItem` / `AppTab` を新ファイルへ移動）

**目的:** `ContentView.swift` を root coordinator のみ（目標 ~60行）にする

**リスク:** 低〜中（`AppTab` は全 View が参照。移動後ビルド確認が必須）

**コミットメッセージ案:**
```
Extract shared UI components into SharedComponents.swift
```
