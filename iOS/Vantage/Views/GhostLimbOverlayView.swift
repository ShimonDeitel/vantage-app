import SwiftUI

/// The quirky feature: after AI critique, the corrected proportions are redrawn as
/// faint translucent red-pencil correction marks directly on top of the user's own
/// sketch photo — a fix shown in place, not just described in text. Each mark draws
/// itself stroke-by-stroke, like a signature being drawn in red pencil, using a
/// `Canvas` whose path length is driven by a continuously advancing `TimelineView`.
struct GhostLimbOverlayView: View {
    let sketchJPEG: Data
    let marks: [CorrectionMark]

    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()

    private let perMarkDuration: Double = 0.9
    private let stagger: Double = 0.35

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = UIImage(data: sketchJPEG) {
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size.width, height: size.height)

                        TimelineView(.animation) { timeline in
                            Canvas { context, canvasSize in
                                let elapsed = timeline.date.timeIntervalSince(startDate)
                                for (index, mark) in marks.enumerated() {
                                    let markStart = Double(index) * stagger
                                    let progress = clampedProgress(elapsed: elapsed, start: markStart)
                                    guard progress > 0 else { continue }
                                    drawMark(mark, progress: progress, size: canvasSize, context: context)
                                }
                            }
                        }
                        .frame(width: size.width, height: size.height)
                    }
                }
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(VantageColor.overlayPanel)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        startDate = Date()
                    } label: {
                        Label("Redraw", systemImage: "arrow.counterclockwise")
                            .font(VantageFont.tick(12))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(VantageColor.overlayPanel)
                }
                .padding()
                Spacer()
                Text("Ghost-Limb Correction Overlay")
                    .font(VantageFont.tick(11))
                    .tracking(1.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(VantageColor.overlayPanel)
                    .padding(.bottom, 24)
            }
        }
    }

    private func clampedProgress(elapsed: Double, start: Double) -> Double {
        guard elapsed > start else { return 0 }
        return min(1, (elapsed - start) / perMarkDuration)
    }

    /// Draws one caliper-style correction bracket: a horizontal line trimmed to
    /// `progress`, with end ticks appearing once it has nearly finished, and the
    /// percent label fading in once the stroke completes.
    private func drawMark(_ mark: CorrectionMark, progress: Double, size: CGSize, context: GraphicsContext) {
        let y = size.height * mark.yFraction
        let marginX = size.width * 0.12
        let fullWidth = size.width - marginX * 2
        let drawnWidth = fullWidth * progress

        var line = Path()
        line.move(to: CGPoint(x: marginX, y: y))
        line.addLine(to: CGPoint(x: marginX + drawnWidth, y: y))
        context.stroke(line, with: .color(VantageColor.pencilRed.opacity(0.85)), lineWidth: 2.4)

        if progress > 0.85 {
            var ticks = Path()
            let tickLength: CGFloat = 10
            ticks.move(to: CGPoint(x: marginX, y: y - tickLength / 2))
            ticks.addLine(to: CGPoint(x: marginX, y: y + tickLength / 2))
            if progress >= 1 {
                ticks.move(to: CGPoint(x: marginX + fullWidth, y: y - tickLength / 2))
                ticks.addLine(to: CGPoint(x: marginX + fullWidth, y: y + tickLength / 2))
            }
            context.stroke(ticks, with: .color(VantageColor.pencilRed.opacity(0.85)), lineWidth: 2.4)
        }

        if progress >= 1 {
            let text = Text("\(mark.part.label) \(mark.label)")
                .font(VantageFont.tick(11))
                .foregroundColor(VantageColor.pencilRed)
            context.draw(text, at: CGPoint(x: marginX + fullWidth / 2, y: y - 14), anchor: .bottom)
        }
    }
}
