import CoreGraphics

/// Pure geometry for the proportion grid overlay — how many interior lines a given
/// division count produces and where they fall, as fractions of the frame (0...1).
/// Kept separate from any drawing code so it is trivially unit-testable.
enum GridGeometry {
    /// e.g. divisions = 3 → [1/3, 2/3]; divisions = 4 → [0.25, 0.5, 0.75].
    static func linePositions(divisions: Int) -> [CGFloat] {
        guard divisions >= 2 else { return [] }
        return (1..<divisions).map { CGFloat($0) / CGFloat(divisions) }
    }
}
