// AppDelegate.swift

import Flutter
import UIKit
import UserNotifications
import AppTrackingTransparency
import AdSupport

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    // Request App Tracking Transparency permission
    if #available(iOS 14, *) {
      ATTrackingManager.requestTrackingAuthorization { status in
        switch status {
        case .authorized:
          // Tracking permission granted, continue with tracking
          print("Tracking permission granted")
        case .denied:
          // Tracking permission denied, handle accordingly
          print("Tracking permission denied")
        default:
          break
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Example: Handling background fetch
  override func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
      // Perform background task
      completionHandler(.newData)
  }

  // Example: Handling remote notifications
override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Pass the token to Firebase Messaging
    // Messaging.messaging().apnsToken = deviceToken
    print("APNs device token: \(deviceToken)")
}

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("Failed to register for remote notifications: \(error)")
  }

  // Example: Handling deep links
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
      // Handle the URL
      return true
  }
}
