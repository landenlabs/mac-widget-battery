// Copyright (c) 2026 LanDen Labs - Dennis Lang
import SwiftUI

struct ContentView: View {
    @ObservedObject var monitor:   BatteryMonitor
    @ObservedObject var appState:  AppState
    @ObservedObject var btMonitor: BluetoothMonitor

    private var cfg:   WidgetConfig { appState.config }
    private var info:  BatteryInfo  { monitor.info }
    private var color: Color        { cfg.graphColor.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if cfg.showTitle { titleRow }
            batteryRow
            if cfg.showStatusText || cfg.showTimeRemaining { statusRow }
            if cfg.showHistoryGraph {
                BatteryGraphView(samples: monitor.samples, color: color)
                    .frame(height: cfg.graphHeight)
            }
            if cfg.showBluetoothDevices && !btMonitor.devices.isEmpty {
                btDevicesSection
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(cfg.backgroundOpacity))
        )
        .frame(width: cfg.graphWidth)
    }

    // MARK: - Mac battery sub-views

    private var titleRow: some View {
        HStack {
            Text("🔋 Battery")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.40))
            Spacer()
        }
        .frame(height: 20)
    }

    private var batteryRow: some View {
        HStack(spacing: 8) {
            Image(systemName: info.batteryImageName)
                .font(.system(size: 20))
                .foregroundColor(info.statusColor)
                .frame(width: 28)

            Text(info.hasBattery ? "\(info.percentage)%" : "—")
                .font(.system(size: 20, design: .monospaced).weight(.bold))
                .foregroundColor(info.statusColor)

            if cfg.showColorBar { colorBar }
        }
        .frame(height: 32)
    }

    private var colorBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 4)
                    .fill(info.statusColor.opacity(0.85))
                    .frame(width: geo.size.width
                           * CGFloat(min(100, max(0, info.percentage))) / 100)
            }
        }
        .frame(height: 14)
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 1) {
            if cfg.showStatusText {
                Text(info.statusText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.60))
                    .frame(height: 15, alignment: .top)
            }
            if cfg.showTimeRemaining {
                Text(info.timeRemainingText ?? " ")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(height: 15, alignment: .top)
            }
        }
    }

    // MARK: - Bluetooth devices section

    private var btDevicesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Bluetooth")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.30))
                .frame(height: 14)
            ForEach(btMonitor.devices) { device in
                BluetoothDeviceRow(device: device)
            }
        }
    }
}

// MARK: - BluetoothDeviceRow

private struct BluetoothDeviceRow: View {
    let device: BluetoothDeviceInfo

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 14)

            Text(device.name)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.80))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            Text(device.batteryLevel >= 0 ? "\(device.batteryLevel)%" : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(batteryColor)
                .frame(width: 32, alignment: .trailing)

            if device.batteryLevel >= 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(batteryColor.opacity(0.85))
                            .frame(width: geo.size.width * CGFloat(device.batteryLevel) / 100)
                    }
                }
                .frame(width: 52, height: 8)
            } else {
                // placeholder keeps row width stable when battery is unknown
                Spacer().frame(width: 52)
            }
        }
        .frame(height: 18)
    }

    private var iconName: String {
        let lower = device.name.lowercased()
        if lower.contains("keyboard")              { return "keyboard" }
        if lower.contains("mouse")                 { return "computermouse" }
        if lower.contains("trackpad")              { return "trackpad" }
        if lower.contains("airpod") ||
           lower.contains("earbud")                { return "airpodspro" }
        if lower.contains("headphone") ||
           lower.contains("headset")               { return "headphones" }
        return "dot.radiowaves.left.and.right"
    }

    private var batteryColor: Color {
        guard device.batteryLevel >= 0 else { return .gray }
        switch device.batteryLevel {
        case 50...: return .green
        case 20...: return .yellow
        default:    return .red
        }
    }
}
