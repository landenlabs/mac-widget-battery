// Copyright (c) 2026 LanDen Labs - Dennis Lang
import Foundation

final class BluetoothMonitor: ObservableObject {
    @Published var devices: [BluetoothDeviceInfo] = []

    private var timer: Timer?

    func start(interval: Double = 30.0) {
        refresh()
        let effectiveInterval = max(10.0, interval)
        timer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let found = BluetoothBatteryService.connectedDevices()
            DispatchQueue.main.async { self?.devices = found }
        }
    }

    deinit { stop() }
}
