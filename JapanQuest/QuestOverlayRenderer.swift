import UIKit

enum QuestOverlayRenderer {
    static func render(image: UIImage, spot: QuestSpot) -> UIImage {
        let fixedImage = normalizedImage(image)
        let size = fixedImage.size

        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            fixedImage.draw(in: CGRect(origin: .zero, size: size))

            let scale = min(size.width, size.height) / 1000

            let dateText = formattedDate()
            let placeText = spot.englishName.lowercased()

            let horizontalPadding = 42 * scale
            let verticalPadding = 28 * scale

            let boxWidth = size.width * 0.58
            let boxHeight = 132 * scale

            let boxRect = CGRect(
                x: 42 * scale,
                y: size.height - boxHeight - 72 * scale,
                width: boxWidth,
                height: boxHeight
            )

            let boxPath = UIBezierPath(
                roundedRect: boxRect,
                cornerRadius: 20 * scale
            )

            UIColor.white.withAlphaComponent(0.18).setFill()
            boxPath.fill()

            UIColor.white.withAlphaComponent(0.36).setStroke()
            boxPath.lineWidth = 2 * scale
            boxPath.stroke()

            let dateFont = UIFont.monospacedDigitSystemFont(
                ofSize: 36 * scale,
                weight: .semibold
            )

            let placeFont = UIFont.monospacedSystemFont(
                ofSize: 42 * scale,
                weight: .bold
            )

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = 8 * scale
            shadow.shadowOffset = CGSize(width: 0, height: 2 * scale)

            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: dateFont,
                .foregroundColor: UIColor.white,
                .shadow: shadow
            ]

            let placeAttributes: [NSAttributedString.Key: Any] = [
                .font: placeFont,
                .foregroundColor: UIColor.white,
                .shadow: shadow
            ]

            dateText.draw(
                in: CGRect(
                    x: boxRect.minX + horizontalPadding,
                    y: boxRect.minY + verticalPadding,
                    width: boxRect.width - horizontalPadding * 2,
                    height: 42 * scale
                ),
                withAttributes: dateAttributes
            )

            placeText.draw(
                in: CGRect(
                    x: boxRect.minX + horizontalPadding,
                    y: boxRect.minY + verticalPadding + 48 * scale,
                    width: boxRect.width - horizontalPadding * 2,
                    height: 54 * scale
                ),
                withAttributes: placeAttributes
            )
        }
    }

    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: Date())
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        let renderer = UIGraphicsImageRenderer(size: image.size)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
