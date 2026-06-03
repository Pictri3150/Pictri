import SwiftUI

@main
struct JapanQuestApp: App {
    @StateObject private var photoStore = PhotoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoStore)
        }
    }
}
