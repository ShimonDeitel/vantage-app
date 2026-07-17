import SwiftUI

struct RootView: View {
    @AppStorage("vantage.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                OverlayCameraView()
                    .navigationTitle("Vantage")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label("Overlay", systemImage: "viewfinder") }

            NavigationStack {
                CritiqueFlowView()
                    .navigationTitle("Critique")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label("Critique", systemImage: "pencil.and.outline") }

            NavigationStack {
                SessionHistoryView()
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .tint(VantageColor.graphite)
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.tap()
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
    }
}
