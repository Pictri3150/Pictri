# CLAUDE.md — JapanQuest 開発ガイド

Claude Codeはこのファイルを最初に読み、作業前に `docs/PROJECT_STATE.md` と `docs/NEXT_TASKS.md` を確認すること。

---

## プロダクト概要

**JapanQuest** は Swift / SwiftUI 製の iOS 旅行写真 SNS アプリ。

- 場所認証された旅行写真と思い出保存を中心にする
- ゲーム・ランキングアプリではない
- BeReal クローンに見えないようにする
- 観光スタンプアプリっぽくしない
- 地図・ピン・場所認証・県別 Memories を軸にする

### コアフロー（最重要）

```
地図でスポット発見 → スポット選択 → カメラ起動 → 撮影 → 保存 → Memories に反映
```

### UI 方針

- 黒白基調、高級感、余白、静けさを重視
- Bottom Tab: Home / Map / Camera / Memories
- Account / Friend はタブではなく Home 右上アイコンから入る

---

## 作業前の必須確認

1. `docs/PROJECT_STATE.md` — 現在のビルド状態・完了済みStep・既知の課題
2. `docs/NEXT_TASKS.md` — 次の候補タスク・推奨順序・Definition of Done

---

## 開発ルール

### 変更の粒度
- 一度に変更するのは **1領域・1ファイル** だけ
- UI改善と大規模リファクタリングを同時に行わない
- 設計変更とバグ修正を同じコミットに混ぜない

### Build の維持
- すべての変更後に **Xcode Command+B（Build Succeeded）** を確認してからコミット
- ビルドが壊れた場合はそのステップを完了とみなさない

### コミットの方針
- コミット対象は Swift ソースファイルのみ
- 以下は **絶対にコミットしない**:
  - `xcuserdata/`
  - `DerivedData/`
  - `.DS_Store`
  - `project.xcworkspace/xcuserdata/`

### 破壊的操作
- `rm -rf`、`git reset --hard`、`git clean -f`、`git push --force` は **明示的な許可なしに実行しない**
- 大量削除の前は必ずユーザーに確認する

### コードの品質
- 死にコード（どこからも呼ばれていない型・関数）は残さない
- コードを移動するだけの分割では、UIや機能を変更しない
- 不明な点は推測で断定せず「未確認」と記録する

### ドキュメントの更新
- 作業完了後、`docs/PROJECT_STATE.md` と `docs/NEXT_TASKS.md` を必要に応じて更新する
- CLAUDE.md 自体はプロダクト方針と開発ルールのみ記載し、進捗状態は書かない

---

## ファイル構成の原則

各ドメインは独立したファイルに分離する（分割進行中）:

| ファイル | 担当 |
|---------|-----|
| `ContentView.swift` | Root coordinator のみ（最終目標: ~60行） |
| `HomeView.swift` | Home 画面 + HomeMemoryTile 等のサブコンポーネント |
| `MapView.swift` | QuestMapView + QuestSpotDetailView |
| `CameraView.swift` | QuestCameraView + キャプチャ関連 enum |
| `MemoriesView.swift` | Memories 画面（分割済み） |
| `JQAccountView.swift` | JQAccountSheetView + JQAccount 系コンポーネント |
| `SharedComponents.swift` | AppBackground / JQUI / JQFloatingTabBar |
| `QuestModels.swift` | 全データモデル定義 |
| `QuestSampleData.swift` | モックデータ定数 |
| `QuestMemoryStore.swift` | メモリー・フィード永続化 |
| `QuestFriendStore.swift` | フレンド管理 |
| `QuestLocationManager.swift` | CoreLocation |
| `QuestCameraService.swift` | AVFoundation |
| `QuestCameraPreview.swift` | カメラプレビュー UIViewRepresentable |
| `QuestMapKitView.swift` | MapKit UIViewRepresentable |
| `QuestOverlayRenderer.swift` | 写真オーバーレイ描画 |
| `QuestProofBadge.swift` | 検証バッジ UI |
| `ShareSheet.swift` | UIActivityViewController |

---

## アーキテクチャメモ

- `ContentView` が `@StateObject` で `QuestMemoryStore` / `QuestFriendStore` / `QuestLocationManager` を生成し `.environmentObject` で全子 View に配布する
- スポット一覧は `mockQuestSpots`（グローバル定数、`QuestSampleData.swift`）を直参照
- `QuestCameraService` は `QuestCameraView` 内で `@StateObject` 生成（ローカルスコープ）
- `JQAccountSheetView` は `HomeView` の `.sheet` として呼ばれている
- `developerUnlockMode` は現在デフォルト `true`（App Store 提出前に `false` へ変更必須）
