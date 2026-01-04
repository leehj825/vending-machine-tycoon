import Cocoa
import FlutterMacOS
import GameKit

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // Set up MethodChannel to receive Game Center related calls from Dart
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(name: "com.vending_empire/game_center", binaryMessenger: controller.engine.binaryMessenger)

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "unlockAchievement":
        if let args = call.arguments as? [String:Any], let id = args["id"] as? String {
          let achievement = GKAchievement(identifier: id)
          achievement.percentComplete = 100.0
          GKAchievement.report([achievement]) { error in
            if let error = error {
              result(FlutterError(code: "gc_error", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        } else {
          result(FlutterError(code: "bad_args", message: "Expected achievement id", details: nil))
        }

      case "showAchievements":
        // macOS GameKit does not have a direct standard achievements UI like iOS; return not-implemented
        result(FlutterMethodNotImplemented)

      case "authenticate":
        // Trigger Game Center authentication flow
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
          if let vc = viewController {
            controller.presentAsModalWindow(vc)
            result(nil)
          } else if GKLocalPlayer.local.isAuthenticated {
            result(nil)
          } else if let err = error {
            result(FlutterError(code: "gc_auth", message: err.localizedDescription, details: nil))
          } else {
            result(FlutterMethodNotImplemented)
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Kick off silent authentication attempt for Game Center.
    // Do NOT present UI automatically on app launch — that can block the Flutter view.
    // We still set the authenticate handler so the Game Center state will update.
    GKLocalPlayer.local.authenticateHandler = { viewController, error in
      if let _ = viewController {
        // Game Center requires interactive authentication; defer showing UI until Dart requests it.
        NSLog("Game Center requires interactive authentication; deferring UI presentation.")
      } else if let err = error {
        NSLog("Game Center auth error: \(err.localizedDescription)")
      } else if GKLocalPlayer.local.isAuthenticated {
        NSLog("Game Center authenticated")
      }
    }
  }
}
