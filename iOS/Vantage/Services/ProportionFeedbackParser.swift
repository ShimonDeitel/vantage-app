import Foundation

/// Fallback path: if either vision call's JSON measurement fails to decode, Vantage
/// asks the text model to phrase discrepancies as a bullet list and parses that list
/// here. Pure string logic, unit-testable without any network call.
enum ProportionFeedbackParser {

    /// Strips common bullet/number markers ("- ", "* ", "1.", "1)") from each line,
    /// drops blank lines, and trims whitespace.
    static func parseBulletLines(_ text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map(stripMarker)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func stripMarker(_ rawLine: String) -> String {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        let bulletPrefixes = ["- ", "* ", "• ", "— "]
        for prefix in bulletPrefixes where line.hasPrefix(prefix) {
            line.removeFirst(prefix.count)
            return line
        }
        // Numbered markers like "1.", "1)", "12 -".
        if let firstNonDigitIndex = line.firstIndex(where: { !$0.isNumber }) {
            let digits = line[line.startIndex..<firstNonDigitIndex]
            if !digits.isEmpty {
                let separator = line[firstNonDigitIndex]
                if separator == "." || separator == ")" || separator == "-" || separator == ":" {
                    var rest = line[line.index(after: firstNonDigitIndex)...]
                    while rest.first == " " { rest.removeFirst() }
                    return String(rest)
                }
            }
        }
        return line
    }

    /// Wraps parsed bullet strings as `ProportionFeedback` with no `partKey` (so no
    /// ghost-limb mark is generated for them) and no computed percent delta.
    static func toFeedback(_ lines: [String]) -> [ProportionFeedback] {
        lines.map { line in
            ProportionFeedback(partKey: "", part: "Note", message: line, percentDelta: 0)
        }
    }
}
