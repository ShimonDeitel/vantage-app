import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store (Pro session history) and grid-division
/// settings (persisted to UserDefaults).
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    static let gridDivisionsRange: ClosedRange<Int> = 2...6

    @Published var gridDivisions: Int {
        didSet { defaults.set(gridDivisions, forKey: Keys.gridDivisions) }
    }
    @Published var showGrid: Bool {
        didSet { defaults.set(showGrid, forKey: Keys.showGrid) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let gridDivisions = "vantage.gridDivisions"
        static let showGrid = "vantage.showGrid"
    }

    init(container: ModelContainer) {
        self.container = container
        let d = UserDefaults.standard
        let storedDivisions = d.integer(forKey: Keys.gridDivisions)
        _gridDivisions = Published(initialValue: Self.gridDivisionsRange.contains(storedDivisions) ? storedDivisions : 3)
        _showGrid = Published(initialValue: d.object(forKey: Keys.showGrid) == nil ? true : d.bool(forKey: Keys.showGrid))
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([CritiqueSession.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Session history (Pro)

    func sessions() -> [CritiqueSession] {
        var descriptor = FetchDescriptor<CritiqueSession>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }

    @discardableResult
    func saveSession(referenceJPEG: Data, sketchJPEG: Data, feedback: [ProportionFeedback]) -> CritiqueSession {
        let session = CritiqueSession(referenceJPEG: referenceJPEG, sketchJPEG: sketchJPEG, feedback: feedback)
        container.mainContext.insert(session)
        try? container.mainContext.save()
        objectWillChange.send()
        return session
    }

    func deleteSession(_ session: CritiqueSession) {
        container.mainContext.delete(session)
        try? container.mainContext.save()
        objectWillChange.send()
    }

    func deleteAllData() {
        try? container.mainContext.delete(model: CritiqueSession.self)
        try? container.mainContext.save()
        gridDivisions = 3
        showGrid = true
    }
}
