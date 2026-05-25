import Foundation
import GRDB

extension AppDatabase {
    func bookCount() throws -> Int {
        try countRows(in: .books)
    }

    func chapterCount() throws -> Int {
        try countRows(in: .chapters)
    }

    func paragraphCount() throws -> Int {
        try countRows(in: .paragraphs)
    }

    func tableNames() throws -> Set<String> {
        try pool.read { db in
            let names = try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
            return Set(names)
        }
    }

    func indexNames(on table: String) throws -> Set<String> {
        try pool.read { db in
            let names = try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = ?",
                arguments: [table]
            )
            return Set(names)
        }
    }
}
