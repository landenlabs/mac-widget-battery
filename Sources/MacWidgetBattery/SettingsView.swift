// Copyright (c) 2026 LanDen Labs - Dennis Lang
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    private var cfg: Binding<WidgetConfig> {
        Binding(get: { appState.config }, set: { appState.config = $0 })
    }

    var body: some View {
        Form {
            Section("Sampling") {
                Picker("Sample interval", selection: cfg.sampleInterval) {
                    Text("5 s").tag(5.0)
                    Text("10 s").tag(10.0)
                    Text("30 s").tag(30.0)
                    Text("1 min").tag(60.0)
                    Text("5 min").tag(300.0)
                }
                .pickerStyle(.menu)

                Picker("History window", selection: cfg.historyMinutes) {
                    Text("15 min").tag(15.0)
                    Text("30 min").tag(30.0)
                    Text("1 hr").tag(60.0)
                    Text("2 hr").tag(120.0)
                    Text("4 hr").tag(240.0)
                    Text("8 hr").tag(480.0)
                }
                .pickerStyle(.menu)

                Text("\(appState.config.maxSamples) samples stored")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Graph Size") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Width: \(Int(appState.config.graphWidth)) pt")
                        .font(.caption).foregroundColor(.secondary)
                    Slider(value: cfg.graphWidth, in: 160...500, step: 10)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height: \(Int(appState.config.graphHeight)) pt")
                        .font(.caption).foregroundColor(.secondary)
                    Slider(value: cfg.graphHeight, in: 30...200, step: 5)
                }
            }

            Section("Appearance") {
                Picker("Graph color", selection: cfg.graphColor) {
                    ForEach(GraphColor.allCases) { c in
                        HStack(spacing: 6) {
                            Circle().fill(c.color).frame(width: 10, height: 10)
                            Text(c.rawValue)
                        }
                        .tag(c)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Background opacity: \(Int(appState.config.backgroundOpacity * 100))%")
                        .font(.caption).foregroundColor(.secondary)
                    Slider(value: cfg.backgroundOpacity, in: 0...1, step: 0.05)
                }
            }

            Section("Display") {
                Toggle("Show title",             isOn: cfg.showTitle)
                Toggle("Show color bar",         isOn: cfg.showColorBar)
                Toggle("Show status text",       isOn: cfg.showStatusText)
                Toggle("Show time remaining",    isOn: cfg.showTimeRemaining)
                Toggle("Show history graph",     isOn: cfg.showHistoryGraph)
                Toggle("Show Bluetooth devices", isOn: cfg.showBluetoothDevices)
            }

            Section("System") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 320, minHeight: 520)
    }

    // MARK: - Login item helpers

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "launchAtLogin") },
            set: { enabled in
                UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
                setLoginItem(enabled: enabled)
            }
        )
    }

    private func setLoginItem(enabled: Bool) {
        let path   = Bundle.main.bundlePath
        let script = enabled
            ? "tell application \"System Events\" to make login item at end with properties {path:\"\(path)\", hidden:false}"
            : "tell application \"System Events\" to delete (every login item whose path is \"\(path)\")"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }
}
