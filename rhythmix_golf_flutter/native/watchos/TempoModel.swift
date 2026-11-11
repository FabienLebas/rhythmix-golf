import Foundation
import SwiftUI
import WatchConnectivity
import WatchKit

/// Trois temps du swing et le haptique associé.
/// À ajuster après essai sur la montre : les motifs de watchOS sont prédéfinis
/// (.click, .start, .stop, .directionUp, .directionDown, .success, .retry,
/// .notification, .failure) et on ne peut pas régler leur durée.
private enum Beat {
  case start, top, impact

  var haptic: WKHapticType {
    switch self {
    case .start: return .start
    case .top: return .click
    case .impact: return .directionDown
    }
  }

  var label: String {
    switch self {
    case .start: return "Départ"
    case .top: return "Sommet"
    case .impact: return "Impact"
    }
  }
}

private extension DispatchTime {
  func adding(_ seconds: Double) -> DispatchTime {
    self + .nanoseconds(Int(max(0, seconds) * 1e9))
  }
}

final class TempoModel: NSObject, ObservableObject, WCSessionDelegate, WKExtendedRuntimeSessionDelegate {
  // État affiché
  @Published var mode = "grand"
  @Published var running = false
  @Published var speed: Double = 100  // en %, à droite = plus rapide
  @Published var connected = false
  @Published var currentBeat: String?

  // Tempo reçu de l'iPhone à la vitesse 100 %
  private var baseB = 0.81
  private var baseD = 0.27
  private var pause = 3.0

  var b: Double { baseB * 100 / speed }
  var d: Double { baseD * 100 / speed }

  // Cadencement : une file dédiée, des échéances absolues.
  private let queue = DispatchQueue(label: "rhythmix.haptic", qos: .userInteractive)
  private var generation = 0

  private var session: WKExtendedRuntimeSession?
  private var lastPhoneSeq = 0.0
  private var pushWork: DispatchWorkItem?

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    let s = WCSession.default
    s.delegate = self
    s.activate()
  }

  // MARK: - Actions de l'utilisateur

  func toggle() {
    running ? stop() : start()
    push()
  }

  /// Molette : change la vitesse, renvoie le tempo à l'iPhone (après une courte pause).
  func setSpeed(_ v: Double) {
    guard v >= 60, v <= 140, v != speed else { return }
    speed = v
    pushWork?.cancel()
    let w = DispatchWorkItem { [weak self] in self?.push() }
    pushWork = w
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: w)
  }

  // MARK: - Haptique

  private func start() {
    guard !running else { return }
    running = true
    beginSession()
    generation += 1
    let gen = generation
    queue.async { [weak self] in self?.cycle(at: .now().adding(0.3), gen: gen) }
  }

  private func stop() {
    guard running else { return }
    running = false
    generation += 1
    currentBeat = nil
    endSession()
  }

  /// Un swing : départ, sommet, impact, puis pause. Les durées sont relues à
  /// chaque cycle, donc un changement de vitesse prend effet au swing suivant.
  private func cycle(at t0: DispatchTime, gen: Int) {
    guard gen == generation else { return }
    let (b, d, p) = DispatchQueue.main.sync { (self.b, self.d, self.pause) }
    fire(.start, at: t0, gen: gen)
    fire(.top, at: t0.adding(b), gen: gen)
    fire(.impact, at: t0.adding(b + d), gen: gen)
    let next = t0.adding(b + d + p)
    queue.asyncAfter(deadline: next.adding(-0.1)) { [weak self] in
      self?.cycle(at: next, gen: gen)
    }
  }

  private func fire(_ beat: Beat, at t: DispatchTime, gen: Int) {
    queue.asyncAfter(deadline: t) { [weak self] in
      guard let self, gen == self.generation else { return }
      WKInterfaceDevice.current().play(beat.haptic)
      DispatchQueue.main.async { self.currentBeat = beat.label }
    }
  }

  // MARK: - Session prolongée (continue poignet baissé)

  private func beginSession() {
    if session?.state == .running { return }
    let s = WKExtendedRuntimeSession()
    s.delegate = self
    s.start()
    session = s
  }

  private func endSession() {
    session?.invalidate()
    session = nil
  }

  func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}
  func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}
  func extendedRuntimeSession(
    _ extendedRuntimeSession: WKExtendedRuntimeSession,
    didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
    error: Error?
  ) {
    DispatchQueue.main.async { if self.session === extendedRuntimeSession { self.session = nil } }
  }

  // MARK: - Échanges avec l'iPhone

  /// Envoie l'état courant (tempo à la vitesse actuelle, marche / arrêt).
  private func push() {
    guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
    let now = Date().timeIntervalSince1970
    let msg: [String: Any] = [
      "origin": "watch", "seq": now * 1000, "sentAt": now,
      "mode": mode, "b": b, "d": d, "pause": pause, "running": running,
    ]
    let s = WCSession.default
    if s.isReachable { s.sendMessage(msg, replyHandler: nil, errorHandler: nil) }
    try? s.updateApplicationContext(msg)
  }

  /// Applique un état venu de l'iPhone. `allowStart` est faux pour un contexte
  /// ancien (relu au lancement) : la montre ne doit jamais se mettre à vibrer toute seule.
  private func apply(_ m: [String: Any], allowStart: Bool) {
    guard (m["origin"] as? String) == "phone" else { return }
    let seq = (m["seq"] as? NSNumber)?.doubleValue ?? 0
    guard seq > lastPhoneSeq else { return }
    lastPhoneSeq = seq
    let b = (m["b"] as? NSNumber)?.doubleValue ?? 0
    let d = (m["d"] as? NSNumber)?.doubleValue ?? 0
    let sentAt = (m["sentAt"] as? NSNumber)?.doubleValue ?? 0
    let fresh = Date().timeIntervalSince1970 - sentAt < 15
    DispatchQueue.main.async {
      if let md = m["mode"] as? String, md == "grand" || md == "putt" { self.mode = md }
      if b > 0, d > 0 {
        self.baseB = b
        self.baseD = d
        self.speed = 100
      }
      if let p = (m["pause"] as? NSNumber)?.doubleValue, p > 0 { self.pause = p }
      if let run = (m["running"] as? NSNumber)?.boolValue {
        if run, !self.running, allowStart, fresh { self.start() }
        if !run, self.running { self.stop() }
      }
    }
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    DispatchQueue.main.async { self.connected = session.isReachable }
    let ctx = session.receivedApplicationContext
    if !ctx.isEmpty { apply(ctx, allowStart: false) }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { self.connected = session.isReachable }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    apply(message, allowStart: true)
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    apply(applicationContext, allowStart: true)
  }
}
