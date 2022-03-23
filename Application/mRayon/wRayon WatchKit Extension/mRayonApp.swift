//
//  mRayonApp.swift
//  wRayon WatchKit Extension
//
//  Created by Rachel on 3/23/22.
//

import SwiftUI

@main
struct mRayonApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
