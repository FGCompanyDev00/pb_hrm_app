// AppDelegate.swift

import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
import AdSupport
import flutter_background_service_ios

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Cache notification center and method channel
  private let notificationCenter = UNUserNotificationCenter.current()
  private var notificationChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register plugins first
    GeneratedPluginRegistrant.register(with: self)
    
    // Configure background service
    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "com.psvsystem.next.sessionService"
    
    // Initialize method channel early
    if let controller = window?.rootViewController as? FlutterViewController {
      notificationChannel = FlutterMethodChannel(
        name: "com.psvsystem.next/notifications",
        binaryMessenger: controller.binaryMessenger
      )
    }
    
    // Move heavy initialization to background
    DispatchQueue.global(qos: .utility).async { [weak self] in
      self?.initializeNotifications(application)
      
      // Handle tracking permission with delay
      #if canImport(AppTrackingTransparency)
      if #available(iOS 14, *) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          self?.requestTrackingPermission()
        }
      }
      #endif
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func initializeNotifications(_ application: UIApplication) {
    if #available(iOS 10.0, *) {
      notificationCenter.delegate = self
      
      // Register for notifications without requesting permission
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
        self.notificationCenter.delegate = self
      }
    } else {
      DispatchQueue.main.async {
        let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()
      }
    }
  }
  
  private func requestTrackingPermission() {
    #if canImport(AppTrackingTransparency)
    if #available(iOS 14, *) {
      ATTrackingManager.requestTrackingAuthorization { status in
        switch status {
        case .authorized:
          print("Tracking permission granted")
        case .denied:
          print("Tracking permission denied")
        case .notDetermined:
          print("Tracking permission not determined")
        case .restricted:
          print("Tracking permission restricted")
        @unknown default:
          print("Tracking permission unknown status")
        }
      }
    }
    #endif
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("Device Token: \(token)")
    
    // Send token to Flutter on main thread
    DispatchQueue.main.async { [weak self] in
      self?.notificationChannel?.invokeMethod("updateToken", arguments: token)
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error)")
  }

  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    completionHandler(.newData)
  }
}

// MARK: - UNUserNotificationCenterDelegate
@available(iOS 10.0, *)
extension AppDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    // Process notification data in background
    DispatchQueue.global(qos: .utility).async {
      print("Received notification in foreground: \(userInfo)")
      
      DispatchQueue.main.async {
        if #available(iOS 14.0, *) {
          completionHandler([[.banner, .list, .sound, .badge]])
        } else {
          completionHandler([[.alert, .sound, .badge]])
        }
      }
    }
  }
  
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    // Process notification response in background
    DispatchQueue.global(qos: .utility).async { [weak self] in
      print("Notification response received: \(userInfo)")
      
      DispatchQueue.main.async {
        self?.notificationChannel?.invokeMethod("notificationTapped", arguments: userInfo)
        completionHandler()
      }
    }
  }
}
