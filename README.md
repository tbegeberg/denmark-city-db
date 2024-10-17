# Danish City Datebase
A SQLite database containing all cities in Denmark described by rectangels with four coordinates. The database can be used for querying if a point is in a city and the data has been optimized with RTree - https://www.sqlite.org/rtree.html

## Usage 

The query for checking if a coordinate is in a ciy in Denmark the query statement can look like this:
```
SELECT demo_data.* FROM demo_data, demo_index WHERE demo_data.id=demo_index.id AND minX<=\(location.longitude) AND maxX>=\(location.longitude) AND minY<=\(location.latitude) AND maxY>=\(location.latitude);
```

The result will return an id(colounm 0) and a city(colounm 1)

### Swift implementation
This is an example of how you can use the database in swift

```
import SQLite3
import Foundation

struct CityService {

  let cityDbURL = Bundle.module.url(forResource: "cityDB", withExtension: "sqlite")
  var cityOpenDatabase: OpaquePointer?

  /// Checks if a location is in a city in DK
  func isInCity(at location: CLLocationCoordinate2D) async -> Bool {
      cityOpenDatabase = setupDatabase(dbPath: cityDbURL?.path() ?? "")
      
      let queryInTree = "SELECT demo_data.* FROM demo_data, demo_index WHERE demo_data.id=demo_index.id AND minX<=\(location.longitude) AND maxX>=\(location.longitude) AND minY<=\(location.latitude) AND maxY>=\(location.latitude);"
      
      guard let cityOpenDatabase = cityOpenDatabase else {
          logger.warning("no city open database available")
          return false
      }
  
      return await queryCity(db: cityOpenDatabase, queryStatementString: queryInTree)
  }

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

  func queryCity(db: OpaquePointer, queryStatementString: String) async -> Bool {
      var queryStatement: OpaquePointer?
      
      return await withCheckedContinuation { continution in
          if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) ==
              SQLITE_OK {
              
              while sqlite3_step(queryStatement) == SQLITE_ROW {
                  guard let queryResultCol1 = sqlite3_column_text(queryStatement, 1) else {
                      continution.resume(returning: false)
                      sqlite3_finalize(queryStatement)
                      if sqlite3_close(db) != SQLITE_OK {
                          print("error closing database")
                      }
                      return
                  }
                  let property = String(cString: queryResultCol1)
                  print("\nQuery Result: \(property)")
                  continution.resume(returning: true)
                  sqlite3_finalize(queryStatement)
                  if sqlite3_close(db) != SQLITE_OK {
                      print("error closing database")
                  }
                  return
              }
          } else {
              let errorMessage = String(cString: sqlite3_errmsg(db))
              print("\nQuery is not prepared \(errorMessage)")
              continution.resume(returning: false)
              sqlite3_finalize(queryStatement)
              if sqlite3_close(db) != SQLITE_OK {
                  print("error closing database")
              }
              return
          }
          sqlite3_finalize(queryStatement)
          continution.resume(returning: false)
      }
  }
}
```
