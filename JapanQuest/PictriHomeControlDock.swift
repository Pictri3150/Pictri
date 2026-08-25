import SwiftUI

// MARK: - Home v8 — 3-CONTROL DOCK(REFERENCE FIDELITY FINAL CLOSURE)
//
// Reference(`/Users/takakikeita/Desktop/pictriimagehome_final.png`)のDockは
// 「棚に小さな隆起を足した」ものではなく、top edge全体が
// 肩(shoulder)→上昇→頂点(camera席)→下降→肩、という1本の連続した
// Bezier波形になっている。v7の`PictriHomeDockShape`(平らな辺+局所的な
// 小さいbump)はこの有機的な質感に届いていなかったため、今回は
// 2本のcubic Bezierをcenterで滑らかに繋ぐ形へ全面書き直した。
//
// 3候補比較(17 Pro Dark、実写真で比較):
// A) REFERENCE DIRECT(採用) — riseHeight大(28pt)・rise幅広(全体の60%)。
//    実写真で確認した結果、Map/Album直上も十分になだらかで操作性を
//    損なわず、Referenceの「肩→上昇→頂点→下降→肩」という連続した
//    波形に最も近かったため採用した。
// B) REFERENCE RESTRAINED — Aの曲率を約18%抑制(riseHeight23pt・
//    rise幅52%)。悪くはないが、Aと並べるとうねりが弱く、
//    Reference fidelityの観点でAに一歩譲る。
// C) ARCHITECTURAL — rise幅を26%まで狭めた急峻な案。実写真で見ると
//    「四角い板の中央に三角の切り欠きがある」ように見え、pagination
//    dotsとも視覚的に衝突し、Referenceの有機的な質感には程遠かった
//    ため不採用。
struct PictriHomeControlDock: View {
    let onMapTap: () -> Void
    let onCameraTap: () -> Void
    let onAlbumTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            dockItem(icon: "mappin.and.ellipse", label: "マップ", action: onMapTap)

            Button(action: onCameraTap) {
                PictriHomeDockCameraLens()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("カメラ")

            dockItem(icon: "photo.on.rectangle", label: "アルバム", action: onAlbumTap)
        }
        .padding(.horizontal, 10)
        .padding(.top, 26)
        .padding(.bottom, 10)
        .background(PictriHomeDockMaterial())
    }

    private func dockItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                Text(label)
                    .font(PictriTypography.body(9.5, weight: .bold))
            }
            .foregroundStyle(PictriDarkTheme.textFaint)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// REFERENCE RESTRAINED候補の土台形状。Top edgeを2本のcubic Bezierで
/// 「肩→上昇→頂点」「頂点→下降→肩」と連続させ、途中で曲率が折れないよう
/// 頂点前後の制御点を対称配置している(片方だけ急に曲がる、といういびつさを防ぐ)。
/// Bottom edgeもReferenceに合わせてごくわずかに丸め、完全な直角にしない。
private struct PictriHomeDockShape: Shape {
    /// 頂点の高さ(上へどれだけ盛り上がるか)。
    var riseHeight: CGFloat
    /// 肩から肩までの、盛り上がり区間が占める幅の割合(0〜1)。
    var riseWidthFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        let topRadius: CGFloat = 30
        let bottomRadius: CGFloat = 10
        let midX = rect.midX
        let halfRise = rect.width * riseWidthFraction / 2
        let leftShoulderX = midX - halfRise
        let rightShoulderX = midX + halfRise

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + topRadius))
        path.addArc(
            center: CGPoint(x: rect.minX + topRadius, y: rect.minY + topRadius),
            radius: topRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )

        path.addLine(to: CGPoint(x: leftShoulderX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: midX, y: rect.minY - riseHeight),
            control1: CGPoint(x: leftShoulderX + halfRise * 0.55, y: rect.minY),
            control2: CGPoint(x: midX - halfRise * 0.28, y: rect.minY - riseHeight)
        )
        path.addCurve(
            to: CGPoint(x: rightShoulderX, y: rect.minY),
            control1: CGPoint(x: midX + halfRise * 0.28, y: rect.minY - riseHeight),
            control2: CGPoint(x: rightShoulderX - halfRise * 0.55, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY))

        path.addArc(
            center: CGPoint(x: rect.maxX - topRadius, y: rect.minY + topRadius),
            radius: topRadius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY - bottomRadius),
            radius: bottomRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct PictriHomeDockMaterial: View {
    /// v8候補B(REFERENCE RESTRAINED)採用値。
    /// v8候補A(REFERENCE DIRECT)採用値。
    private let shape = PictriHomeDockShape(riseHeight: 28, riseWidthFraction: 0.60)

    var body: some View {
        shape
            .fill(PictriDarkTheme.surfaceOverlay.opacity(0.92))
            .background { shape.fill(PictriDarkTheme.glassMaterial) }
            .overlay {
                shape.stroke(
                    LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(0.45), radius: 22, x: 0, y: 12)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
    }
}

/// Camera lens object。Referenceのように「Dockの座から生えたlens」を
/// dock surface→camera seat(沈んだ土台)→outer ring→warm lens surface→
/// glyphの5層で構成する。Glowは使わず、layerごとの明暗差だけで
/// 立体感を出す。
private struct PictriHomeDockCameraLens: View {
    var body: some View {
        ZStack {
            // camera seat: dockの面へ沈んだ窪み
            Circle()
                .fill(PictriDarkTheme.surfaceBase.opacity(0.75))
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1.5)
                }
                .frame(width: 64, height: 64)

            // outer ring: seatとlensの間の中間リング
            Circle()
                .fill(PictriDarkTheme.surfaceOverlay.opacity(0.9))
                .frame(width: 52, height: 52)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }

            // warm lens surface
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PictriDarkTheme.accent.opacity(1.0), PictriDarkTheme.accent.opacity(0.82)],
                        center: UnitPoint(x: 0.36, y: 0.30),
                        startRadius: 2,
                        endRadius: 26
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    Circle()
                        .trim(from: 0.52, to: 0.98)
                        .stroke(Color.white.opacity(0.38), lineWidth: 1.2)
                        .rotationEffect(.degrees(-90))
                }
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.75)
                }
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(PictriDarkTheme.onAccent)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .offset(y: -18)
        .contentShape(Rectangle())
    }
}
