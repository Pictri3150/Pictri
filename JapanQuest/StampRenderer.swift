import UIKit

enum StampRenderer {
    static func render(image: UIImage, spot: Spot) -> UIImage {
        let fixedImage = image.fixedOrientation()
        let size = fixedImage.size

        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            fixedImage.draw(in: CGRect(origin: .zero, size: size))

            let scale = min(size.width, size.height) / 1000

            let stampWidth = size.width * 0.36
            let stampHeight = size.height * 0.11
            let padding = 34 * scale

            let stampRect = CGRect(
                x: size.width - stampWidth - padding,
                y: size.height - stampHeight - padding,
                width: stampWidth,
                height: stampHeight
            )

            let path = UIBezierPath(
                roundedRect: stampRect,
                cornerRadius: 30 * scale
            )

            UIColor.black.withAlphaComponent(0.72).setFill()
            path.fill()

            UIColor.white.withAlphaComponent(0.9).setStroke()
            path.lineWidth = 3 * scale
            path.stroke()

            let title = spot.stampText
            let subtitle = formattedDate()

            let titleFont = UIFont.systemFont(
                ofSize: 42 * scale,
                weight: .heavy
            )

            let subtitleFont = UIFont.systemFont(
                ofSize: 24 * scale,
                weight: .semibold
            )

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]

            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.78)
            ]

            let titleRect = CGRect(
                x: stampRect.minX + 24 * scale,
                y: stampRect.minY + 17 * scale,
                width: stampRect.width - 48 * scale,
                height: 52 * scale
            )

            let subtitleRect = CGRect(
                x: stampRect.minX + 24 * scale,
                y: stampRect.minY + 66 * scale,
                width: stampRect.width - 48 * scale,
                height: 34 * scale
            )

            title.draw(in: titleRect, withAttributes: titleAttributes)
            subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
        }
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: Date())
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
