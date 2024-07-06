import Foundation
import MapKit
import OSLog
import SQLite3

public struct DenmarkCityService {
    
    public typealias CityQueryResult = (cityName: String?, isInCity: Bool)
    
    public var isInCity: (_ at: CLLocationCoordinate2D) async -> CityQueryResult
    
    public static var liveValue: Self {
        let logger = Logger(subsystem: Bundle.module.bundleIdentifier!, category: "Denmark City Service")
        let cityDbURL = Bundle.module.url(forResource: "cityDB", withExtension: "sqlite")
        var cityOpenDatabase: OpaquePointer?
        
        func setupDatabase(dbPath: String) -> OpaquePointer? {
            var db: OpaquePointer?
            
            if sqlite3_open(dbPath, &db) == SQLITE_OK {
                logger.info("Successfully opened connection to database at \(dbPath)")
                return db
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                logger.error("Unable to open database with error: \(errorMessage)")
                return nil
            }
        }
        
        func queryCity(db: OpaquePointer, queryStatementString: String) async -> CityQueryResult {
            var queryStatement: OpaquePointer?
            
            return await withCheckedContinuation { continution in
                if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) ==
                    SQLITE_OK {
                    
                    while sqlite3_step(queryStatement) == SQLITE_ROW {

                        guard let queryResultCol1 = sqlite3_column_text(queryStatement, 1) else {
                            continution.resume(returning: CityQueryResult(cityName: nil, isInCity: false))
                            sqlite3_finalize(queryStatement)
                            if sqlite3_close(db) != SQLITE_OK {
                                logger.error("error closing database")
                            } else {
                                logger.info("closing database successfully")
                            }
                            return
                        }
                        let cityName = String(cString: queryResultCol1)
                        logger.info("\nQuery Result: \(cityName)")
                        
                        continution.resume(returning: CityQueryResult(cityName: cityName, isInCity: true))
                        sqlite3_finalize(queryStatement)
                        if sqlite3_close(db) != SQLITE_OK {
                            logger.error("error closing database")
                        } else {
                            logger.info("closing database successfully")
                        }
                        return
                    }
                } else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    
                    logger.error("\nQuery is not prepared \(errorMessage)")
                    
                    continution.resume(returning: CityQueryResult(cityName: nil, isInCity: false))
                    sqlite3_finalize(queryStatement)
                    if sqlite3_close(db) != SQLITE_OK {
                        logger.error("error closing database")
                    } else {
                        logger.info("closing database successfully")
                    }
                    return
                }
                sqlite3_finalize(queryStatement)
                continution.resume(returning: CityQueryResult(cityName: nil, isInCity: false))
            }
        }
        
        return .init(
            isInCity: { location in
                cityOpenDatabase = setupDatabase(dbPath: cityDbURL?.path() ?? "")
                
                let queryInTree = "SELECT city_data.* FROM city_data, city_index WHERE city_data.id=city_index.id AND minX<=\(location.longitude) AND maxX>=\(location.longitude) AND minY<=\(location.latitude) AND maxY>=\(location.latitude);"
                
                guard let cityOpenDatabase = cityOpenDatabase else {
                    logger.warning("no city open database available")
                    return false
                }

                return await queryCity(db: cityOpenDatabase, queryStatementString: queryInTree)
            }
        )
    }
}
