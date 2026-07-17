import Foundation
import SwiftData
import CoreGraphics

/// Which figure measurement a ratio describes. `kind` drives the wording of the
/// generated feedback sentence (shorter/longer for lengths, narrower/wider for widths)
/// and `canonicalYFraction` drives where its ghost-limb correction mark is drawn.
enum BodyPart: String, CaseIterable, Codable {
    case headToHeight = "head_to_height"
    case shoulderWidthToHeight = "shoulder_width_to_height"
    case hipWidthToHeight = "hip_width_to_height"
    case armLengthToHeight = "arm_length_to_height"
    case legLengthToHeight = "leg_length_to_height"
    case torsoToHeight = "torso_to_height"
    case handLengthToHeight = "hand_length_to_height"

    enum Kind { case length, width }

    var kind: Kind {
        switch self {
        case .shoulderWidthToHeight, .hipWidthToHeight: return .width
        default: return .length
        }
    }

    var label: String {
        switch self {
        case .headToHeight: return "Head Height"
        case .shoulderWidthToHeight: return "Shoulder Width"
        case .hipWidthToHeight: return "Hip Width"
        case .armLengthToHeight: return "Arm Length"
        case .legLengthToHeight: return "Leg Length"
        case .torsoToHeight: return "Torso Length"
        case .handLengthToHeight: return "Hand Length"
        }
    }

    /// Canonical normalized vertical position (0 = top of photo, 1 = bottom) used to
    /// place this part's ghost-limb correction mark. Illustrative, not pose-derived —
    /// Vantage has no on-device body segmentation, so the mark communicates *which*
    /// proportion is off and by how much, at the figure region it typically belongs to.
    var canonicalYFraction: CGFloat {
        switch self {
        case .headToHeight: return 0.14
        case .shoulderWidthToHeight: return 0.24
        case .torsoToHeight: return 0.46
        case .hipWidthToHeight: return 0.52
        case .armLengthToHeight: return 0.58
        case .handLengthToHeight: return 0.64
        case .legLengthToHeight: return 0.90
        }
    }
}

/// A set of figure-proportion ratios (each part's size relative to overall height),
/// as reported by the vision model for one photo (reference or sketch).
struct ProportionMeasurement: Codable, Equatable {
    var values: [String: Double]

    subscript(part: BodyPart) -> Double? {
        get { values[part.rawValue] }
        set { values[part.rawValue] = newValue }
    }

    /// True once at least a couple of the expected parts are present — used to
    /// decide whether the structured path succeeded or Vantage should fall back to
    /// the plain-text comparison path.
    var isUsable: Bool {
        BodyPart.allCases.filter { values[$0.rawValue] != nil }.count >= 2
    }
}

/// Wire shape for the vision model's structured response: `{"measurements": {...}}`.
struct ProportionMeasurementResponse: Decodable {
    let measurements: [String: Double]
}

/// One piece of AI critique feedback, ready to display in a list and (when it maps to
/// a known body part) to place as a ghost-limb correction mark.
struct ProportionFeedback: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// `BodyPart.rawValue` when this feedback came from the structured comparison
    /// path; empty when it came from the plain-text fallback (no mark is drawn).
    var partKey: String
    var part: String
    var message: String
    var percentDelta: Double
}

/// A ghost-limb correction mark: a horizontal caliper bracket drawn over the user's
/// sketch photo at the canonical position for the flagged part.
struct CorrectionMark: Identifiable, Equatable {
    var id = UUID()
    var part: BodyPart
    var yFraction: CGFloat
    var percentDelta: Double
    var label: String
}

enum PhotoRole: String, Identifiable {
    case reference
    case sketch

    var id: String { rawValue }
}

/// A saved critique session: both photos (downsized JPEGs) plus the resulting
/// feedback list, persisted with SwiftData for the Pro history screen.
@Model
final class CritiqueSession {
    var id: UUID
    var createdAt: Date
    var referenceJPEG: Data
    var sketchJPEG: Data
    var feedbackJSON: Data

    init(id: UUID = UUID(), createdAt: Date = Date(), referenceJPEG: Data, sketchJPEG: Data, feedback: [ProportionFeedback]) {
        self.id = id
        self.createdAt = createdAt
        self.referenceJPEG = referenceJPEG
        self.sketchJPEG = sketchJPEG
        self.feedbackJSON = (try? JSONEncoder().encode(feedback)) ?? Data()
    }

    var feedback: [ProportionFeedback] {
        (try? JSONDecoder().decode([ProportionFeedback].self, from: feedbackJSON)) ?? []
    }
}

/// Lightweight, `Sendable`-friendly projection of a `CritiqueSession` for list rows.
struct CritiqueSessionSummary: Identifiable {
    let id: UUID
    let createdAt: Date
    let sketchThumbnail: Data
    let feedbackCount: Int
    let topFeedback: String?

    init(session: CritiqueSession) {
        id = session.id
        createdAt = session.createdAt
        sketchThumbnail = session.sketchJPEG
        let feedback = session.feedback
        feedbackCount = feedback.count
        topFeedback = feedback.max(by: { abs($0.percentDelta) < abs($1.percentDelta) })?.message
    }
}
