import SwiftUI

@main
struct DoneLoopApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(services)
        }
    }
}
