//
//  SwiftUI_Web_Image_PickerApp.swift
//  SwiftUI Web Image Picker
//
//  Created by Nathan Fennel on 5/1/26.
//

import SwiftUI
import SwiftData

@main
struct SwiftUI_Web_Image_PickerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
