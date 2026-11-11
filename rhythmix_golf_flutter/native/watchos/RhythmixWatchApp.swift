import SwiftUI

/// App watchOS de Rhythmix Golf : joue le tempo du swing en vibrations au poignet.
/// Le tempo (durées de montée / descente) vient de l'iPhone ; la molette
/// (Digital Crown) règle la vitesse et renvoie le nouveau tempo à l'iPhone.
@main
struct RhythmixWatchApp: App {
  @StateObject private var model = TempoModel()

  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(model)
    }
  }
}
