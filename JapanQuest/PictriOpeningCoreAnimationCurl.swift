import SwiftUI
import UIKit
import QuartzCore

// MARK: - Route B: Core Animation Prototype(Physical Peel Closure比較用)
//
// Route A(SwiftUI multi-strip + wordmark rigid decal)との比較のため、
// 同じ幾何・同じtiming・同じ「wordmarkは単一剛体としてのみ扱う」戦略を
// CALayer + CATransform3Dで再実装した最小Prototype。Opening Lab限定、
// Home/Camera等のProduction経路には一切接続しない(DEBUG比較用のみ)。

private func pictriRouteBPeelEasing(_ t: Double) -> Double {
    let c = min(max(t, 0), 1)
    if c < 0.15 {
        let l = c / 0.15
        return 0.05 * l * l
    } else if c < 0.85 {
        let l = (c - 0.15) / 0.70
        let s = l * l * l * (l * (l * 6 - 15) + 10)
        return 0.05 + 0.90 * s
    } else {
        let l = (c - 0.85) / 0.15
        return 0.95 + 0.05 * (1 - pow(1 - l, 2))
    }
}

final class PictriCurlCALayerView: UIView {
    private var stripLayers: [CALayer] = []
    private var wordmarkLayer: CALayer?
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval?

    private let stripCount = 7
    private let assemblyBaseDelay: CFTimeInterval = 0.40
    private let revealStart: CFTimeInterval = 1.90
    private let revealDuration: CFTimeInterval = 1.40
    private let totalDuration: CFTimeInterval = 3.55
    var onComplete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0x12 / 255, green: 0x12 / 255, blue: 0x14 / 255, alpha: 1)
        setupWordmark()
        setupStrips()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupWordmark() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 100))
        let img = renderer.image { _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Georgia", size: 38) ?? UIFont.systemFont(ofSize: 38),
                .foregroundColor: UIColor(red: 0xD6 / 255, green: 0xC7 / 255, blue: 0x9A / 255, alpha: 1)
            ]
            let str = NSAttributedString(string: "PicTri", attributes: attrs)
            let size = str.size()
            str.draw(at: CGPoint(x: (320 - size.width) / 2, y: (100 - size.height) / 2))
        }
        let layer = CALayer()
        layer.contents = img.cgImage
        layer.contentsGravity = .resizeAspect
        layer.contentsScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
        self.layer.addSublayer(layer)
        wordmarkLayer = layer
    }

    private func setupStrips() {
        for _ in 0..<stripCount {
            let l = CALayer()
            self.layer.addSublayer(l)
            stripLayers.append(l)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let wm = wordmarkLayer else { return }
        wm.bounds = CGRect(x: 0, y: 0, width: 240, height: 75)
        wm.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    @objc private func tick(_ link: CADisplayLink) {
        if startTime == nil { startTime = link.timestamp }
        let elapsed = link.timestamp - (startTime ?? link.timestamp)
        update(elapsed: elapsed)
        if elapsed >= totalDuration {
            displayLink?.invalidate()
            onComplete?()
        }
    }

    private func update(elapsed: CFTimeInterval) {
        let size = bounds.size
        guard size.width > 0 else { return }
        let progress = revealDuration > 0 ? min(max((elapsed - revealStart) / revealDuration, 0), 1) : 0
        let eased = pictriRouteBPeelEasing(progress)

        let nx: CGFloat = 0.7071, ny: CGFloat = 0.7071
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let halfDiagS = (size.width + size.height) / 2 * 0.7071 * 1.08
        let threshold = halfDiagS - CGFloat(eased) * 2 * halfDiagS
        let bandDepth: CGFloat = min(120, size.height * 0.12)
        let stripWidth = bandDepth / CGFloat(stripCount)
        let hugeSide = halfDiagS * 6
        let active = progress > 0.001 && progress < 0.999

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, l) in stripLayers.enumerated() {
            l.isHidden = !active
            guard active else { continue }
            let outerEdge = threshold - CGFloat(stripCount - 1 - i) * stripWidth
            let angleDeg: CGFloat = 80 * CGFloat(i + 1) / CGFloat(stripCount)
            let angleRad = angleDeg * .pi / 180
            let shade = 1.0 - 0.62 * (angleDeg / 80)

            l.backgroundColor = UIColor(white: shade * 0.09, alpha: 1).cgColor
            l.anchorPoint = CGPoint(x: 0.5, y: 1.0) // hinge at the near (still-flat) edge, not center
            l.bounds = CGRect(x: 0, y: 0, width: hugeSide, height: stripWidth + 4)

            var t = CATransform3DIdentity
            t.m34 = -1.0 / 1400
            t = CATransform3DRotate(t, 45 * .pi / 180, 0, 0, 1)
            t = CATransform3DRotate(t, angleRad, 1, 0, 0)
            l.transform = t

            let hingeS = outerEdge
            l.position = CGPoint(x: center.x + nx * hingeS, y: center.y + ny * hingeS)
        }

        if let wm = wordmarkLayer {
            let wordmarkHalfExtent: CGFloat = 78
            let crossT = 1 - min(max((threshold + wordmarkHalfExtent) / (2 * wordmarkHalfExtent), 0), 1)
            if crossT >= 0.999 {
                wm.isHidden = true
            } else {
                wm.isHidden = false
                wm.opacity = 1
                if crossT <= 0.001 {
                    wm.transform = CATransform3DIdentity
                } else {
                    var t = CATransform3DIdentity
                    t.m34 = -1.0 / 1400
                    t = CATransform3DRotate(t, 45 * .pi / 180, 0, 0, 1)
                    t = CATransform3DRotate(t, CGFloat(74 * crossT) * .pi / 180, 1, 0, 0)
                    t = CATransform3DRotate(t, -45 * .pi / 180, 0, 0, 1)
                    wm.transform = t
                    let shade = 1 - 0.5 * crossT
                    wm.opacity = Float(shade)
                }
            }
        }

        CATransaction.commit()
    }
}

struct PictriCALayerCurlRepresentable: UIViewRepresentable {
    var onComplete: () -> Void
    func makeUIView(context: Context) -> PictriCurlCALayerView {
        let v = PictriCurlCALayerView(frame: .zero)
        v.onComplete = onComplete
        return v
    }
    func updateUIView(_ uiView: PictriCurlCALayerView, context: Context) {}
}

/// Route B production wiring互換ラッパー(DEBUG比較用のみ)。
struct PictriPeelConceptRouteB_CoreAnimation: View {
    var onComplete: () -> Void
    var body: some View {
        PictriCALayerCurlRepresentable(onComplete: onComplete)
            .ignoresSafeArea()
            .statusBarHidden(true)
    }
}
