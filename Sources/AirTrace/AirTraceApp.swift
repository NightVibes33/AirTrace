import SwiftUI

@main
struct AirTraceApp: App {
    @StateObject private var search = SearchCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView(search: search)
                .preferredColorScheme(.dark)
        }
    }
}
