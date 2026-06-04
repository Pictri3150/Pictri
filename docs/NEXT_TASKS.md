# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-06-05（Step 3-F 完了・Step 2-A 次の推奨に更新）

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

---

## 推奨作業順序の概要

```
Phase 2: App Store 必須修正
  Step 2-A    developerUnlockMode デフォルト false 化（★次の推奨、前提条件 完了済み）

Phase 3: 体験品質の改善（継続中）
  Step 3-D    Map スポット詳細 UX 改善（いつでも可）
  Step 3-C    Home セクション名の改善（いつでも可）

Phase 1: コード整理（継続）
  Step 1-B-6  SharedComponents.swift 分割（いつでも可）
  Step 1-B-7  旧モデル・旧サンプルデータ 削除（いつでも可）
```

---

## Phase 3: 体験品質の改善（継続）

### ~~Step 3-F: Camera 保存フィードバック UI の改善~~（完了）

- 保存済みボタン背景 `.green` → `.white.opacity(0.14)`（黒白基調に統一）
- `hasSaved = true` を `withAnimation` でラップ
- 保存後「Memoriesで確認する」ボタン追加（`selectedTab = .memories`）
- ヒントテキスト「Memoriesに保存しました」に切り替え
- コミット: `103f968`

---

### Step 3-D: Map スポット詳細 UX 改善

**目的:** `QuestSpotDetailView` の体験を強化し、「このスポットに行って写真を残したい」と思わせる画面にする

**前提条件:** Step 1-B-4（MapView.swift 分割）完了済み

**変更対象:** `MapView.swift` のみ（`QuestSpotDetailView` 内）

**候補:**
- スポット詳細ヒーロー画像エリアのビジュアル強化
- 「撮影済み」バッジの視認性改善
- 「この場所で撮る」ボタンの視認性・文言改善
- 場所の説明や距離感を伝えるテキスト追加（Store/Model の追加なしで可能な範囲）

**リスク:** 低〜中（`MapView.swift` 1ファイル内、MapKit には触らない）

**Definition of Done:**
- `QuestSpotDetailView` がより魅力的になっている
- 「この場所で撮る」導線が明確
- 変更は `MapView.swift` のみ
- Build Succeeded

**コミットメッセージ案:**
```
Improve spot detail view on map screen
```

---

### Step 3-C: Home セクション名の改善

**目的:** 「最近のシェア」「最近埋まった場所」という文言が SNS 的・スタンプラリー的に見える問題を解消し、ピクトリらしい「旅の記録」「場所の発見」に寄せる

**変更対象（HomeView.swift のみ）:**
- `recentShareSection` 見出し: 「最近のシェア」→「フレンドの記録」（または「最近の記録」）
- `recentMemorySection` 見出し: 「最近埋まった場所」→「最近の記録」（または「保存した場所」）

**リスク:** 最低（Text 2行の変更のみ）

**Definition of Done:**
- 2箇所のセクション見出しが更新されている
- レイアウト崩れなし
- Build Succeeded

**コミットメッセージ案:**
```
Update home section labels to reflect journey context
```

---

## Phase 2: App Store 必須修正

### Step 2-A: developerUnlockMode デフォルト変更（★次の推奨）

**目的:** App Store 提出時に、ユーザーが現地にいなくてもスポットをアンロックできる状態を解消する

**前提条件:** Step 1-B-3（CameraView.swift 分割）と Step 1-B-4（MapView.swift 分割）**両方完了済み** — 今すぐ実施可能

**変更内容:**
- `QuestSpotDetailView`（`MapView.swift`）: `developerUnlockMode = true` → `false`
- `QuestCameraView`（`CameraView.swift`）: `developerUnlockMode = true` → `false`
- 開発者向けトグル UI は残す（`#if DEBUG` 内）

**リスク:** 中
- 変更後、実機で GPS が正常に動作していないとスポットをアンロックできなくなる
- シミュレーターでは位置情報のシミュレーションが必要

**Definition of Done:**
- 両ファイルで `developerUnlockMode` のデフォルトが `false`
- 実機または位置シミュレーターでスポット近くでアンロックされることを確認
- Build Succeeded

**コミットメッセージ案:**
```
Disable developer unlock mode by default
```

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

### Step 1-B-7: 旧モデル・旧サンプルデータ 削除

**目的:** `QuestModels.swift` と `QuestSampleData.swift` に残る View から参照されていないモデルと定数を削除してコードベースをクリーンにする

**削除候補（要精査）:**

`QuestModels.swift` 内:
- `RecentQuestPost` / `PrefectureMemory` / `MemorySpot` / `MapDot` / `KanagawaDot`

`QuestSampleData.swift` 内:
- `mockRecentPosts` / `mockPrefectures` / `mockKanagawaSpots` / `mockMapDots` / `mockKanagawaDots`

**作業前の必須確認:** 削除前に `grep -rn` で全 Swift ファイルから参照されていないことを確認する

**リスク:** 低（事前確認で0参照を確認してから削除）

**Definition of Done:**
- 対象型・定数が0参照であることを確認済み
- 削除後 Build Succeeded

**コミットメッセージ案:**
```
Remove unused legacy model types and sample data
```

---

## Phase 3: 体験品質の改善（完了済み）

### ~~Step 3-E: コアフロー確認~~（完了・Swift変更なし）

**結果:**
- 全ステップがコード上正しく接続されていることを確認（破損なし）
- **実機確認が別途必要な項目:** コアフロー5ステップ / Home フィードへのポスト表示 / Account シートの開閉

---

## タスク間の依存関係

```
2-A (developerUnlockMode) ← ★次の推奨
  ← 1-B-3 / 1-B-4 / 3-F 完了済み → 今すぐ実施可能

3-D (Map スポット詳細 UX 改善)
  ← 1-B-4 完了済みのため今すぐ可能

3-C (Homeセクション名)
  ← いつでも実施可能（独立）

1-B-6 (SharedComponents)
  ← 1-B-3 完了済み → 今すぐ実施可能

1-B-7 (旧モデル削除)
  ← いつでも実施可能（他タスクと独立）
```
