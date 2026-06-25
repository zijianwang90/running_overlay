import Foundation

extension Bundle {
    static var runningOverlayResources: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }
}
