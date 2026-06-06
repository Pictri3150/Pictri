# PROJECT_STATE.md — ピクトリ（Pictri）現在の実装状況

最終更新: 2026-06-07（Memories Explore モード Stage 2 完了）

> **プロダクト名:** ピクトリ（Pictri）— *picture trip* に由来  
> **内部プロジェクト名:** JapanQuest（Xcode・Bundle ID・型名はそのまま）

---

## ビルド状態

| 項目 | 状態 |
|-----|------|
| Xcode Build | **Succeeded** |
| ブランチ | `main` |
| 最新コミット | `6693d59` — Polish memories explore carousel interaction |
| 最新 Swift コード変更 | `6693d59` — Polish memories explore carousel interaction |
| ワーキングツリー | クリーン |

---

## コミット履歴（直近）

```
6693d59  Polish memories explore carousel interaction
dbb2b0c  Add memories explore mode carousel
db03fa1  Update project state after memories visual improvement
e09368a  Improve memories view visual quality
8e827aa  Clean up project docs and next task priorities
1eaca0e  Update project state after spot detail status improvement
```

---

## 完了済みステップ（主要）

| ステップ | 内容 | コミット |
|---------|-----|---------|
| Step 1-A | レガシーファイル5本削除・死にコード除去 | Fix build error and complete Step 1-A cleanup |
| Step 1-B-1 | MemoriesView.swift 分割（452行） | Extract Memories views from ContentView |
| Step 1-B-2 | 旧 Account 系 死にコード削除（8型、429行削減） | Remove unused legacy account views |
| Step 1-B-3 | CameraView.swift 分割（1043行） | `4d6e29b` |
| Step 1-B-4 | MapView.swift 分割（384行） | `fab79d6` |
| Step 1-B-5 | HomeView.swift 分割（975行、13型） | `74c68f6` |
| Step 2-A | developerUnlockMode デフォルト false 化 | `7232f65` |
| Step 3-A | Home Hero カードにスポット進捗を実データ反映 | Show spot progress in home hero card |
| Step 3-B | EmptyFeedCard を Map-first な空状態に改善 | Update empty home state for map-first journey |
| Step 3-E | コアフロー確認（コード上・破損なし）| コミットなし（実機確認は別途必要） |
| Step 3-F | Camera 保存フィードバック UI 改善 | `103f968` |
| Step 3-G | UI 表示名を「ピクトリ」に変更 | `ce2df41` |
| Step 3-H | Home Hero カード Map 導線改善 | `43e9fca` |
| Step 3-I | Home「気になるスポット」セクション追加 | `651d464` / `cc15bf9` |
| Camera 保存後改善 | 「Memoriesで確認する」CTA を primary スタイルに格上げ | `f591d33` |
| Step 3-D | QuestSpotDetailView の heroStatusChip を3-state 対応に | `31831c4` |
| Memories UI 改善 | サマリータイルで実写真表示・ヘッダー文言改善・mappin アイコン | `e09368a` |
| Memories Explore Stage 1 | コレクト/探索モード切り替え・横スクロールカルーセル・ExplorePhotoCard | `dbb2b0c` |
| Memories Explore Stage 2 | スナップスクロール・カード影・カルーセル垂直配置改善 | `6693d59` |

---

## 現在のファイル構成

| ファイル | 行数 | 状態・備考 |
|---------|-----|-----------|
| `ContentView.swift` | 186行 | Root / TabBar / JQUI / AppBackground のみ |
| `HomeView.swift` | ~1053行 | Home 系 + JQAccount 系（13型） |
| `MapView.swift` | ~405行 | QuestMapView / QuestSpotDetailView（heroStatusChip 追加済み） |
| `CameraView.swift` | 1043行 | QuestCameraView 系（4型） |
| `MemoriesView.swift` | ~540行 | MemoriesView 系 + ExplorePhotoCard + MemoryVisualStyle（Explore Stage 1/2 実装済み） |
| `QuestModels.swift` | 172行 | **要精査**（旧モデルが残存） |
| `QuestSampleData.swift` | 618行 | **要精査**（旧モックデータが残存） |
| `QuestMemoryStore.swift` | 267行 | 安定 |
| `QuestFriendStore.swift` | 54行 | 安定 |
| `QuestLocationManager.swift` | 90行 | 安定 |
| `QuestCameraService.swift` | 221行 | 安定 |
| `QuestCameraPreview.swift` | 46行 | 安定 |
| `QuestMapKitView.swift` | 411行 | 安定 |
| `QuestOverlayRenderer.swift` | 109行 | 安定 |
| `QuestProofBadge.swift` | 98行 | 安定 |
| `ShareSheet.swift` | 20行 | 安定 |
| `JapanQuestApp.swift` | 10行 | 完了 |

---

## 各画面の現状

### Home（動作確認未実施）
- 「ピクトリ」表示・Hero Map導線・スポット進捗・空状態 Map-first 文言 — 改善済み
- 「気になるスポット」セクションあり
- 未改善: セクション名「最近のシェア」「最近埋まった場所」（Step 3-C 候補）

### Map（動作確認未実施）
- `QuestSpotDetailView` に `heroStatusChip` 追加済み（撮影済み / 撮影可能 / 未撮影 を3-state 表示）
- `developerUnlockMode = false`（現地認証が有効）
- 神奈川のみ表示

### Camera（動作確認未実施）
- 2枚連続撮影フロー（内カメ → 外カメ）
- `developerUnlockMode = false`（`#if DEBUG` トグルで開発時解除可）
- 保存後: 「Memoriesに保存しました」+ primary CTA「Memoriesで確認する」

### Memories（動作確認未実施）
- 県別サマリーカード + 詳細ビュー
- **サマリーカードのプレビュータイルで実際の写真サムネイルを表示**（`e09368a`）
- **ヘッダーサブテキスト: 「現地で撮った写真が記録になる」**（旅の記録寄りに改善）
- **未訪問・空セルのアイコンを `mappin` に変更**（フラグ感・ゲーム感を除去）
- **Exploreモード Stage 1 実装済み**（`dbb2b0c`）: コレクト/探索切り替え・横スクロールカルーセル・スケール演出
- **Exploreモード Stage 2 実装済み**（`6693d59`）: スナップスクロール（`.scrollTargetBehavior(.viewAligned)`）・カード影・カルーセル垂直配置改善
- Stage 3（タップで県詳細 or 写真拡大遷移）は未実装

### Account（動作確認未実施）
- `JQAccountSheetView`（Home 右上アイコンからシート表示）
- フレンド管理（ローカルのみ、Firebase 未接続）

---

## コアフローの確認状況

| フロー | 状態 |
|-------|------|
| Home → Map タブ遷移 | コード上確認済み（実機未確認） |
| Map スポット選択 → SpotDetailView 遷移 | コード上確認済み（実機未確認） |
| SpotDetailView → Camera へ activeCameraSpotId を渡す | コード上確認済み（実機未確認） |
| Camera で2枚撮影 → QuestMemoryStore.save() | コード上確認済み（実機未確認） |
| 保存後 Memories に自動反映 | コード上確認済み（実機未確認） |
| Home フィードにポストが表示 | 未確認 |
| Account シートの開閉 | 未確認 |

---

## 既知の課題

1. **カメラ権限なしのフォールバック未確認**（App Store 提出前に必須）
2. **旧モデル型が QuestModels.swift に残存**（`RecentQuestPost` 等5型 — Step 1-B-7 候補）
3. **コアフロー実機確認が未完了**（コード上は問題なし）
4. **Map は神奈川のみ**（他県スポットデータはあるが Map 画面は kanagawa フィルタのみ）
