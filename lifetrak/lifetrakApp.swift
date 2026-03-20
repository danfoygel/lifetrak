//
//  lifetrakApp.swift
//  lifetrak
//
//  Created by Dan Foygel on 2/28/26.
//

import SwiftUI
import SwiftData

@main
struct lifetrakApp: App {
    var sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            Activity.self,
            Event.self,
            Routine.self,
            Goal.self,
            RoutineSchedule.self,
            WaterEntry.self,
        ])

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            sharedModelContainer = try! ModelContainer(for: schema, configurations: config)
            UITestSeeder.seed(container: sharedModelContainer)
            return
        }
        #endif

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.blue)
        }
        .modelContainer(sharedModelContainer)
    }
}
