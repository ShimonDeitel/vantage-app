import SwiftUI

/// Drafting-table identity: graphite grey + off-white paper, one vivid red-pencil
/// accent reserved strictly for AI-generated feedback/corrections. Every primary
/// control is sharp-cornered — crosshairs, plumb lines, tick marks, hairline rules —
/// the deliberate opposite of a rounded/organic app.
enum VantageColor {
    static let paper = Color(light: Color(hex: 0xF3F0E7), dark: Color(hex: 0x18191B))
    static let panel = Color(light: Color(hex: 0xEAE6D9), dark: Color(hex: 0x212327))
    static let ink = Color(light: Color(hex: 0x232426), dark: Color(hex: 0xEDEAE0))
    static let inkMuted = Color(light: Color(hex: 0x63645F), dark: Color(hex: 0x9B9C96))
    static let hairline = Color(light: Color(hex: 0xC9C4B3), dark: Color(hex: 0x33352F))
    static let graphite = Color(hex: 0x3A3B3D)

    /// The single vivid accent. Reserved for AI critique, ghost-limb corrections,
    /// and the Pro call-to-action — never ordinary chrome.
    static let pencilRed = Color(hex: 0xE8362B)
    static let pencilRedDim = Color(hex: 0xE8362B).opacity(0.35)

    /// Overlay line color drawn on top of the live camera feed. Deliberately
    /// theme-independent (it sits over live video, not app chrome).
    static let overlayLine = Color.white.opacity(0.72)
    static let overlayLineLocked = Color.white

    /// Camera-chrome panel/hairline — also theme-independent, sits over live video.
    static let overlayPanel = Color.black.opacity(0.55)
    static let overlayHairline = Color.white.opacity(0.25)
}

enum VantageFont {
    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .bold, design: .default) }
    static func headline(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .semibold) }
    static func value(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func tick(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .semibold) }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// A sharp (0-radius) rectangular frame with a hairline border — the primary chrome
/// container across Vantage. No rounded corners anywhere in the drafting-table chrome.
struct DraftPanel<Content: View>: View {
    var accent: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VantageColor.panel)
            .overlay(
                Rectangle()
                    .strokeBorder(accent ? VantageColor.pencilRed.opacity(0.6) : VantageColor.hairline, lineWidth: 1)
            )
    }
}

/// Uppercase tracked label styled like a drafting-instrument engraving.
struct TickLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(VantageFont.caption())
            .tracking(1.8)
            .foregroundStyle(VantageColor.inkMuted)
    }
}

/// Primary CTA — square-cornered solid bar. Red only when the action is AI-related
/// (critique / Pro); graphite otherwise.
struct SquareButtonStyle: ButtonStyle {
    var filled: Bool = true
    var tint: Color = VantageColor.graphite

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VantageFont.headline())
            .foregroundStyle(filled ? Color.white : tint)
            .padding(.vertical, 13)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(filled ? tint : Color.clear)
            .overlay(Rectangle().strokeBorder(tint, lineWidth: filled ? 0 : 1.4))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func squareButton(filled: Bool = true, tint: Color = VantageColor.graphite) -> some View {
        buttonStyle(SquareButtonStyle(filled: filled, tint: tint))
    }
}

/// Small corner-crosshair mark, used to bracket viewports and photo frames — echoes
/// the plumb-line/crosshair language at rest, not just in the live camera overlay.
struct CornerTicks: Shape {
    var length: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners = [rect.minX, rect.maxX]
        let rows = [rect.minY, rect.maxY]
        for x in corners {
            for y in rows {
                let dx: CGFloat = x == rect.minX ? 1 : -1
                let dy: CGFloat = y == rect.minY ? 1 : -1
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + dx * length, y: y))
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + dy * length))
            }
        }
        return path
    }
}
