//
//  minitApp.swift
//  minit
//
//  Created by Armands Berzins on 29/06/2026.
//

import SwiftUI
import CoreLogging
import FirebaseCore

@main
struct minitApp: App {
    init() {
        FirebaseApp.configure()
        SentryConfiguration.start()
        #if DEBUG
        LoggingConfiguration.configure(fileLoggingEnabled: true)
        #else
        LoggingConfiguration.configure(fileLoggingEnabled: false)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
