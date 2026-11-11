import Flutter
import WatchConnectivity

/// Pont entre l'app Flutter et l'app Apple Watch (WatchConnectivity).
/// Canal « rhythmix_watch » :
/// - Dart -> natif `send` : envoie l'état (mode, b, d, pause, running…) à la montre ;
/// - Dart -> natif `status` : montre appairée / app installée / joignable ;
/// - natif -> Dart `onState` : état envoyé par la montre (molette, marche / arrêt) ;
/// - natif -> Dart `onReachable` : la montre redevient joignable (renvoyer l'état).
public class WatchBridge: NSObject, FlutterPlugin, WCSessionDelegate {
  private static var shared: WatchBridge?
  private var channel: FlutterMethodChannel?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let ch = FlutterMethodChannel(name: "rhythmix_watch", binaryMessenger: registrar.messenger())
    let instance = WatchBridge()
    instance.channel = ch
    shared = instance  // WCSession ne retient pas son délégué
    registrar.addMethodCallDelegate(instance, channel: ch)
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = instance
    WCSession.default.activate()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard WCSession.isSupported() else {
      result(call.method == "status" ? ["supported": false] : false)
      return
    }
    let s = WCSession.default
    switch call.method {
    case "send":
      guard let msg = call.arguments as? [String: Any],
        s.activationState == .activated, s.isPaired, s.isWatchAppInstalled
      else {
        result(false)
        return
      }
      if s.isReachable { s.sendMessage(msg, replyHandler: nil, errorHandler: nil) }
      try? s.updateApplicationContext(msg)
      result(true)
    case "status":
      result([
        "supported": true,
        "paired": s.isPaired,
        "installed": s.isWatchAppInstalled,
        "reachable": s.isReachable,
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func toDart(_ method: String, _ args: Any?) {
    DispatchQueue.main.async { self.channel?.invokeMethod(method, arguments: args) }
  }

  // MARK: - WCSessionDelegate

  public func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  public func sessionDidBecomeInactive(_ session: WCSession) {}

  public func sessionDidDeactivate(_ session: WCSession) {
    session.activate()  // changement de montre appairée
  }

  public func sessionReachabilityDidChange(_ session: WCSession) {
    if session.isReachable { toDart("onReachable", nil) }
  }

  public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    toDart("onState", message)
  }

  public func session(
    _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    toDart("onState", applicationContext)
  }
}
