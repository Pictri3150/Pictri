# ピクトリ（Pictri）内部設計書

バージョン: 1.0  
作成日: 2026-06-07  
対象フェーズ: 開発MVP〜公開MVP

---

## 1. 内部設計の目的

本書は、ピクトリの内部実装を定義することを目的とする。

内部設計が扱う範囲は以下である。

- データモデルの定義とモデル間の関係
- 状態管理の方針と責任の所在
- 画面間でのデータ受け渡し設計
- コアフロー（Map → Camera → Save → Memories → Home）の実装レベルの詳細
- ローカル保存とモックデータの構成
- 将来のバックエンド接続に向けた境界の定義
- エラー処理・権限管理の方針

外部から見える仕様（画面構成・遷移・表示ルール）は `docs/03_EXTERNAL_DESIGN.md` に記載している。本書はその実現手段を定義する。

---

## 2. アプリ全体の内部構成

### 2-1. レイヤー構成

```
┌─────────────────────────────────────────┐
│ View Layer                              │
│  ContentView / HomeView / MapView /     │
│  CameraView / MemoriesView             │
├─────────────────────────────────────────┤
│ Store Layer（ObservableObject）          │
│  QuestMemoryStore / QuestFriendStore    │
├─────────────────────────────────────────┤
│ Service Layer（ObservableObject）        │
│  QuestLocationManager / QuestCameraService │
├─────────────────────────────────────────┤
│ Model Layer（struct / enum）             │
│  QuestModels.swift                      │
├─────────────────────────────────────────┤
│ Data Layer                              │
│  UserDefaults（メタデータ）              │
│  Documents Directory（画像ファイル）     │
│  QuestSampleData.swift（モックデータ）   │
└─────────────────────────────────────────┘
```

### 2-2. ファイルと責任の対応

| ファイル | 責任 |
|---------|-----|
| `ContentView.swift` | ルートコーディネーター。`@StateObject` の生成と `.environmentObject` 配布。`activeCameraSpotId` の管理 |
| `HomeView.swift` | Home 画面 + JQAccount 系コンポーネント |
| `MapView.swift` | `QuestMapView` + `QuestSpotDetailView` |
| `CameraView.swift` | `QuestCameraView`。`QuestCameraService` をローカル `@StateObject` として生成 |
| `MemoriesView.swift` | Memories 画面（Collect / Explore 両モード） |
| `QuestModels.swift` | 全データモデル定義 |
| `QuestSampleData.swift` | モックデータ定数（開発MVP 用） |
| `QuestMemoryStore.swift` | 撮影記録・フィード投稿の永続化と取得ロジック |
| `QuestFriendStore.swift` | フレンドリスト・申請管理（開発MVP ではインメモリ） |
| `QuestLocationManager.swift` | CoreLocation ラッパー。位置情報取得・権限管理 |
| `QuestCameraService.swift` | AVFoundation ラッパー。カメラセッション管理・撮影 |

---

## 3. 主要データモデル

### 3-1. QuestUser（ユーザー）

```swift
struct QuestUser: Identifiable, Hashable {
    let id: String           // ユーザー識別子（例: "user_keita"）
    let username: String     // @username
    let displayName: String  // 表示名
    let profileImageName: String?  // プロフィール画像ファイル名
}
```

**開発MVP の制約:** ローカル固定ユーザー（`mockUsers`）のみ。認証なし。  
**公開MVP で必要な変更:** バックエンドの認証トークン・UUID を `id` に使用する。

---

### 3-2. QuestFriend（フレンド関係）

```swift
struct QuestFriend: Identifiable, Hashable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let recentPlace: String      // 最近の投稿場所（表示用）
    let lastSharedText: String   // 最終投稿テキスト
}

struct QuestFriendRequest: Identifiable, Hashable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let message: String
    let requestedAtText: String
}
```

**開発MVP の制約:** `QuestFriendStore` がインメモリで管理。永続化なし。  
**公開MVP で必要な変更:** バックエンドから取得・同期する。

---

### 3-3. QuestPrefecture（都道府県）

```swift
struct QuestPrefecture: Identifiable, Hashable {
    let id: String           // 例: "kanagawa"
    let name: String         // 例: "神奈川"
    let englishName: String  // 例: "Kanagawa"
    let totalSpotCount: Int  // 登録スポット総数（Memories の進捗計算に使用）
}
```

**開発MVP の制約:** `mockQuestPrefectures`（`QuestSampleData.swift`）で定義。バンドル内の静的データ。

---

### 3-4. QuestSpot（スポット）

```swift
struct QuestSpot: Identifiable, Hashable {
    let id: String              // 例: "enoshima_coast"
    let prefectureId: String    // 例: "kanagawa"
    let name: String            // 例: "江の島海岸"
    let englishName: String     // 例: "enoshima"
    let areaName: String        // 例: "湘南"
    let latitude: Double        // 緯度
    let longitude: Double       // 経度
    let unlockRadiusMeters: Double  // 撮影許可範囲（メートル）
    let gridIndex: Int          // Memories グリッドの並び順（固定）
}
```

**位置認証:** `QuestLocationManager.isNear(_:)` が `distance <= unlockRadiusMeters` を判定する。  
**開発MVP の制約:** `mockQuestSpots`（静的配列）で定義。神奈川スポットのみ Map に表示。

---

### 3-5. QuestFeedPost（Home フィード投稿）

```swift
struct QuestFeedPost: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let username: String
    let spotId: String
    let prefectureId: String
    let createdAt: Date          // 投稿日時
    let expiresAt: Date          // 表示期限（createdAt + 7日）
    let displayDate: String      // 表示用日付文字列
    let displayPlace: String     // 表示用場所名
    let isMine: Bool             // 自分の投稿かどうか
    var imageName: String?       // 画像ファイル名（Documents 内）
    var verificationStatus: String?       // 位置認証ステータス
    var verifiedDistanceMeters: Double?   // 認証時の実測距離
}
```

**7日ルールの実装:** `expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: createdAt)`  
`visibleFeedPosts()` は `expiresAt > Date()` でフィルタする。  
**永続化:** `Codable` 準拠。`UserDefaults` に JSON として保存。

---

### 3-6. QuestMemoryPhoto（撮影記録・Memories の元データ）

```swift
struct QuestMemoryPhoto: Identifiable, Codable, Hashable {
    let id: String
    let spotId: String
    let prefectureId: String
    let imageName: String?       // 画像ファイル名（Documents 内）
    let createdAtText: String    // 表示用日時テキスト
    var verificationStatus: String?
    var verifiedDistanceMeters: Double?
}
```

**役割:** Memories（Collect / Explore）の表示データソース。保存後、永続的に残る。  
**永続化:** `Codable` 準拠。`UserDefaults` に JSON として保存。  
**Homeとの違い:** `QuestFeedPost` は7日で表示が消えるが、`QuestMemoryPhoto` は削除しない限り残る。

---

### 3-7. PhotoAsset（画像ファイル管理）

モデルではなく、`QuestMemoryStore` 内の実装として管理する。

| 処理 | 実装 |
|-----|-----|
| 保存 | `UIImage.jpegData(compressionQuality: 0.88)` → Documents ディレクトリに UUID.jpg として書き込み |
| 読み込み | `UIImage(contentsOfFile: url.path)` |
| ファイル名 | `UUID().uuidString + ".jpg"` |
| 保存先 | `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]` |

---

### 3-8. QuestVerificationStatus（位置認証ステータス）

```swift
enum QuestVerificationStatus: String, Codable, Hashable {
    case verified    // 現地認証済み（距離が unlockRadiusMeters 以内）
    case developer   // 開発モード（developerUnlockMode = true）
    case unverified  // 未認証
    case unknown     // 不明
}
```

---

### 3-9. Like / Comment（いいね・コメント）

現在の開発MVP では独立したモデルとして定義されていない。`QuestFeedPost` に対してローカルで管理する。

| 概念 | 現在の実装 |
|-----|----------|
| いいね | `HomeView` 内の `@State var likedPostIds: Set<String>` で管理 |
| いいね数 | `post.baseLikeCount + (likedPostIds.contains(post.id) ? 1 : 0)` でインライン計算 |
| コメント | `@State var commentsByPostId: [String: [String]]` で管理（HomeView ローカル） |

**公開MVP では以下のモデルが必要になる:**

```
Like:
  id: String
  postId: String
  userId: String
  createdAt: Date

Comment:
  id: String
  postId: String
  userId: String
  text: String
  createdAt: Date
```

---

## 4. データモデル間の関係

```
QuestPrefecture (1) ─────────────── (N) QuestSpot
    id                                    prefectureId

QuestSpot (1) ─────────────────────── (0..1) QuestMemoryPhoto
    id                                         spotId
    ※ 1スポットにつき最新1枚のみ保持（上書き保存）

QuestSpot (1) ─────────────────────── (N) QuestFeedPost
    id                                         spotId
    ※ 同一スポットへの再撮影で複数Postが生成される場合あり

QuestUser (1) ─────────────────────── (N) QuestFeedPost
    id                                         userId

QuestUser (N) ───────────────────── (M) QuestFriend
    ※ QuestFriend は相互フレンド関係を表す（非対称フォローなし）

QuestMemoryPhoto ── (1:1) ── QuestFeedPost
    ※ save() の1回の呼び出しで両方が生成される。
       同一 spotId の再撮影時は MemoryPhoto が上書きされ、FeedPost は追記される
```

---

## 5. 状態管理方針

### 5-1. Store の責任分担

| Store | 管理する状態 | スコープ |
|-------|-----------|---------|
| `QuestMemoryStore` | 撮影記録（`memoryPhotos`）・フィード投稿（`feedPosts`）の永続化と読み込み | アプリ全体（environmentObject） |
| `QuestFriendStore` | フレンド一覧・申請リスト | アプリ全体（environmentObject） |
| `QuestLocationManager` | 現在地・位置情報権限状態 | アプリ全体（environmentObject） |
| `QuestCameraService` | カメラセッション・撮影状態 | Camera 画面のみ（@StateObject in QuestCameraView） |

### 5-2. @StateObject の生成場所

```
ContentView
  @StateObject var memoryStore = QuestMemoryStore()
  @StateObject var friendStore = QuestFriendStore()
  @StateObject var locationManager = QuestLocationManager()
    │
    ├── .environmentObject(memoryStore)
    ├── .environmentObject(friendStore)
    └── .environmentObject(locationManager)
         │
         └── 子 View は @EnvironmentObject で参照する

QuestCameraView
  @StateObject var cameraService = QuestCameraService()
    ※ Camera 画面のみで使うため ContentView には持ち上げない
```

### 5-3. @State と @Binding の使い方

| 値 | 定義場所 | 渡し方 |
|----|---------|-------|
| `selectedTab: AppTab` | ContentView @State | 子 View に @Binding で渡す |
| `activeCameraSpotId: String` | ContentView @State | Map → ContentView → Camera に @Binding で渡す |
| `likedPostIds: Set<String>` | HomeView @State | HomeView 内でのみ使用 |
| `commentsByPostId: [String: [String]]` | HomeView @State | HomeView 内でのみ使用 |
| `viewMode: MemoryViewMode` | MemoriesView @State | ExplorePhotoDetailSheet に @Binding で渡す |

---

## 6. 画面間データ受け渡し設計

### 6-1. 受け渡しパターン一覧

| データ | 方向 | 手段 |
|-------|-----|-----|
| 選択した spotId | Map → Camera | `@Binding activeCameraSpotId`（ContentView 経由） |
| 選択した spot 全体 | Map → SpotDetailView | イニシャライザ引数（直接渡し） |
| 撮影した UIImage | CameraService → CameraView | `@Published capturedImage` |
| 保存済み memories | Store → Memories | `@EnvironmentObject memoryStore.memoryPhotos` |
| 保存済み feedPosts | Store → Home | `@EnvironmentObject memoryStore.visibleFeedPosts()` |
| フレンド一覧 | Store → Home / Account | `@EnvironmentObject friendStore.friends` |
| 現在地情報 | LocationManager → Camera | `@EnvironmentObject locationManager` |
| Memories 表示モード | MemoriesView → ExploreDetailSheet | `@Binding viewMode` |

---

## 7. Map で選択した spotId を Camera へ渡す設計

```
[ユーザー操作]
  MapKit ピンタップ → QuestSpotDetailView 表示

[QuestMapView]
  選択された spot: QuestSpot を保持
  「カメラを起動」ボタンタップ時:
    1. activeCameraSpotId = spot.id  （@Binding 経由で ContentView の @State を更新）
    2. selectedTab = .camera         （@Binding 経由でタブを Camera に切り替え）

[ContentView]
  @State var activeCameraSpotId: String
    → QuestCameraView(selectedSpotId: $activeCameraSpotId) に @Binding で渡す

[QuestCameraView]
  @Binding var selectedSpotId: String
    → mockQuestSpots.first { $0.id == selectedSpotId } で QuestSpot を解決
    → QuestLocationManager.isNear(spot) で位置認証を実行
```

**注意:** `activeCameraSpotId` は初期値 `"enoshima_coast"` を持つ。spotId なしで Camera タブを直接タップした場合もこのデフォルト値が使われる。将来的には nil 許容に変更することが望ましい。

---

## 8. Camera で撮影した写真を Save 処理へ渡す設計

```
[QuestCameraService]
  AVCapturePhotoCaptureDelegate.photoOutput(_:didFinishProcessingPhoto:error:)
    → AVCapturePhoto → UIImage に変換
    → photoCompletion: ((UIImage?) -> Void)? を呼び出す

[QuestCameraView]
  cameraService.capturePhoto { [weak self] image in
      guard let image else { return }
      self?.capturedImage = image  // @State で保持
  }

[QuestCameraView 保存ボタンタップ時]
  guard let image = capturedImage, let spot = currentSpot else { return }
  memoryStore.save(
      image: image,
      for: spot,
      verificationStatus: verificationStatus,
      verifiedDistanceMeters: distanceMeters
  )
```

**verificationStatus の決定ロジック:**

| 条件 | status |
|-----|-------|
| `developerUnlockMode = true` | `.developer` |
| `locationManager.isNear(spot) = true` | `.verified` |
| 位置情報なし / 範囲外 | `.unverified` |

---

## 9. Save 処理で Post / Memory へ変換する設計

`QuestMemoryStore.save(image:for:verificationStatus:verifiedDistanceMeters:)` が1回の呼び出しで以下を行う。

```
save() の処理フロー:
  1. saveImageToDocuments(image:)
       UIImage → JPEG → Documents/UUID.jpg に書き込み
       戻り値: fileName: String

  2. saveMemoryPhoto(for:imageName:...)
       既存 memoryPhotos に同一 spotId があれば上書き
       なければ先頭に追加
       → @Published memoryPhotos が更新 → Memories View が自動再描画

  3. createFeedPost(for:imageName:...)
       QuestFeedPost を生成（expiresAt = now + 7日）
       feedPosts の先頭に追加
       → @Published feedPosts が更新 → Home View が自動再描画

  4. save()（private）
       memoryPhotos と feedPosts を JSONEncoder で UserDefaults に書き込み
```

**同一スポットの再撮影時の挙動:**
- `QuestMemoryPhoto` は上書き（最新写真1枚のみ保持）
- `QuestFeedPost` は追記（再撮影のたびに新しい Post が生成される）

---

## 10. Memories への反映設計

```
[QuestMemoryStore]
  @Published var memoryPhotos: [QuestMemoryPhoto]

[MemoriesView]
  @EnvironmentObject var memoryStore: QuestMemoryStore
  memoryStore.memoryPhotos の変更を自動検知して再描画

[Collect モードの表示ロジック]
  mockQuestSpots（静的）をグリッドのベースとする
    → spot ごとに memoryStore.hasMemory(for: spot) を判定
    → true: 写真サムネイルを表示
    → false: mappin プレースホルダーを表示
  進捗: memoryStore.completedCount(prefectureId:) / prefecture.totalSpotCount

[Explore モードの表示ロジック]
  memoryStore.memoryPhotos を createdAtText の降順で並べ替えて表示
```

**hasMemory(for:) の実装:**

```swift
func hasMemory(for spot: QuestSpot) -> Bool {
    memoryPhotos.contains { $0.spotId == spot.id }
}
```

---

## 11. Home フィードへの反映設計

```
[QuestMemoryStore]
  @Published var feedPosts: [QuestFeedPost]

[HomeView]
  @EnvironmentObject var memoryStore: QuestMemoryStore

  表示する投稿:
    memoryStore.visibleFeedPosts()
      → feedPosts.filter { $0.expiresAt > Date() }.sorted { $0.createdAt > $1.createdAt }

  フレンドの投稿との混在:
    開発MVP: mockQuestFeedPosts（QuestSampleData.swift）を feedPosts に含むことで代替
    公開MVP: バックエンドからフレンドの投稿を取得して feedPosts に追加
```

---

## 12. 7日限定フィードの内部処理

### 12-1. 期限の設定

```swift
// createFeedPost() 内
expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
```

### 12-2. 表示時のフィルタリング

```swift
func visibleFeedPosts() -> [QuestFeedPost] {
    let now = Date()
    return feedPosts
        .filter { $0.expiresAt > now }
        .sorted { $0.createdAt > $1.createdAt }
}
```

### 12-3. 起動時の一括削除

```swift
// QuestMemoryStore.init() で呼ぶ
func purgeExpiredFeedPosts() {
    let now = Date()
    feedPosts.removeAll { $0.expiresAt <= now }
    save()  // UserDefaults を更新
}
```

### 12-4. 7日ルールの範囲

- `expiresAt` は `createdAt` から正確に7日後（秒単位）
- 日本語「7日」は暦日ではなく 7 × 24時間として実装
- UI 上の日数カウントダウンは表示しない（外部設計書の禁止事項）

---

## 13. 訪問済みスポット判定とピン表示状態

### 13-1. 訪問済み判定

```swift
// QuestMemoryStore
func hasMemory(for spot: QuestSpot) -> Bool {
    memoryPhotos.contains { $0.spotId == spot.id }
}
```

### 13-2. Map ピン表示の3状態

| 状態 | 条件 | 外観 |
|-----|-----|-----|
| 撮影済み | `hasMemory(for: spot) = true` | 強調色または透過ピン |
| 撮影可能 | `hasMemory = false` かつ `locationManager.isNear(spot) = true` | 通常ピン |
| 未撮影 | `hasMemory = false` かつ `isNear = false`（または位置情報なし） | グレーピン |

### 13-3. SpotDetailView の heroStatusChip の3状態

`QuestSpotDetailView` の `heroStatusChip` は上記3状態に対応して表示を切り替える。

```
撮影済み → 「撮影済み」（強調色）
撮影可能 → 「撮影可能」（通常色）
未撮影   → 「未撮影」（グレー）
```

---

## 14. ローカル保存 / モックデータ / 将来バックエンド接続の分離

### 14-1. 現在（開発MVP）のデータ層

```
種別                   保存場所           実装
─────────────────────────────────────────────────
スポット定義           バンドル内静的データ  QuestSampleData.swift（mockQuestSpots）
都道府県定義           バンドル内静的データ  QuestSampleData.swift（mockQuestPrefectures）
ユーザー情報           バンドル内静的データ  QuestSampleData.swift（mockUsers）
フレンド一覧           インメモリ           QuestFriendStore（@Published、再起動で初期化）
撮影記録メタデータ     UserDefaults（JSON） QuestMemoryStore（memoryPhotosKey）
フィード投稿メタデータ UserDefaults（JSON） QuestMemoryStore（feedPostsKey）
画像ファイル           Documents Dir      QuestMemoryStore（UUID.jpg）
フレンドの投稿         バンドル内モック     mockQuestFeedPosts（QuestSampleData.swift）
```

### 14-2. 将来（公開MVP）のバックエンド接続方針

バックエンド接続時に変更が必要な箇所を明示する。

| 現在の実装 | 将来の実装 |
|----------|---------|
| `mockUsers` の固定ユーザー | Firebase Auth / Supabase Auth によるアカウント認証 |
| `mockQuestFriends` のモックフレンド | バックエンド API からフレンドリストを取得 |
| `mockQuestFeedPosts` のモック投稿 | バックエンド API からフレンドの投稿を取得 |
| `UserDefaults` でのフィード保存 | バックエンドへの投稿保存・取得に置き換え |
| `Documents Dir` でのローカル画像保存 | Cloud Storage（Firebase Storage 等）への画像アップロード |
| いいね・コメントのローカル @State 管理 | バックエンド API への読み書きに置き換え |

**設計原則:** バックエンド接続時に最小限の変更で済むよう、Store の public インターフェースは変えず、内部実装だけを差し替えられるようにする。

---

## 15. エラー処理方針

### 15-1. Camera 系エラー

| エラー | 発生場所 | 処理方法 |
|-------|---------|---------|
| カメラ権限拒否 | `QuestCameraService.requestAndConfigure()` | `@Published permissionDenied = true` でフラグを立て、View 側で誘導 UI を表示 |
| カメラデバイスなし | `QuestCameraService` 初期化時 | `@Published errorMessage` にメッセージをセット |
| 撮影失敗 | `photoOutput(_:didFinishProcessingPhoto:error:)` | `photoCompletion(nil)` を呼び出し、View 側でリトライを促す |
| 画像保存失敗 | `QuestMemoryStore.save()` 内 | `saveImageToDocuments()` が nil を返す。guard で早期 return し、現状はサイレント失敗 |

### 15-2. 位置情報系エラー

| エラー | 発生場所 | 処理方法 |
|-------|---------|---------|
| 位置情報権限拒否 | `QuestLocationManager.locationManagerDidChangeAuthorization` | `@Published errorMessage` にメッセージをセット。Camera View が権限エラーを表示 |
| 位置取得失敗 | `locationManager(_:didFailWithError:)` | `@Published errorMessage` にセット |
| スポットから遠すぎる | `QuestLocationManager.isNear()` が false | Camera View が「撮影不可」状態を表示。シャッターを無効化 |

### 15-3. データ保存系エラー

| エラー | 発生場所 | 処理方法 |
|-------|---------|---------|
| UserDefaults 書き込み失敗 | `QuestMemoryStore.save()` | `print()` でログ出力のみ（現状）。App Store 提出前に改善を推奨 |
| UserDefaults 読み込み失敗 | `QuestMemoryStore.load()` | モックデータにフォールバック |

**方針:** 開発MVP ではエラーログを `print()` で出力し、クラッシュを避けることを優先する。公開MVP でリトライ・ユーザー通知のロジックを追加する。

---

## 16. 権限状態の管理方針

### 16-1. カメラ権限

```
管理クラス: QuestCameraService
@Published var permissionDenied: Bool
@Published var isCameraAvailable: Bool

フロー:
  requestAndConfigure() 呼び出し
    → AVCaptureDevice.authorizationStatus
      .authorized     → カメラセッション設定・起動
      .notDetermined  → requestAccess() → 許可なら設定・起動、拒否なら permissionDenied = true
      .denied         → permissionDenied = true
```

### 16-2. 位置情報権限

```
管理クラス: QuestLocationManager
@Published var authorizationStatus: CLAuthorizationStatus

フロー:
  requestPermission() → requestWhenInUseAuthorization()
  locationManagerDidChangeAuthorization で authorizationStatus を更新
    .authorizedWhenInUse → startUpdatingLocation()
    .denied              → errorMessage にメッセージをセット
```

### 16-3. フォトライブラリ権限

現在の実装では、画像は `Documents Dir` に保存しており `PHPhotoLibrary` への書き込みは行っていない。フォトライブラリ権限は現状不要。

---

## 17. 開発MVP と公開MVP の内部設計上の違い

| 項目 | 開発MVP | 公開MVP |
|-----|--------|--------|
| ユーザー認証 | なし（固定ユーザー `user_keita`） | Firebase Auth 等による認証 |
| フレンド一覧 | `mockQuestFriends`（インメモリ） | バックエンド API から取得 |
| フレンドの投稿 | `mockQuestFeedPosts`（バンドル内） | バックエンド API から取得 |
| いいね | `HomeView @State likedPostIds`（ローカル） | バックエンドへ書き込み・読み込み |
| コメント | `HomeView @State commentsByPostId`（ローカル） | バックエンドへ書き込み・読み込み |
| 画像保存 | Documents Dir | Cloud Storage |
| 投稿データ保存 | UserDefaults | バックエンド DB |
| `developerUnlockMode` | `false`（`#if DEBUG` で切り替え可） | `false`（固定） |
| 位置認証 | `QuestLocationManager.isNear()` | 同左（変更なし） |
| 7日フィード | `expiresAt` でローカルフィルタ | バックエンドがフィルタ処理を担う（またはクライアント側でも維持） |

---

## 18. 今後実装時に守るべき制約

### 18-1. データ整合性

- **すべての `QuestMemoryPhoto` は `spotId` と `prefectureId` を持たなければならない。** nilを許容してはならない。
- **`QuestFeedPost` の `expiresAt` は必ず `createdAt + 7日` で設定する。** 手動で別の値を設定してはならない。
- **`QuestMemoryStore.save()` は `QuestMemoryPhoto` と `QuestFeedPost` を必ずセットで生成する。** 片方だけ生成するロジックを追加してはならない。

### 18-2. コアフローの保護

- `activeCameraSpotId` の受け渡しロジックを変更する場合は、Map → SpotDetail → Camera の全体を確認してから行う。
- `QuestMemoryStore` の `@Published memoryPhotos` の型や構造を変更する場合は、Memories View（Collect / Explore 両モード）への影響を確認する。
- `visibleFeedPosts()` のフィルタロジックを変更する場合は、7日ルールが維持されることを確認する。

### 18-3. Store の扱い

- `QuestMemoryStore` / `QuestFriendStore` / `QuestLocationManager` は `ContentView` でのみ `@StateObject` で生成する。子 View では `@EnvironmentObject` で参照する。
- `QuestCameraService` は `QuestCameraView` のみがローカル `@StateObject` で生成する。他の View からアクセスしてはならない。

### 18-4. 死にコードの管理

以下のモデルは現在 `QuestModels.swift` に残存しているが、どこからも参照されていない可能性がある。削除前に `grep -rn` で全 Swift ファイルの参照を確認すること。

- `RecentQuestPost`
- `PrefectureMemory`
- `MemorySpot`
- `MapDot`
- `KanagawaDot`
- `QuestPost`（`QuestFeedPost` とは別物。使われているか要確認）

### 18-5. スコープ外の実装禁止

`docs/02_REQUIREMENTS.md` の Later / 対象外機能は実装しない。

- ランキング・スコア・ポイント
- 動画撮影
- AI 推薦
- 多言語対応（公開MVP 前）
- グループ旅行

---

## 19. 未決定事項

| 事項 | 現状 | 決定が必要なタイミング |
|-----|-----|------------------|
| `activeCameraSpotId` の nil 許容化 | 現在は初期値 `"enoshima_coast"`。spotId なしの Camera 起動時の挙動が曖昧 | Camera QA 時 |
| 同一スポット再撮影時のメモリ上書き vs 追記 | 現在は `QuestMemoryPhoto` を上書き。複数枚保持の仕様は未定 | Memories 設計確定時 |
| いいね・コメントの公開MVP 向けモデル定義 | 開発MVP ではローカル @State 管理のため未定義 | バックエンド接続設計時 |
| `QuestPost` モデルの扱い | `QuestFeedPost` と並存しているが役割が不明確。削除 or 統合が必要 | Step 1-B-7（旧モデル削除）時 |
| UserDefaults の上限 | 大量の feedPosts が蓄積した場合の上限未設定 | QA・負荷テスト時 |
| 画像ファイルの削除ポリシー | `QuestMemoryPhoto` が上書きされた場合、旧画像ファイルが Documents に残る。削除ロジック未実装 | ストレージ管理設計時 |
| バックエンド接続時の既存ローカルデータの移行 | UserDefaults / Documents Dir のデータをバックエンドへ移行する方針が未定 | 公開MVP バックエンド設計時 |
| 位置認証半径（unlockRadiusMeters）の実地値 | 現在はスポットごとに設定可能だが、実地での適切な半径は未検証 | 実機・現地テスト時 |
