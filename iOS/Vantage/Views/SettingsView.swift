import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("vantage.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Vantage \(v)"
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                gridSection
                appearanceSection
                howItWorksSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(VantageColor.pencilRed)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Erase All Vantage Data?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) {
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes every saved critique session and resets settings. Vantage keeps no data anywhere else.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Vantage Pro", systemImage: "pencil.and.outline")
                    Spacer()
                    Text("Active").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Get Vantage Pro", systemImage: "pencil.and.outline")
                        Spacer()
                        Text("\(store.displayPrice)/mo").foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("AI proportion critique, session history, and the ghost-limb correction overlay.")
            }
        }
    }

    private var gridSection: some View {
        Section("Live Overlay") {
            Toggle("Show Proportion Grid", isOn: $appModel.showGrid)
            Stepper("Grid Divisions: \(appModel.gridDivisions)", value: $appModel.gridDivisions, in: AppModel.gridDivisionsRange)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var howItWorksSection: some View {
        Section {
            DisclosureGroup("How Vantage critiques a sketch") {
                Text("Vantage sends your reference photo and your sketch photo to the shared vision model separately, asking each time for a structured set of proportion ratios (head, shoulders, hips, arms, legs, torso, hands — each as a fraction of total height). It then computes the real percentage difference between the two sets itself, so the feedback is arithmetic, not a guess in prose.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button("Erase All Data", role: .destructive) { showDeleteConfirm = true }
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("Saved sessions (\(appModel.sessions().count)) live only in this app on this device. Reference and sketch photos are sent to the AI proxy only while a critique is running and are not stored on the server.")
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/vantage-app/privacy.html")!)
            Link("Terms of Use", destination: URL(string: "https://shimondeitel.github.io/vantage-app/terms.html")!)
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}
