import Foundation

enum BuildFlavor {
    #if LOCAL_TESTING
    static let isLocalTesting = true
    #else
    static let isLocalTesting = false
    #endif
}
