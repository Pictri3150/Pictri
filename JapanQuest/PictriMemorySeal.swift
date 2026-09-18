import SwiftUI

// MARK: - Memory Seal & Comment Note Tag(v4: Card統合)
//
// v4 CARD-INTEGRATED ACTIONS: 「Cardから独立したtileに見える」という指摘を
// 受け、Like(Seal)/Comment(Note Tag)は`PictriHomeMemoryCard`自身のoverlayへ
// 統合し直した(旧`PictriHomeActionRow`はHome側の独立行として存在したが、
// 使用箇所が無くなったため削除した)。Instagram的な横並びiconや、参考画像の
// neon pink-purpleなグロー加工はどちらも避け、抑えたテラコッタaccent
// (既存`accent`と同じ#D97757)と、matte graphiteな物体で「可愛いが
// 子どもっぽくない」を狙う。Like=円形のseal/token、Comment=角の一部を欠いた
// note tagという、互いに異なる形状にして双子square感を排除している。
/// v8 REFERENCE FIDELITY SOCIAL: Referenceの「Like+count | divider |
/// Comment+countが1つのdark capsuleとしてHeroへ統合されている」構成を
/// 実装した候補(SOCIAL B/C)。過去ラウンドで確定していた「Like左/Comment右
/// separate」は今回のuser要求(Referenceへ限界まで寄せる)を優先して
/// 再検討対象にした。
struct PictriMemorySocialCapsule: View {
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    let onLike: () -> Void
    let onOpenComments: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onLike) {
                HStack(spacing: 5) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        // v8.2: Like activeを旧terracottaからHome brand accent
                        // (muted lavender)へ。派手な紫Heartにならないよう、
                        // 既存のsize/weightはそのまま、色のみ置き換えている。
                        .foregroundStyle(isLiked ? PictriHomeBrandAccent.accent : Color.white.opacity(0.92))
                    Text("\(likeCount)")
                        .font(PictriTypography.mono(11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .monospacedDigit()
                }
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .frame(height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(PictriSocialButtonStyle())
            .accessibilityLabel(isLiked ? "いいねを取り消す" : "いいねする")
            .accessibilityValue("\(likeCount)件")

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 1, height: 16)

            Button(action: onOpenComments) {
                HStack(spacing: 5) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Text("\(commentCount)")
                        .font(PictriTypography.mono(11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .monospacedDigit()
                }
                .padding(.leading, 12)
                .padding(.trailing, 14)
                .frame(height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(PictriSocialButtonStyle())
            .accessibilityLabel("コメントを開く")
            .accessibilityValue(commentCount == 0 ? "コメントなし" : "\(commentCount)件")
        }
        .frame(height: 38)
        .background(capsuleSurface)
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
        }
        .shadow(color: Color.black.opacity(0.38), radius: 8, x: 0, y: 4)
    }

    /// v6 TASK5 SOCIAL CAPSULE: 旧`Capsule().fill(Color.black.opacity(0.36))`
    /// (単色フラット) + white 1pt strokeは「generic dark pill」に見えていた。
    /// iOS 26 Liquid Glass(`glassEffect`、Dockと同じAPI・Deployment Target
    /// 26.4で利用可能)へ置き換え、写真を完全に隠さない薄い黒tintの光学的な
    /// 素材にした。`interactive()`は採用しなかった(Glass自身の押下反応と、
    /// 下記`PictriSocialButtonStyle`のscale/opacity反応が二重に効いて
    /// 挙動が読みにくくなるリスクを避け、Dockの`PictriCameraButtonStyle`と
    /// 同じ「自前ButtonStyleで統一する」方式に揃えた)。iOS 26未満では
    /// 旧来のflat fillへfallbackする。
    @ViewBuilder
    private var capsuleSurface: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.tint(Color.black.opacity(0.30)), in: Capsule())
        } else {
            Capsule().fill(Color.black.opacity(0.36))
        }
    }
}

/// v6 TASK6 INTERACTION STATES: Like/Comment個別に「press中はわずかに
/// 縮んで沈む」フィードバックを追加(旧`.buttonStyle(.plain)`はpress
/// フィードバックが無く、静止画のままだった)。Dockの`PictriCameraButtonStyle`
/// と同じ語彙(scale + opacity、spring)に揃え、「同じMaterial universe」に
/// 属する操作感にする。強いlavender発光等は使わない。
private struct PictriSocialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Comment Note Scrim

struct PictriCommentNoteScrim: View {
    let onTap: () -> Void
    var body: some View {
        Color.black.opacity(0.55)
            .ignoresSafeArea()
            .onTapGesture(perform: onTap)
            .transition(.opacity)
    }
}

// MARK: - Comment Note Sheet
//
// SIGNATURE PHYSICAL WORLD CLOSURE: 「画面下からのbottom sheet」に見える
// 問題を是正。System sheetの定番である「edge-to-edge幅+中央drag handle
// capsule」を両方やめ、
// 1) NoteはCardと同じ横幅程度に留め、左右に黒を残す(=画面全体の帯ではなく
//    「Cardに付属する紙片」に見せる)、
// 2) 四隅を均一に丸めず、右上だけ小さい半径にして通常のsheetと違う
//    「一枚の紙」のシルエットにする、
// 3) 中央drag handleを廃し、右上に小さなcloseボタンだけを置く、
// という3点で対応した。Card自体はHomeView側で開閉に合わせて8pt持ち上がり、
// Noteは画面最下端からではなくCardのすぐ下から現れる(HomeView側のoffset/
// 配置と連動)。
//
// 2案比較: A)非対称の角(採用) B)全体を-1.1度傾けた「photographic note」風。
// Bは実機で見ると「一枚の紙が斜めに置かれている」というより「表示が
// ずれている」ように見えるリスクがあり、tap領域(closeボタン・composer)も
// 斜めになって触りにくくなるため不採用とした。高級写真集の付箋程度の
// 品位を保つにはAの静かな非対称の方が適切と判断。
struct PictriCommentNoteSheet: View {
    let post: QuestFeedPost
    let comments: [PictriHomeComment]
    let onSubmit: (String) -> Void
    let onClose: () -> Void
    /// `-pictriHomeCommentsAutoFocus true` QAスクショ専用。keyboard表示状態を
    /// tapなしで確認するため(通常操作では常にfalse)。
    var autoFocusComposer: Bool = false

    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 20,
            bottomTrailingRadius: 20,
            topTrailingRadius: 7,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("コメント")
                        .font(PictriTypography.mono(10.5, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.42))

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if comments.isEmpty {
                            Text("まだコメントはありません")
                                .font(PictriTypography.body(13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.vertical, 6)
                        } else {
                            ForEach(comments) { comment in
                                commentRow(comment)
                            }
                        }
                    }
                }
                .frame(maxHeight: 180)

                composer
                    .padding(.top, 12)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
            .background(PictriCommentNoteTheme.surface)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(PictriCommentNoteTheme.rim, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 26, x: 0, y: 10)
            .frame(maxWidth: 340)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if autoFocusComposer {
                isComposerFocused = true
            }
        }
    }

    private func commentRow(_ comment: PictriHomeComment) -> some View {
        let name = Text(comment.username)
            .font(PictriTypography.body(13, weight: .bold))
            .foregroundStyle(.white)
        return Text("\(name) \(comment.text)")
            .font(PictriTypography.body(13, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 通常のchat input barではなく、Note用紙の最下部に引かれた1本の細い罫線+
    /// placeholderという体裁にした(pill型backgroundやglass capsuleは使わない)。
    private var composer: some View {
        HStack(spacing: 8) {
            TextField("コメントを書く", text: $draft)
                .font(PictriTypography.body(13, weight: .medium))
                .foregroundStyle(.white)
                .tint(PictriFinalTheme.accent)
                .focused($isComposerFocused)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isDraftEmpty ? Color.white.opacity(0.28) : PictriFinalTheme.accent)
            }
            .disabled(isDraftEmpty)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
        }
    }

    private var isDraftEmpty: Bool {
        draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        draft = ""
    }
}

enum PictriCommentNoteTheme {
    static var surface: Color { PictriDarkTheme.surfaceOverlay }
    static var rim: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
