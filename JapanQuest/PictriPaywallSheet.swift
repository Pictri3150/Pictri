import SwiftUI

// MARK: - Pictri Paywall
//
// Product Requirement(今回追加): 課金導線は「FREEユーザーが4回目を撮影しようとした
// とき」と「Premium AI Vlogを生成しようとしたとき」の2箇所に限定する。アプリ起動直後や
// Memories Collectを見るだけではpaywallを出さない(このsheetはCameraView/Vlog側の
// 明示的なCTAからだけ.sheet(isPresented:)で開く)。
//
// 実StoreKit(課金)基盤はこのプロジェクトに存在しないことを確認済み(監査済み)。
// 今回は本格的なStoreKit導入をせず、Paywallの見た目とtier切り替えの入口だけを
// 最小構成で用意する。DEBUGビルドでは「Premiumにする」ボタンがQuestEntitlementStoreの
// tierをその場でpremiumへ切り替える(free/premiumをtap 1つでQAできるようにするため)。
// RELEASEビルドでは同じボタンは何も購入完了させない(fake purchase resultを出さない)
// ——実際の購入フローへの接続は今回のスコープ外として明示的に残す。
struct PictriPaywallSheet: View {
    @ObservedObject var entitlementStore: QuestEntitlementStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PictriFinalTheme.ink)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("閉じる")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Premium")
                    .font(PictriTypography.display(22))
                    .foregroundStyle(PictriFinalTheme.ink)

                Text("1日の撮影回数が無制限になります")
                    .font(PictriTypography.body(13, weight: .medium))
                    .foregroundStyle(PictriFinalTheme.inkSoft)
            }

            // Visual Foundation Part C。以前はcheckmark+平文の素朴な箇条書きで、
            // 「よくあるSaaSの価格表」に見えていた。紙のパネルへ収め、各行に
            // secondaryアクセント色の柔らかいバッジを添えることで、装飾を増やさずに
            // Homeと地続きの「紙の上の質感」へ寄せた(構造・コピー・購入ロジックは無変更)。
            VStack(alignment: .leading, spacing: 14) {
                paywallLine(icon: "infinity", text: "1日の撮影・保存が無制限", accent: PictriFinalTheme.secondarySoftAmber)
                paywallLine(icon: "sparkles", text: "撮った写真からVlogを自動でつくる", accent: PictriFinalTheme.secondaryMint)
            }
            .padding(16)
            .background(PictriFinalTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PictriFinalTheme.radiusGroupedBlock, style: .continuous)
                    .stroke(PictriFinalTheme.line, lineWidth: 1)
            }

            Spacer(minLength: 0)

            Button {
                #if DEBUG
                entitlementStore.debugSetTier(.premium)
                #endif
                // TODO: 実際のStoreKit購入フローに接続する(今回スコープ外)。
                // 実billing基盤が無いため、RELEASEビルドではここでtierを変更しない
                // (「できたふり」を避けるため、購入未実装の状態を正直に保つ)。
                dismiss()
            } label: {
                Text("Premiumにする")
                    .font(PictriTypography.body(15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(PictriFinalTheme.onAccent)
                    .background(PictriFinalTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, JQUI.sidePadding)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .background(PictriFinalTheme.paper.ignoresSafeArea())
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    private func paywallLine(icon: String, text: String, accent: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                }
                .accessibilityHidden(true)

            Text(text)
                .font(PictriTypography.body(13, weight: .medium))
                .foregroundStyle(PictriFinalTheme.ink)
        }
    }
}
