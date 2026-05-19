//
//  lexiApp.swift
//  lexi
//
//  Created by 琅邪 on 5/19/26.
//

import SwiftUI
import CoreData

@main
struct lexiApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
