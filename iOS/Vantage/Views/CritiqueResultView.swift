import SwiftUI

/// Shows the AI critique's feedback list and the entry point to the ghost-limb
/// correction overlay (the quirky feature).
struct CritiqueResultView: View {
    let payload: CritiqueResultPayload
    @State private var showGhostLimb = false

    private var marks: [CorrectionMark] {
        ProportionComparator.correctionMarks(from: payload.feedback)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                photoComparison

                DraftPanel {
                    TickLabel(text: "AI Critique")
                    if payload.feedback.isEmpty {
                        Text("No proportion differences over the flagged threshold. This sketch reads close to the reference.")
                            .font(.subheadline)
                            .foregroundStyle(VantageColor.inkMuted)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(payload.feedback) { item in
                                FeedbackRow(feedback: item)
                                if item.id != payload.feedback.last?.id {
                                    Rectangle().fill(VantageColor.hairline).frame(height: 1)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                if !marks.isEmpty {
                    Button {
                        Haptics.tap()
                        showGhostLimb = true
                    } label: {
                        Label("Show Ghost-Limb Correction Overlay", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .squareButton(tint: VantageColor.pencilRed)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 20)
        }
        .background(VantageColor.paper.ignoresSafeArea())
        .navigationTitle("Critique")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showGhostLimb) {
            GhostLimbOverlayView(sketchJPEG: payload.sketchJPEG, marks: marks)
        }
    }

    private var photoComparison: some View {
        HStack(spacing: 10) {
            photoThumb(payload.referenceJPEG, caption: "Reference")
            photoThumb(payload.sketchJPEG, caption: "Your Sketch")
        }
        .padding(.horizontal, 16)
    }

    private func photoThumb(_ data: Data, caption: String) -> some View {
        VStack(spacing: 6) {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(Rectangle().strokeBorder(VantageColor.hairline, lineWidth: 1))
            }
            TickLabel(text: caption)
        }
    }
}
