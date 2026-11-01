import SwiftUI

@main
struct CamCardApp: App {
    private let environment = AppEnvironment.make()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
