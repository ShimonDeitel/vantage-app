import Foundation

/// Turns two structured proportion-ratio sets (reference vs. sketch) into concrete,
/// worded feedback — pure and deterministic so the math can be unit-tested without
/// any network call. The AI supplies ratios; Vantage does the arithmetic.
enum ProportionComparator {

    /// Below this magnitude a difference isn't worth flagging (measurement noise from
    /// two independent vision-model reads on two different photos).
    static let defaultThresholdPercent: Double = 8

    /// Signed percent difference of `sketch` relative to `reference`.
    static func percentDelta(reference: Double, sketch: Double) -> Double {
        guard reference != 0 else { return 0 }
        return (sketch - reference) / reference * 100
    }

    static func direction(for part: BodyPart, percentDelta: Double) -> String {
        switch part.kind {
        case .length: return percentDelta < 0 ? "shorter" : "longer"
        case .width: return percentDelta < 0 ? "narrower" : "wider"
        }
    }

    static func message(for part: BodyPart, percentDelta: Double) -> String {
        let pct = Int(abs(percentDelta).rounded())
        let word = direction(for: part, percentDelta: percentDelta)
        return "The \(part.label.lowercased()) reads about \(pct)% \(word) than the reference."
    }

    /// Compares every part both measurements agree on, in `BodyPart.allCases` order,
    /// and returns feedback only for differences at or above `thresholdPercent`.
    static func compare(
        reference: ProportionMeasurement,
        sketch: ProportionMeasurement,
        thresholdPercent: Double = defaultThresholdPercent
    ) -> [ProportionFeedback] {
        var results: [ProportionFeedback] = []
        for part in BodyPart.allCases {
            guard let refValue = reference[part], let sketchValue = sketch[part], refValue > 0 else { continue }
            let delta = percentDelta(reference: refValue, sketch: sketchValue)
            guard abs(delta) >= thresholdPercent else { continue }
            results.append(
                ProportionFeedback(
                    partKey: part.rawValue,
                    part: part.label,
                    message: message(for: part, percentDelta: delta),
                    percentDelta: delta
                )
            )
        }
        // Largest discrepancies first — the artist's most useful fix goes on top.
        return results.sorted { abs($0.percentDelta) > abs($1.percentDelta) }
    }

    /// Maps feedback (from the structured path) into ghost-limb correction marks.
    /// Feedback from the plain-text fallback (empty `partKey`) is skipped since there
    /// is no canonical position to draw it at.
    static func correctionMarks(from feedback: [ProportionFeedback]) -> [CorrectionMark] {
        feedback.compactMap { item in
            guard let part = BodyPart(rawValue: item.partKey) else { return nil }
            let pct = Int(item.percentDelta.rounded())
            let label = (pct >= 0 ? "+" : "") + "\(pct)%"
            return CorrectionMark(part: part, yFraction: part.canonicalYFraction, percentDelta: item.percentDelta, label: label)
        }
    }
}
