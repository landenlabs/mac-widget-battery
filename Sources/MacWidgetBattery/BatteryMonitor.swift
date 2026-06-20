// Copyright (c) 2026 LanDen Labs - Dennis Lang
import Foundation
import Combine

final class BatteryMonitor: ObservableObject {
    @Published var info:    BatteryInfo = BatteryInfo()
    @Published var samples: [Double]    = []   // 0.0 – 100.0

    private var timer:      Timer?
    private var maxSamples: Int = 120

    func configure(sampleInterval: Double, historyMinutes: Double) {
        let interval = max(5.0, sampleInterval)
        let mins     = max(1.0, historyMinutes)
        maxSamples   = max(10, Int((mins * 60.0 / interval).rounded()))
        stop()
        start(interval: interval)
    }

    func start(interval: Double = 30.0) {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let latest = BatteryService.read()
        info = latest
        samples.append(Double(latest.percentage))
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    deinit { stop() }
}
