import SwiftUI
import PhotosUI

/// Result of one AI critique, handed off to `CritiqueResultView`.
struct CritiqueResultPayload: Identifiable, Hashable {
    let id = UUID()
    let referenceJPEG: Data
    let sketchJPEG: Data
    let feedback: [ProportionFeedback]
}

/// Pro screen: capture (or pick) a reference photo and a photo of the finished
/// sketch, then submit both to the AI proxy for a proportion critique.
struct CritiqueFlowView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var appModel: AppModel

    @State private var referenceData: Data?
    @State private var sketchData: Data?
    @State private var referencePickerItem: PhotosPickerItem?
    @State private var activeCaptureRole: PhotoRole?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var resultPayload: CritiqueResultPayload?
    @State private var showPaywall = false

    var body: some View {
        Group {
            if store.isPro {
                flow
            } else {
                gate
            }
        }
        .background(VantageColor.paper.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .fullScreenCover(item: $activeCaptureRole) { role in
            PhotoCaptureSheet(title: role == .reference ? "Reference Photo" : "Your Sketch") { data in
                switch role {
                case .reference: referenceData = data
                case .sketch: sketchData = data
                }
            }
        }
        .navigationDestination(item: $resultPayload) { payload in
            CritiqueResultView(payload: payload)
        }
        .onChange(of: referencePickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    referenceData = data
                }
            }
        }
    }

    private var gate: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(VantageColor.pencilRed)
            Text("Vantage Pro")
                .font(VantageFont.title(22))
                .foregroundStyle(VantageColor.ink)
            Text("AI proportion critique, session history, and the ghost-limb correction overlay.")
                .font(.subheadline)
                .foregroundStyle(VantageColor.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Unlock Vantage Pro — \(store.displayPrice)/mo") {
                Haptics.tap()
                showPaywall = true
            }
            .squareButton(tint: VantageColor.pencilRed)
            .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private var flow: some View {
        ScrollView {
            VStack(spacing: 18) {
                photoSlot(
                    title: "Reference",
                    subtitle: "The photo you're sketching from.",
                    data: referenceData,
                    onCamera: { activeCaptureRole = .reference },
                    picker: true
                )
                photoSlot(
                    title: "Your Sketch",
                    subtitle: "Photograph your finished (or in-progress) sketch on paper.",
                    data: sketchData,
                    onCamera: { activeCaptureRole = .sketch },
                    picker: false
                )

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Comparing Proportions…" : "Get AI Critique")
                    }
                    .frame(maxWidth: .infinity)
                }
                .squareButton(tint: VantageColor.pencilRed)
                .disabled(referenceData == nil || sketchData == nil || isSubmitting)
                .padding(.horizontal, 16)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(VantageColor.pencilRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private func photoSlot(title: String, subtitle: String, data: Data?, onCamera: @escaping () -> Void, picker: Bool) -> some View {
        DraftPanel {
            TickLabel(text: title)
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(Rectangle().strokeBorder(VantageColor.hairline, lineWidth: 1))
            } else {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(VantageColor.inkMuted)
            }
            HStack(spacing: 10) {
                Button(data == nil ? "Camera" : "Retake") { onCamera() }
                    .squareButton(filled: false, tint: VantageColor.ink)
                if picker {
                    PhotosPicker(selection: $referencePickerItem, matching: .images) {
                        Text("Photo Library")
                            .font(VantageFont.headline())
                            .foregroundStyle(VantageColor.ink)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
                            .overlay(Rectangle().strokeBorder(VantageColor.ink, lineWidth: 1.4))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func submit() async {
        guard let referenceData, let sketchData else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let client = AIProxyClient()
            let feedback = try await client.critique(referencePhoto: referenceData, sketchPhoto: sketchData)
            let refJPEG = AIProxyClient.preparedJPEG(from: referenceData)
            let sketchJPEG = AIProxyClient.preparedJPEG(from: sketchData)
            appModel.saveSession(referenceJPEG: refJPEG, sketchJPEG: sketchJPEG, feedback: feedback)
            Haptics.success()
            resultPayload = CritiqueResultPayload(referenceJPEG: refJPEG, sketchJPEG: sketchJPEG, feedback: feedback)
        } catch {
            Haptics.warning()
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
        }
        isSubmitting = false
    }
}
