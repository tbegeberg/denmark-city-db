import Foundation

public enum QueryError: Error {
    case queryNonPrepared(message: String)
    case noOpenDatabase
    case missingDataInTable(message: String)
    case noResults
}
