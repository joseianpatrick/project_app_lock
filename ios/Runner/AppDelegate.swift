import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appLockChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.focuslock/app_lock",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getCapability":
        result([
          "platform": "ios",
          "isAvailable": false,
          "reason": "iOS app locking is intentionally unavailable in this Android-first release."
        ])
      case "startLockSession", "stopLockSession":
        result(FlutterError(
          code: "unsupported_platform",
          message: "App locking is not available on iOS in this release.",
          details: nil
        ))
      case "getInstalledApps", "requestAuthorization":
        result(FlutterError(
          code: "unsupported_platform",
          message: "Installed-app selection is not available on iOS in this release.",
          details: nil
        ))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    appLockChannel = channel
  }
}
