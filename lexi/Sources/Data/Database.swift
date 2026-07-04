import Foundation
import GRDB

actor AppDatabase {
    let pool: DatabasePool

    init(pool: DatabasePool) throws {
        self.pool = pool
        try Self.migrate(pool)
    }

    private static let sharedResult: Result<AppDatabase, Error> = Result {
        try makeShared()
    }

    static func sharedInstance() throws -> AppDatabase {
        try sharedResult.get()
    }

    private static func makeShared() throws -> AppDatabase {
        let url = try sharedDatabaseURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let pool = try DatabasePool(path: url.path)
        return try AppDatabase(pool: pool)
    }

    static func makeTransient() throws -> AppDatabase {
        let directory = FileManager.default.temporaryDirectory.appending(path: "LexiTests", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(UUID().uuidString).sqlite")
        let pool = try DatabasePool(path: url.path)
        return try AppDatabase(pool: pool)
    }

    func migrate() throws {
        try Self.migrate(pool)
    }

    private static func migrate(_ pool: DatabasePool) throws {
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(pool)
    }

    static func sharedDatabaseURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appending(path: "Lexi", directoryHint: .isDirectory).appending(path: "lexi.sqlite")
    }

    enum CountedTable: String {
        case books
        case chapters
        case paragraphs
        case vocab
    }

    func countRows(in table: CountedTable) throws -> Int {
        try pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table.rawValue)") ?? 0
        }
    }
}
