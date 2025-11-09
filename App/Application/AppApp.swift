//
//  AppApp.swift
//  App
//
//  Created by user on 8/11/25.
//

import SwiftData
import SwiftUI

@main
struct AppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FinanceEvent.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
