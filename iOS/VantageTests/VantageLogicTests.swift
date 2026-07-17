import XCTest
@testable import Vantage

final class VantageLogicTests: XCTestCase {

    // MARK: ProportionComparator

    func testPercentDelta_ShorterExample() {
        // Reference brief example: a 20%-shorter forearm.
        let delta = ProportionComparator.percentDelta(reference: 0.20, sketch: 0.16)
        XCTAssertEqual(delta, -20.0, accuracy: 0.001)
    }

    func testDirectionWording_LengthAndWidth() {
        XCTAssertEqual(ProportionComparator.direction(for: .armLengthToHeight, percentDelta: -20), "shorter")
        XCTAssertEqual(ProportionComparator.direction(for: .armLengthToHeight, percentDelta: 12), "longer")
        XCTAssertEqual(ProportionComparator.direction(for: .shoulderWidthToHeight, percentDelta: 15), "wider")
        XCTAssertEqual(ProportionComparator.direction(for: .shoulderWidthToHeight, percentDelta: -9), "narrower")
    }

    func testMessage_MatchesExpectedWording() {
        let message = ProportionComparator.message(for: .armLengthToHeight, percentDelta: -20.4545)
        XCTAssertEqual(message, "The arm length reads about 20% shorter than the reference.")
    }

    func testCompare_FiltersBelowThresholdAndSortsByLargestDiscrepancyFirst() {
        // head: 7.69% (below the 8% threshold, excluded)
        // arm: -20.45% (included)
        // leg: 6.0% (excluded)
        // torso: -10.0% (included)
        let reference = ProportionMeasurement(values: [
            BodyPart.headToHeight.rawValue: 0.13,
            BodyPart.armLengthToHeight.rawValue: 0.44,
            BodyPart.legLengthToHeight.rawValue: 0.50,
            BodyPart.torsoToHeight.rawValue: 0.30,
        ])
        let sketch = ProportionMeasurement(values: [
            BodyPart.headToHeight.rawValue: 0.14,
            BodyPart.armLengthToHeight.rawValue: 0.35,
            BodyPart.legLengthToHeight.rawValue: 0.53,
            BodyPart.torsoToHeight.rawValue: 0.27,
        ])

        let feedback = ProportionComparator.compare(reference: reference, sketch: sketch)

        XCTAssertEqual(feedback.count, 2)
        XCTAssertEqual(feedback[0].partKey, BodyPart.armLengthToHeight.rawValue)
        XCTAssertEqual(feedback[1].partKey, BodyPart.torsoToHeight.rawValue)
        XCTAssertEqual(feedback[0].percentDelta, -20.4545, accuracy: 0.01)
        XCTAssertEqual(feedback[1].percentDelta, -10.0, accuracy: 0.01)
    }

    func testCorrectionMarks_MapsPartKeyToCanonicalPositionAndRoundedLabel() {
        let feedback = [
            ProportionFeedback(partKey: BodyPart.armLengthToHeight.rawValue, part: "Arm Length", message: "…", percentDelta: -20.4545),
            ProportionFeedback(partKey: "", part: "Note", message: "fallback text item", percentDelta: 0),
        ]
        let marks = ProportionComparator.correctionMarks(from: feedback)

        XCTAssertEqual(marks.count, 1, "the empty partKey fallback item has no canonical position and is skipped")
        XCTAssertEqual(marks[0].part, .armLengthToHeight)
        XCTAssertEqual(marks[0].yFraction, BodyPart.armLengthToHeight.canonicalYFraction)
        XCTAssertEqual(marks[0].label, "-20%")
    }

    func testProportionMeasurement_IsUsableRequiresAtLeastTwoKnownParts() {
        XCTAssertFalse(ProportionMeasurement(values: [:]).isUsable)
        XCTAssertFalse(ProportionMeasurement(values: [BodyPart.headToHeight.rawValue: 0.13]).isUsable)
        XCTAssertTrue(ProportionMeasurement(values: [
            BodyPart.headToHeight.rawValue: 0.13,
            BodyPart.torsoToHeight.rawValue: 0.30,
        ]).isUsable)
    }

    // MARK: GridGeometry

    func testGridGeometry_LinePositions() {
        XCTAssertEqual(GridGeometry.linePositions(divisions: 1), [])
        XCTAssertEqual(GridGeometry.linePositions(divisions: 2), [0.5])
        let thirds = GridGeometry.linePositions(divisions: 3)
        XCTAssertEqual(thirds.count, 2)
        XCTAssertEqual(Double(thirds[0]), 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(Double(thirds[1]), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(GridGeometry.linePositions(divisions: 4), [0.25, 0.5, 0.75])
    }

    // MARK: MotionEngine (pure geometry — `nonisolated`, so no actor hop needed)

    func testMotionEngine_IsSteadyWithinThreshold() {
        XCTAssertTrue(MotionEngine.isSteady(rollHistory: [0.010, 0.015, 0.012], pitchHistory: [0.000, 0.002, 0.001]))
        XCTAssertFalse(MotionEngine.isSteady(rollHistory: [0.0, 0.05, 0.02], pitchHistory: [0.0, 0.0, 0.0]))
        XCTAssertFalse(MotionEngine.isSteady(rollHistory: [0.01, 0.01], pitchHistory: [0.0, 0.0]), "fewer than 3 samples is never considered steady")
    }

    func testMotionEngine_PlumbRotationClampsAndInverts() {
        XCTAssertEqual(MotionEngine.plumbRotation(roll: 0).radians, 0, accuracy: 0.0001)
        XCTAssertEqual(MotionEngine.plumbRotation(roll: 0.1).radians, -0.1, accuracy: 0.0001)
        // .pi/2 exceeds the clamp range (±.pi/2.4) and should be capped there.
        XCTAssertEqual(MotionEngine.plumbRotation(roll: .pi / 2).radians, -(.pi / 2.4), accuracy: 0.0001)
    }

    func testMotionEngine_AlignmentScoreRange() {
        XCTAssertEqual(MotionEngine.alignmentScore(roll: 0, pitch: 0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(MotionEngine.alignmentScore(roll: .pi / 6, pitch: 0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(MotionEngine.alignmentScore(roll: .pi / 12, pitch: 0), 0.5, accuracy: 0.01)
    }

    // MARK: ProportionFeedbackParser (text fallback)

    func testProportionFeedbackParser_ParsesMixedBulletStyles() {
        let raw = "- Line one\n* Line two\n\n1. Line three\n2) Line four\n   \nJust a note"
        let lines = ProportionFeedbackParser.parseBulletLines(raw)
        XCTAssertEqual(lines, ["Line one", "Line two", "Line three", "Line four", "Just a note"])
    }

    // MARK: AIProxyClient (pure string parsing)

    func testAIProxyClient_ExtractJSONObjectFromFencedText() {
        let raw = "Here is the result:\n```json\n{\"measurements\": {\"head_to_height\": 0.13}}\n```\nThanks!"
        let extracted = AIProxyClient.extractJSONObject(from: raw)
        XCTAssertEqual(extracted, "{\"measurements\": {\"head_to_height\": 0.13}}")
    }
}
