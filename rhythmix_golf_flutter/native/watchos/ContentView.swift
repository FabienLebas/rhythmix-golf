import SwiftUI

struct ContentView: View {
  @EnvironmentObject var model: TempoModel
  @State private var crown: Double = 100

  private var accent: Color { model.mode == "grand" ? .green : .blue }

  var body: some View {
    VStack(spacing: 6) {
      Text(model.mode == "grand" ? "Grand jeu" : "Putting")
        .font(.headline)
        .foregroundStyle(accent)

      Text("\(fmt(model.b)) s · \(fmt(model.d)) s")
        .font(.title3.monospacedDigit())

      Text("Vitesse \(Int(model.speed)) %")
        .font(.footnote)
        .foregroundStyle(.secondary)

      Text(model.running ? (model.currentBeat ?? " ") : " ")
        .font(.caption)
        .foregroundStyle(accent)

      Button(model.running ? "Arrêter" : "Démarrer") { model.toggle() }
        .tint(model.running ? .red : accent)

      if !model.connected {
        Text("iPhone non joignable")
          .font(.caption2)
          .foregroundStyle(.orange)
      }
    }
    .focusable()
    .digitalCrownRotation(
      $crown, from: 60, through: 140, by: 1,
      sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
    .onChange(of: crown) { _, v in model.setSpeed(v) }
    .onChange(of: model.speed) { _, v in if v != crown { crown = v } }
    .onAppear { crown = model.speed }
  }

  private func fmt(_ x: Double) -> String {
    String(format: "%.2f", x).replacingOccurrences(of: ".", with: ",")
  }
}
