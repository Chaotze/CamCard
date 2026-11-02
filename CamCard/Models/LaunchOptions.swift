import Foundation

struct LaunchOptions: Equatable {
    var resetStore: Bool = false
    var seedFixture: String?
    var ocrFixture: String?
    var skipCamera: Bool = false
    var forceExportFailure: Bool = false
    var persistentStore: Bool = false

    var isUITest: Bool {
        resetStore || seedFixture != nil || ocrFixture != nil || skipCamera
            || forceExportFailure || persistentStore
    }

    static func parse(_ arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-uiTestResetStore":
                options.resetStore = true
            case "-uiTestSkipCamera":
                options.skipCamera = true
            case "-uiTestForceExportFailure":
                options.forceExportFailure = true
            case "-uiTestPersistentStore":
                options.persistentStore = true
            case "-uiTestSeedFixture":
                if index + 1 < arguments.count {
                    options.seedFixture = arguments[index + 1]
                    index += 1
                }
            case "-uiTestOCRFixture":
                if index + 1 < arguments.count {
                    options.ocrFixture = arguments[index + 1]
                    index += 1
                }
            default:
                if argument.hasPrefix("-uiTestSeedFixture=") {
                    options.seedFixture = String(argument.dropFirst("-uiTestSeedFixture=".count))
                } else if argument.hasPrefix("-uiTestOCRFixture=") {
                    options.ocrFixture = String(argument.dropFirst("-uiTestOCRFixture=".count))
                }
            }
            index += 1
        }
        return options
    }
}
