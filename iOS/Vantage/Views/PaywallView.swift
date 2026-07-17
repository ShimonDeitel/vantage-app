import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var restoreMessage: String?

    private let benefits: [(String, String, String)] = [
        ("wand.and.stars", "AI proportion critique", "Photograph your reference and your sketch — get the real percentage difference on each measurement, not a vague note."),
        ("clock.arrow.circlepath", "Session history", "Every critique is saved on-device: photos, feedback, and the date."),
        ("scribble.variable", "Ghost-limb correction overlay", "The corrected proportions drawn in red pencil, right on top of your own sketch photo."),
    ]

    var body: some View {
        ZStack {
            VantageColor.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(VantageColor.pencilRed)
                        Text("Vantage Pro").font(VantageFont.title(28))
                            .foregroundStyle(VantageColor.ink)
                        Text("\(store.displayPrice) / month. Cancel anytime.")
                            .font(.subheadline).foregroundStyle(VantageColor.inkMuted)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(benefits, id: \.0) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.0)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(VantageColor.pencilRed)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(VantageFont.headline(16))
                                        .foregroundStyle(VantageColor.ink)
                                    Text(item.2).font(.subheadline).foregroundStyle(VantageColor.inkMuted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(16)
                    .background(VantageColor.panel)
                    .overlay(Rectangle().strokeBorder(VantageColor.hairline, lineWidth: 1))
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button {
                            Task { await buy() }
                        } label: {
                            HStack {
                                if working { ProgressView().tint(.white) }
                                Text(working ? "Starting…" : "Start Vantage Pro · \(store.displayPrice)/mo")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .squareButton(tint: VantageColor.pencilRed)
                        .accessibilityIdentifier("paywall-subscribe")
                        .disabled(working)

                        Button("Restore Purchase") { Task { await restore() } }
                            .font(.subheadline).tint(VantageColor.inkMuted)

                        if let restoreMessage {
                            Text(restoreMessage).font(.footnote).foregroundStyle(VantageColor.inkMuted)
                        }

                        Text("Auto-renewable subscription, billed monthly to your Apple ID. Manage or cancel anytime in Settings.")
                            .font(.footnote).foregroundStyle(VantageColor.inkMuted)
                            .multilineTextAlignment(.center).padding(.top, 4)
                    }
                    .padding(.horizontal).padding(.bottom, 30)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(VantageColor.inkMuted).padding()
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("paywall-close")
        }
        .onChange(of: store.isPro) { _, newValue in if newValue { dismiss() } }
    }

    private func buy() async {
        working = true
        let ok = await store.purchase()
        working = false
        if ok { Haptics.success(); dismiss() }
    }

    private func restore() async {
        await store.restore()
        if store.isPro { Haptics.success(); dismiss() }
        else { restoreMessage = "No previous purchase found on this Apple ID." }
    }
}
