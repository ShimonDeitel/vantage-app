import SwiftUI

/// Pro screen: every past critique session, most recent first. Tapping one reopens
/// the same result view (feedback list + ghost-limb overlay) used right after a
/// fresh critique.
struct SessionHistoryView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel

    @State private var sessions: [CritiqueSession] = []
    @State private var selectedPayload: CritiqueResultPayload?
    @State private var showPaywall = false

    var body: some View {
        Group {
            if !store.isPro {
                gate
            } else if sessions.isEmpty {
                empty
            } else {
                list
            }
        }
        .background(VantageColor.paper.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .navigationDestination(item: $selectedPayload) { payload in
            CritiqueResultView(payload: payload)
        }
        .onAppear { reload() }
    }

    private var gate: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(VantageColor.inkMuted)
            Text("Session history is a Vantage Pro feature.")
                .font(.subheadline)
                .foregroundStyle(VantageColor.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Unlock Vantage Pro — \(store.displayPrice)/mo") {
                showPaywall = true
            }
            .squareButton(tint: VantageColor.pencilRed)
            .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(VantageColor.inkMuted)
            Text("No critiques yet.")
                .font(.subheadline)
                .foregroundStyle(VantageColor.inkMuted)
            Spacer()
            Spacer()
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(sessions) { session in
                    Button {
                        selectedPayload = CritiqueResultPayload(
                            referenceJPEG: session.referenceJPEG,
                            sketchJPEG: session.sketchJPEG,
                            feedback: session.feedback
                        )
                    } label: {
                        SessionRow(session: CritiqueSessionSummary(session: session))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) { delete(session) }
                    }
                }
            }
            .padding(16)
        }
    }

    private func reload() {
        sessions = appModel.sessions()
    }

    private func delete(_ session: CritiqueSession) {
        appModel.deleteSession(session)
        reload()
    }
}
