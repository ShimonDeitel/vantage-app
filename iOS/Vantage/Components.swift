import SwiftUI
import UIKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func click() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// A single row in the AI-critique feedback list — the only place besides the
/// ghost-limb overlay that shows the pencil-red accent, marked with a small tick.
struct FeedbackRow: View {
    let feedback: ProportionFeedback

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(VantageColor.pencilRed)
                .frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.part.uppercased())
                    .font(VantageFont.caption())
                    .tracking(1.2)
                    .foregroundStyle(VantageColor.pencilRed)
                Text(feedback.message)
                    .font(VantageFont.body())
                    .foregroundStyle(VantageColor.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

/// A locked Pro feature row on the home screen — tapping when not subscribed opens
/// the paywall.
struct ProToolRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(locked ? VantageColor.inkMuted : VantageColor.pencilRed)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(VantageFont.headline(15)).foregroundStyle(VantageColor.ink)
                    Text(subtitle).font(.footnote).foregroundStyle(VantageColor.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: locked ? "lock.fill" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VantageColor.inkMuted)
            }
            .padding(14)
            .background(VantageColor.panel)
            .overlay(Rectangle().strokeBorder(VantageColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A thumbnail-plus-caption card for the session history list.
struct SessionRow: View {
    let session: CritiqueSessionSummary

    var body: some View {
        HStack(spacing: 12) {
            if let image = UIImage(data: session.sketchThumbnail) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipped()
                    .overlay(Rectangle().strokeBorder(VantageColor.hairline, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(session.createdAt, style: .date)
                    .font(VantageFont.headline(14))
                    .foregroundStyle(VantageColor.ink)
                Text(session.topFeedback ?? "No discrepancies over threshold")
                    .font(.footnote)
                    .foregroundStyle(VantageColor.inkMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Text("\(session.feedbackCount)")
                .font(VantageFont.value(14))
                .foregroundStyle(VantageColor.pencilRed)
        }
        .padding(10)
        .background(VantageColor.panel)
        .overlay(Rectangle().strokeBorder(VantageColor.hairline, lineWidth: 1))
    }
}
