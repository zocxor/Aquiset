// watchOS companion (starter): today's water at a glance and one-tap logging.
// Data arrives from the phone via WatchConnectivity application context;
// logs go back with transferUserInfo, which queues while the phone is away.
// AlarmKit alarms appear on the watch automatically; no code needed here.

import SwiftUI
import WatchConnectivity

@main
struct AquisetWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchHome().environmentObject(model)
        }
    }
}

final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var totalMl = 0
    @Published var goalMl = 2000
    @Published var bedtime = "—"
    @Published var wake = "—"

    var progress: Double { goalMl > 0 ? min(1, Double(totalMl) / Double(goalMl)) : 0 }

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func log(_ ml: Int) {
        totalMl += ml
        WCSession.default.transferUserInfo(["logMl": ml])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ context: [String: Any]) {
        DispatchQueue.main.async {
            self.totalMl = (context["totalMl"] as? NSNumber)?.intValue ?? self.totalMl
            self.goalMl = (context["goalMl"] as? NSNumber)?.intValue ?? self.goalMl
            self.bedtime = context["bedtimeLabel"] as? String ?? self.bedtime
            self.wake = context["wakeLabel"] as? String ?? self.wake
        }
    }
}

struct WatchHome: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Gauge(value: model.progress) {
                    Image(systemName: "drop.fill")
                } currentValueLabel: {
                    Text("\(model.totalMl)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.cyan)
                .accessibilityLabel("\(model.totalMl) of \(model.goalMl) millilitres")

                Text("of \(model.goalMl) ml · your goal").font(.footnote).foregroundStyle(.secondary)

                Button { model.log(250) } label: { Label("Glass · 250 ml", systemImage: "plus") }
                Button { model.log(500) } label: { Label("Bottle · 500 ml", systemImage: "plus") }

                Label("Bed \(model.bedtime) · Alarm \(model.wake)", systemImage: "moon.stars")
                    .font(.footnote)
                    .padding(.top, 4)
            }
        }
        .navigationTitle("AQUISET")
    }
}
