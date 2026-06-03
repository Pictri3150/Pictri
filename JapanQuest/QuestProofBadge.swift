import SwiftUI

enum QuestProofBadgeStyle {
    case dark
    case light
}

struct QuestProofBadge: View {
    let status: QuestVerificationStatus
    let distanceMeters: Double?
    let style: QuestProofBadgeStyle

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.iconName)
                .font(.system(size: 11, weight: .bold))

            Text(status.label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))

            if let distanceMeters, status == .verified {
                Text(distanceText(distanceMeters))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .opacity(0.72)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .dark:
            switch status {
            case .verified:
                return .white.opacity(0.92)
            case .developer:
                return .white.opacity(0.20)
            case .unverified, .unknown:
                return .black.opacity(0.38)
            }

        case .light:
            switch status {
            case .verified:
                return .black
            case .developer:
                return .black.opacity(0.12)
            case .unverified, .unknown:
                return .black.opacity(0.06)
            }
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .dark:
            switch status {
            case .verified:
                return .black
            case .developer, .unverified, .unknown:
                return .white
            }

        case .light:
            switch status {
            case .verified:
                return .white
            case .developer, .unverified, .unknown:
                return .black.opacity(0.70)
            }
        }
    }

    private var borderColor: Color {
        switch style {
        case .dark:
            return .white.opacity(0.20)
        case .light:
            return .black.opacity(0.08)
        }
    }

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        } else {
            return "\(Int(meters))m"
        }
    }
}
