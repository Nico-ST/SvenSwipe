//
//  SvenSwipeApp.swift
//  SvenSwipe
//
//  Created by Nico Stillhart on 14.01.2026.
//

import SwiftUI
import UIKit
import GoogleMobileAds

final class AppOrientationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["e01ca33a395701c88c642da1050b7cf2"]
        MobileAds.shared.start(completionHandler: nil)
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct SvenSwipeApp: App {
    @UIApplicationDelegateAdaptor(AppOrientationDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

