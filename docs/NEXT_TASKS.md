# NEXT_TASKS.md — ピクトリ（Pictri）次のタスク一覧

最終更新: 2026-06-04

> **プロダクト名:** ピクトリ（Pictri）— UI 上の表示名。内部プロジェクト名 JapanQuest はコード・Xcode 設定に残存中。

---

## 完了済みタスク（Phase 3 先行分）

- ~~Step 3-A: Home Hero カードを実データで動的に~~ → `ebfd099` 完了
- ~~Step 3-B: EmptyFeedCard を Map-first な空状態に改善~~ → `8ea9e0e` 完了
- ~~Step 3-G: UI 表示名を「ピクトリ」に変更~~ → `ce2df41` 完了
- ~~Step 1-B-5: HomeView.swift 分割（Home + JQAccount 系）~~ → `74c68f6` 完了
- ~~Step 3-H: Home Hero カードの Map 導線改善~~ → `43e9fca` 完了
- ~~Step 3-I: Home「気になるスポット」セクション追加・強化~~ → `651d464` / `cc15bf9` 完了
- ~~Step 1-B-4: MapView.swift 分割~~ → `fab79d6` 完了

---

## 推奨作業順序の概要

```
Phase 3: 体験品質の改善（継続中）
  Step 3-D    Map スポット詳細 UX 改善（★次の推奨、MapView.swift 分割済みのため今すぐ可）
  Step 3-E    コアフロー動作確認と修正（いつでも可）
  Step 3-C    Home セクション名の改善（いつでも可）
  Step 3-F    Camera 保存フィードバック UI（後回し）

Phase 1: コード整理（継続）
  Step 1-B-3  CameraView.swift 分割（後回し）
  Step 1-B-6  SharedComponents.swift 分割（後回し）
  Step 1-B-7  旧モデル・旧サンプルデータ 削除（後回し）

Phase 2: App Store 必須修正
  Step 2-A    developerUnlockMode をデフォルト false に変更
```

---

## Phase 3: 体験品質の改善（継続）

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

### Step 3-D: Map スポット詳細 UX 改善（★次の推奨）

**目的:** `QuestSpotDetailView` の体験を強化し、「このスポットに行って写真を残したい」と思わせる画面にする

**前提条件:** Step 1-B-4（MapView.swift 分割）**完了済み** — 今すぐ安全に着手可能

**変更対象:** `MapView.swift` のみ（`QuestSpotDetailView` 内）

**候補（着手前に現状調査してから決定）:**
- スポット詳細ヒーロー画像エリアのビジュアル強化
- 「撮影済み」バッジの視認性改善
- 「この場所で撮る」ボタンの視認性・文言改善
- 場所の説明や距離感を伝えるテキスト追加（Store/Model の追加なしで可能な範囲）

**リスク:** 低〜中（`MapView.swift` 1ファイル内、MapKit には触らない）

**Definition of Done:**
- `QuestSpotDetailView` がスマホで見てより魅力的になっている
- 「この場所で撮る」導線が明確になっている
- 変更は `MapView.swift` のみ
- Build Succeeded

**コミットメッセージ案:**
```
Improve spot detail view on map screen
```

---

## Phase 1: コード整理

### Step 1-B-3: CameraView.swift 分割

**目的:** ContentView.swift 最大のブロック（1043行）を分離し、後の Camera 改善を安全にする

**対象型:**
- `QuestCameraView`（メイン View）
- `QuestDualCapturePhase`（enum）
- `QuestDemoPhotoMaker`（enum）
- `QuestDualPhotoComposer`（enum）

**リスク:** 中〜高
- `QuestCameraView` は `@StateObject var cameraService = QuestCameraService()` をローカルで生成
- `@Binding var selectedTab` と `@Binding var selectedSpotId` を ContentView から受け取る
- `@AppStorage("developerUnlockMode")` を内部で参照
- AVFoundation + 大量の `@State` を保持するため、移動後のビルドエラーに注意

**作業手順:**
1. `CameraView.swift` を新規作成（`import SwiftUI` + `import AVFoundation`）
2. ContentView.swift から対象4型をコピー
3. ContentView.swift から対象行を削除
4. Build Succeeded を確認
5. git diff で追加行ゼロ・削除行一致を確認

**Definition of Done:**
- `CameraView.swift` が存在する
- ContentView.swift から対象4型が削除されている
- Build Succeeded
- git diff の変更が ContentView.swift（削除）と CameraView.swift（追加）のみ

**コミットメッセージ案:**
```
Extract CameraView and capture enums from ContentView
```

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
- `AppTab` は全 View のタブ切り替えに使用される。移動後に全ファイルからアクセスできることを確認する（同一モジュールなので問題ないはず）
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
- `RecentQuestPost` — View からの参照なし（要確認）
- `PrefectureMemory` — View からの参照なし（要確認）
- `MemorySpot` — View からの参照なし（要確認）
- `MapDot` — View からの参照なし（要確認）
- `KanagawaDot` — View からの参照なし（要確認）

`QuestSampleData.swift` 内:
- `mockRecentPosts` — View からの参照なし（要確認）
- `mockPrefectures` — View からの参照なし（要確認）
- `mockKanagawaSpots` — View からの参照なし（要確認）
- `mockMapDots` — View からの参照なし（要確認）
- `mockKanagawaDots` — View からの参照なし（要確認）

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

## Phase 2: App Store 必須修正

### Step 2-A: developerUnlockMode デフォルト変更

**目的:** App Store 提出時に、ユーザーが現地にいなくてもスポットをアンロックできる状態を解消する

**変更内容:**
- `QuestSpotDetailView`（`MapView.swift`）の `@AppStorage("developerUnlockMode") private var developerUnlockMode = true` を `false` に変更
- `QuestCameraView`（`ContentView.swift` → 分割後は `CameraView.swift`）の同設定を `false` に変更
- 開発者向けトグル UI は残す（隠しデバッグ機能として有用）

**前提条件:** Step 1-B-3（CameraView.swift 分割）と Step 1-B-4（MapView.swift 分割）が完了していること

**リスク:** 中
- 変更後、実機で GPS が正常に動作していないとスポットをアンロックできなくなる
- シミュレーターでは位置情報のシミュレーションが必要

**Definition of Done:**
- 両ファイルで `developerUnlockMode` のデフォルトが `false`
- 実機または位置シミュレーターでスポット近くに近づいたときにアンロックされることを確認
- Build Succeeded

**コミットメッセージ案:**
```
Disable developer unlock mode by default
```

---

## Phase 3: 体験品質の改善（後続）

### Step 3-E: コアフロー動作確認と修正

**目的:** 「Map → スポット選択 → Camera → 撮影 → 保存 → Memories 反映」のコアフローを実機・シミュレーターで確認し、不具合を修正する

**確認項目:**
1. Home → Map タブ遷移
2. Map でスポットをタップ → SpotDetailView に遷移
3. SpotDetailView から Camera へ `activeCameraSpotId` を渡す
4. Camera で2枚撮影 → 保存
5. 保存後に Memories タブに反映される
6. Home フィードにポストが表示される

**リスク:** 中（不具合が発見された場合、修正の範囲が広がる可能性）

**Definition of Done:**
- 上記6ステップがすべてエラーなく動作する（実機またはシミュレーター）

**コミットメッセージ案:**
```
Fix core flow: map → camera → save → memories
```

（修正内容に応じて変更）

---

### Step 3-F: Camera 保存フィードバック UI の改善（後回し）

**目的:** 撮影・保存後のユーザーへのフィードバックを改善する

**変更内容（未確認のため仮）:**
- 保存成功時のアニメーション・確認メッセージ
- 保存失敗時のエラー表示
- カメラ権限がない場合の案内表示

**前提条件:** Step 1-B-3（CameraView.swift 分割）と Step 3-E（コアフロー確認）が完了していること

**リスク:** 中（AVFoundation の状態管理を変更するため）

**Definition of Done:**
- 保存成功時に視覚的フィードバックがある
- カメラ権限なしの場合に適切なメッセージが表示される
- Build Succeeded

**コミットメッセージ案:**
```
Add save feedback and camera permission error handling
```

---

## タスク間の依存関係

```
3-D (Map スポット詳細 UX 改善) ★次の推奨
  ← 1-B-4 完了済みのため今すぐ可能

3-E (コアフロー確認)
  ← いつでも可（1-B-4 完了済み）
  └→ 3-F (Camera UI改善)

3-C (Homeセクション名)
  ← いつでも実施可能（独立）

2-A (developerUnlockMode)
  ← MapView.swift の QuestSpotDetailView は変更可能
  ← CameraView.swift 分割後に Camera 側も変更

1-B-3 (Camera分割) ← 後回し
  └→ 2-A (Camera側)
  └→ 3-F (Camera UI改善)

1-B-6 (SharedComponents)
  ← 1-B-3 完了後に実施（1-B-4, 1-B-5 は完了済み）

1-B-7 (旧モデル削除)
  ← いつでも実施可能（他タスクと独立）
```
