# NEXT_TASKS.md — JapanQuest 次のタスク一覧

最終更新: 2026-06-03

---

## 推奨作業順序の概要

```
Phase 1: コード整理（ファイル分割 + 死にコード削除）
  Step 1-B-3  CameraView.swift 分割
  Step 1-B-4  MapView.swift 分割
  Step 1-B-5  HomeView.swift + JQAccountView.swift 分割
  Step 1-B-6  SharedComponents.swift 分割
  Step 1-B-7  旧モデル・旧サンプルデータ 削除

Phase 2: App Store 必須修正
  Step 2-A    developerUnlockMode をデフォルト false に変更

Phase 3: 体験品質の改善（見えるUI改善）
  Step 3-A    Home Hero カードを実データで動的に
  Step 3-B    コアフロー（Map→Camera→Save→Memories）の動作確認と修正
  Step 3-C    Camera 保存フィードバック UI の改善
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

### Step 1-B-4: MapView.swift 分割

**目的:** Map ドメインを分離し、後の Map 改善（複数県対応など）を安全にする

**対象型:**
- `QuestMapView`
- `QuestSpotDetailView`

**リスク:** 中
- `QuestMapView` は `@Binding var activeCameraSpotId` を ContentView から受け取り、Camera 遷移時に書き込む
- `QuestSpotDetailView` は `@AppStorage("developerUnlockMode")` を参照
- `NavigationStack` + `navigationDestination` の構造を壊さないよう注意

**Definition of Done:**
- `MapView.swift` が存在する
- Build Succeeded
- git diff の変更が ContentView.swift（削除）と MapView.swift（追加）のみ

**コミットメッセージ案:**
```
Extract MapView and SpotDetailView from ContentView
```

---

### Step 1-B-5: HomeView.swift + JQAccountView.swift 分割

**目的:** Home ドメインと Account シートを分離する

**対象型（HomeView.swift）:**
- `HomeView`
- `HomeMemoryTile`
- `EmptyFeedCard`
- `HomeLargePostCard`
- `HomePostDetailSheet`

**対象型（JQAccountView.swift）:**
- `JQAccountSheetView`
- `JQAccountSection`（enum）
- `JQAccountSectionButton`
- `JQAccountStat`
- `JQAccountMenuRow`
- `JQFriendMiniRow`
- `JQRequestMiniRow`

**注意:** HomeView と JQAccountSheetView は密接に関連（HomeView が sheet として表示する）。同じコミットで2ファイルに分けるか、2ステップに分けるかは作業時に判断する。

**リスク:** 中
- `HomeView` は `@Binding var selectedTab` を受け取り、Camera・Map・Memories へのタブ切り替えを行う
- `JQAccountSheetView` は `@EnvironmentObject` で friendStore / memoryStore を使用

**Definition of Done:**
- `HomeView.swift` と `JQAccountView.swift` が存在する
- Build Succeeded
- git diff の変更が ContentView.swift（削除）と新規2ファイル（追加）のみ

**コミットメッセージ案:**
```
Extract HomeView and account sheet views from ContentView
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
- `QuestSpotDetailView`（ContentView.swift line 1280 → 分割後は MapView.swift）の `@AppStorage("developerUnlockMode") private var developerUnlockMode = true` を `false` に変更
- `QuestCameraView`（ContentView.swift line 1549 → 分割後は CameraView.swift）の同設定を `false` に変更
- 開発者向けトグル UI（line 1843）は残す（隠しデバッグ機能として有用）

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

## Phase 3: 体験品質の改善

### Step 3-A: Home Hero カードを実データで動的に

**目的:** Hero カードの「Mapを拡大すると...」という静的テキストを、ユーザーの進捗に合わせた内容にする

**変更内容:**
- 未クリアスポット数を `QuestMemoryStore` から取得して表示
- クリア済みスポット数の表示
- 初回利用時（まだスポット0件）の onboarding メッセージ

**前提条件:** Step 1-B-5（HomeView.swift 分割）が完了していること

**リスク:** 低（表示テキストの変更のみ、ロジック変更なし）

**Definition of Done:**
- スポット達成数が Hero カードに反映される
- 0件時・達成時それぞれの表示が適切

**コミットメッセージ案:**
```
Show real spot progress in home hero card
```

---

### Step 3-B: コアフロー動作確認と修正

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

### Step 3-C: Camera 保存フィードバック UI の改善

**目的:** 撮影・保存後のユーザーへのフィードバックを改善する

**変更内容（未確認のため仮）:**
- 保存成功時のアニメーション・確認メッセージ
- 保存失敗時のエラー表示
- カメラ権限がない場合の案内表示

**前提条件:** Step 3-B（コアフロー確認）が完了していること

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
1-B-3 (Camera分割)
  └→ 2-A (developerUnlockMode)
  └→ 3-B (コアフロー確認)
      └→ 3-C (Camera UI改善)

1-B-4 (Map分割)
  └→ 2-A (developerUnlockMode)

1-B-5 (Home分割)
  └→ 3-A (Hero カード実データ)

1-B-6 (SharedComponents)
  ← 1-B-3, 1-B-4, 1-B-5 完了後に実施

1-B-7 (旧モデル削除)
  ← いつでも実施可能（他タスクと独立）
```
