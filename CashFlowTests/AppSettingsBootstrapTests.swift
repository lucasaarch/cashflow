import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class AppSettingsBootstrapTests: XCTestCase {
    func testEnsureExistsCreatesSingleton() throws {
        let schema = Schema([AppSettings.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        AppSettingsBootstrap.ensureExists(context: context)

        let descriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.id == "default" }
        )
        let settings = try context.fetch(descriptor)
        XCTAssertEqual(settings.count, 1)
        XCTAssertEqual(settings[0].id, AppSettingsBootstrap.defaultID)
    }

    func testEnsureExistsIsIdempotent() throws {
        let schema = Schema([AppSettings.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        AppSettingsBootstrap.ensureExists(context: context)
        AppSettingsBootstrap.ensureExists(context: context)

        let descriptor = FetchDescriptor<AppSettings>()
        XCTAssertEqual(try context.fetch(descriptor).count, 1)
    }
}
