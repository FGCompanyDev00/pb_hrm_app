import UIKit
import Flutter
import UserNotifications
import CoreLocation
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {

  let locationManager = CLLocationManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Request Notification Permission
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        // Handle the granted status
    }

    // Request Location Permission
    locationManager.delegate = self
    locationManager.requestWhenInUseAuthorization()

    // Request Camera Permission
    AVCaptureDevice.requestAccess(for: .video) { granted in
        // Handle the granted status
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Additional methods to handle location updates or other features can be added here

}