import Foundation
import Combine

// MARK: - Entitlement (minimal domain boundary — no billing infra exists yet)
//
// リポジトリ全体を監査した結果、StoreKit・IAP・entitlement関連の実装は一切
// 存在しなかった(grep済み)。したがって今回はStoreKitの本格導入はせず、
// 「FREE/PREMIUM」という区分だけをdomain層に持たせ、実際の課金導線
// (StoreKit Product購入・レシート検証等)は将来の専用タスクに委ねる。
// DEBUGビルドでは`-pictriEntitlement free|premium`で直接切り替えて
// UIを再現できるようにする。RELEASEビルドでは常に.free。

enum QuestEntitlementTier: String {
    case free
    case premium
}

final class QuestEntitlementStore: ObservableObject {
    @Published private(set) var tier: QuestEntitlementTier

    init() {
        #if DEBUG
        tier = PictriVisualReview.entitlementTierOverride ?? .free
        #else
        tier = .free
        #endif
    }

    #if DEBUG
    /// QA目的でtierをその場で切り替える。永続化はしない
    /// (プロセス終了と同時に`-pictriEntitlement`指定値へ戻る、表示専用の上書き)。
    func debugSetTier(_ newTier: QuestEntitlementTier) {
        tier = newTier
    }
    #endif
}

// MARK: - Daily Capture Allowance
//
// 正式Product Requirement:
// FREE = 1日3 Memoryまで保存可能。PREMIUM = 1日の保存数無制限。
// 「1 Memory」= 外カメラ+内カメラの1セットを実際にQuestMemoryStore.saveまで
// 完了させた回数。shutterを押しただけ・撮り直しでは消費しない(CameraViewの
// reviewViewで「これにする」を押した時だけrecordCaptureSaved()を呼ぶ)。
//
// QuestMemoryStore.memoryPhotos.countから逆算しない。
// 「保存後にMemoryを削除しても、その日の枠は戻さない」という仕様のため、
// Memory一覧(削除されうる)とは独立したsource of truthとして
// 「保存に成功した回数」だけを別に永続化する(UserDefaults、日付キー付き)。
final class QuestDailyCaptureAllowance: ObservableObject {
    static let freeDailyLimit = 3

    @Published private(set) var usedToday: Int

    private let usedKey = "quest_daily_capture_used"
    private let dayKey = "quest_daily_capture_day"

    /// `-pictriDailyCaptureUsed`が指定されている間は「表示専用の上書き」を最優先し、
    /// 日付境界の自己修復(scheduleRefreshIfNewDay)を一切走らせない。この一致確認を
    /// 端末側のUserDefaults永続dayKeyだけで行うと、新規インストール直後は
    /// dayKeyが未設定(nil)のため「日付が変わった」と誤判定し、
    /// override値を0で即座に上書きしてしまう実害があったため、専用フラグで
    /// override中は完全にbypassする。
    private let isDebugOverrideActive: Bool

    init() {
        #if DEBUG
        if let seeded = PictriVisualReview.dailyCaptureUsedOverride {
            usedToday = seeded
            isDebugOverrideActive = true
            return
        }
        #endif
        isDebugOverrideActive = false

        if UserDefaults.standard.string(forKey: dayKey) == Self.todayString() {
            usedToday = UserDefaults.standard.integer(forKey: usedKey)
        } else {
            usedToday = 0
        }
    }

    /// nil = 無制限(PREMIUM)。FREEはあと何回撮れるか(0以上)。
    /// Core Invariant 7「device local dayが変わればFREE quotaは3へ戻る」の自己修復を
    /// スケジュールする(即座にはusedTodayを書き換えない――SwiftUIのView body評価中に
    /// @Publishedプロパティを同期的に変更すると「Publishing changes from within view
    /// updates is not allowed」となり、dayKey更新を伴わない素朴な実装では読み取りの
    /// たびに再発火して無限更新ループになる実害を確認したため、必ず次のrun loopへ
    /// 遅延させ、かつ一度直したらdayKeyを即座に永続化して再発火しないようにする)。
    func remaining(tier: QuestEntitlementTier) -> Int? {
        scheduleRefreshIfNewDay()
        guard tier == .free else { return nil }
        return max(Self.freeDailyLimit - usedToday, 0)
    }

    func canCapture(tier: QuestEntitlementTier) -> Bool {
        guard let remaining = remaining(tier: tier) else { return true }
        return remaining > 0
    }

    /// Memoryとして保存が完了した直後にだけ呼ぶ。device local dayが変わっていれば
    /// 先に0へリセットしてからカウントする(local day単位のreset)。
    func recordCaptureSaved() {
        refreshIfNewDay()
        usedToday += 1
        UserDefaults.standard.set(Self.todayString(), forKey: dayKey)
        UserDefaults.standard.set(usedToday, forKey: usedKey)
    }

    private func scheduleRefreshIfNewDay() {
        guard !isDebugOverrideActive else { return }
        guard UserDefaults.standard.string(forKey: dayKey) != Self.todayString() else { return }
        DispatchQueue.main.async { [weak self] in
            self?.refreshIfNewDay()
        }
    }

    /// 永続化済みのdayKeyが「今日」と一致しなければusedTodayを0へ戻す。dayKey/usedKeyを
    /// その場で永続化することで、以後の呼び出しはguardで即returnする(冪等)。
    private func refreshIfNewDay() {
        guard UserDefaults.standard.string(forKey: dayKey) != Self.todayString() else { return }
        usedToday = 0
        UserDefaults.standard.set(Self.todayString(), forKey: dayKey)
        UserDefaults.standard.set(0, forKey: usedKey)
    }

    /// `-pictriDailyCaptureDay <yyyy-MM-dd>` で「device local dayがどの日か」をDEBUG限定で
    /// 上書きする。実機の時計を変更せずに「同日は維持・翌日はreset」の日付境界QAを行うため
    /// (Calendar/Dateを実装全体に注入する大掛かりな構造にはしていない、この1点だけの
    /// 最小フック)。
    private static func todayString() -> String {
        #if DEBUG
        if let override = PictriVisualReview.dailyCaptureDayOverride {
            return override
        }
        #endif
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
