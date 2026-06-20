// Copyright (c) 2026 LanDen Labs - Dennis Lang
import Foundation
import AppKit
import SwiftUI

// MARK: - GraphColor

enum GraphColor: String, Codable, CaseIterable, Identifiable {
    case green  = "Green"
    case cyan   = "Cyan"
    case blue   = "Blue"
    case orange = "Orange"
    case yellow = "Yellow"
    case white  = "White"
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .green:  return .green
        case .cyan:   return .cyan
        case .blue:   return .blue
        case .orange: return .orange
        case .yellow: return .yellow
        case .white:  return .white
        }
    }
}

// MARK: - ScreenPosition

struct ScreenPosition: Codable, Equatable {
    var x: Double
    var y: Double
}

// MARK: - ScreenFingerprint

enum ScreenFingerprint {
    static var current: String {
        NSScreen.screens
            .sorted { $0.frame.minX != $1.frame.minX
                ? $0.frame.minX < $1.frame.minX
                : $0.frame.minY < $1.frame.minY }
            .map { "\(Int($0.frame.width))x\(Int($0.frame.height))@\(Int($0.frame.origin.x)),\(Int($0.frame.origin.y))" }
            .joined(separator: "|")
    }
}

// MARK: - WidgetConfig

struct WidgetConfig: Codable {
    var sampleInterval:    Double     = 30.0     // seconds between battery reads
    var historyMinutes:    Double     = 60.0     // minutes of history in graph
    var graphWidth:        Double     = 260.0
    var graphHeight:       Double     = 60.0
    var backgroundOpacity: Double     = 0.85
    var graphColor:        GraphColor = .green
    var showTitle:            Bool       = true
    var showColorBar:         Bool       = true
    var showStatusText:       Bool       = true
    var showTimeRemaining:    Bool       = true
    var showHistoryGraph:     Bool       = true
    var showBluetoothDevices: Bool       = true
    var positionX:         Double     = 40.0
    var positionY:         Double     = 400.0
    var screenPositions:   [String: ScreenPosition] = [:]

    // MARK: Computed

    var maxSamples: Int {
        max(10, Int((historyMinutes * 60.0 / sampleInterval).rounded()))
    }

    var effectiveX: Double { screenPositions[ScreenFingerprint.current]?.x ?? positionX }
    var effectiveY: Double { screenPositions[ScreenFingerprint.current]?.y ?? positionY }

    /// Pass current Bluetooth device count so the window height accounts for that section.
    func windowSize(btDeviceCount: Int = 0) -> CGSize {
        let titleH:  Double = showTitle ? 20 : 0
        let mainH:   Double = 38
        let statusH: Double = (showStatusText ? 15 : 0) + (showTimeRemaining ? 15 : 0)
        let graphH:  Double = showHistoryGraph ? graphHeight : 0
        // BT section: 14pt header + 20pt per row (18pt frame + 2pt spacing)
        let btH:     Double = showBluetoothDevices && btDeviceCount > 0
                              ? 16.0 + Double(btDeviceCount) * 20.0 : 0.0
        let height = titleH + mainH + statusH + graphH + btH + 24
        return CGSize(width: graphWidth, height: height)
    }

    // MARK: Codable (forward-compatible defaults)

    enum CodingKeys: String, CodingKey {
        case sampleInterval, historyMinutes, graphWidth, graphHeight
        case backgroundOpacity, graphColor, showTitle, showColorBar
        case showStatusText, showTimeRemaining, showHistoryGraph, showBluetoothDevices
        case positionX, positionY, screenPositions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sampleInterval       = (try? c.decode(Double.self,     forKey: .sampleInterval))       ?? 30.0
        historyMinutes       = (try? c.decode(Double.self,     forKey: .historyMinutes))       ?? 60.0
        graphWidth           = (try? c.decode(Double.self,     forKey: .graphWidth))           ?? 260.0
        graphHeight          = (try? c.decode(Double.self,     forKey: .graphHeight))          ?? 60.0
        backgroundOpacity    = (try? c.decode(Double.self,     forKey: .backgroundOpacity))    ?? 0.85
        graphColor           = (try? c.decode(GraphColor.self, forKey: .graphColor))           ?? .green
        showTitle            = (try? c.decode(Bool.self,       forKey: .showTitle))            ?? true
        showColorBar         = (try? c.decode(Bool.self,       forKey: .showColorBar))         ?? true
        showStatusText       = (try? c.decode(Bool.self,       forKey: .showStatusText))       ?? true
        showTimeRemaining    = (try? c.decode(Bool.self,       forKey: .showTimeRemaining))    ?? true
        showHistoryGraph     = (try? c.decode(Bool.self,       forKey: .showHistoryGraph))     ?? true
        showBluetoothDevices = (try? c.decode(Bool.self,       forKey: .showBluetoothDevices)) ?? true
        positionX            = (try? c.decode(Double.self,     forKey: .positionX))            ?? 40.0
        positionY            = (try? c.decode(Double.self,     forKey: .positionY))            ?? 400.0
        screenPositions      = (try? c.decode([String: ScreenPosition].self,
                                              forKey: .screenPositions))                       ?? [:]
    }

    init() {}
}
