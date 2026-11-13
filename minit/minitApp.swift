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
        AppLanguageSettingsReconciler.reconcile()
        SettingsVersionPreference.write()
        FirebaseApp.configure()
        RemoteConfigGate.start()
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
