// Copyright (c) 2026 LanDen Labs - Dennis Lang
import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private let appState   = AppState.shared
    private let monitor    = BatteryMonitor()
    private let btMonitor  = BluetoothMonitor()

    private var windowManager:            DesktopWindowManager?
    private var settingsWindowController: NSWindowController?
    private var aboutWindowController:    NSWindowController?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let cfg = appState.config
        monitor.configure(sampleInterval: cfg.sampleInterval,
                          historyMinutes: cfg.historyMinutes)
        btMonitor.start(interval: cfg.sampleInterval)

        // Reconfigure monitors when sampling parameters change
        appState.$config
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cfg in
                self?.monitor.configure(sampleInterval: cfg.sampleInterval,
                                        historyMinutes: cfg.historyMinutes)
                self?.btMonitor.stop()
                self?.btMonitor.start(interval: cfg.sampleInterval)
            }
            .store(in: &cancellables)

        windowManager = DesktopWindowManager(appState: appState, monitor: monitor, btMonitor: btMonitor)
        windowManager?.setup()

        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Status Bar

    private var statusItem: NSStatusItem?

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        monitor.$info
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in self?.updateStatusIcon(info) }
            .store(in: &cancellables)
    }

    private func updateStatusIcon(_ info: BatteryInfo) {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(
            systemSymbolName: info.batteryImageName,
            accessibilityDescription: info.statusText
        )
        button.contentTintColor = nsColor(for: info)
    }

    private func nsColor(for info: BatteryInfo) -> NSColor {
        guard info.hasBattery else { return .systemGray }
        if info.isCharging || info.isPluggedIn { return NSColor(red: 0, green: 0.85, blue: 1, alpha: 1) }
        switch info.percentage {
        case 50...: return .systemGreen
        case 20...: return .systemYellow
        default:    return .systemRed
        }
    }

    // MARK: - Window helpers

    private func openWindow(
        width: CGFloat, height: CGFloat,
        title: String,
        rootView: some View,
        styleMask: NSWindow.StyleMask = [.titled, .closable],
        controller: inout NSWindowController?
    ) {
        if controller == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask:   styleMask,
                backing:     .buffered,
                defer:       false
            )
            win.title       = title
            win.contentView = NSHostingView(rootView: rootView)
            win.center()
            let wc = NSWindowController(window: win)
            controller = wc
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: win, queue: .main
            ) { [weak self] _ in
                if self?.settingsWindowController?.window === win { self?.settingsWindowController = nil }
                if self?.aboutWindowController?.window    === win { self?.aboutWindowController    = nil }
            }
        }
        controller?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @objc func toggleDragMode() {
        windowManager?.toggleDragMode()
    }

    @objc func openSettings() {
        openWindow(
            width: 360, height: 560,
            title: "Battery Widget — Settings",
            rootView: SettingsView(appState: appState),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            controller: &settingsWindowController
        )
    }

    @objc func openAbout() {
        openWindow(
            width: 480, height: 540,
            title: "About Battery Widget",
            rootView: AboutView(),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            controller: &aboutWindowController
        )
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginEnabled.toggle()
        setLoginItem(enabled: launchAtLoginEnabled)
    }

    private var launchAtLoginEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "launchAtLogin") }
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

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(titleItem("Wid-Battery"))
        menu.addItem(.separator())

        let dragging  = windowManager?.isDragging ?? false
        let moveTitle = dragging ? "Done Moving Widget" : "Move Widget…"
        menu.addItem(item(moveTitle, action: #selector(toggleDragMode)))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(item("About…",    action: #selector(openAbout)))
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login",
                                   action: #selector(toggleLaunchAtLogin),
                                   keyEquivalent: "")
        loginItem.state  = launchAtLoginEnabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        menu.addItem(.separator())
        menu.addItem(versionItem())
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        return it
    }

    /// Bold, non-clickable title shown at the top of the menu.
    private func titleItem(_ title: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)])
        it.isEnabled = false
        return it
    }

    /// Small, light, non-clickable version label shown at the bottom of the menu.
    private func versionItem() -> NSMenuItem {
        let text = "v\(appVersion)"
        let it = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        it.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.secondaryLabelColor])
        it.isEnabled = false
        return it
    }
}
