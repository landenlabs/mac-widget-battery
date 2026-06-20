// Copyright (c) 2026 LanDen Labs - Dennis Lang
import IOKit.ps
import IOKit
import SwiftUI

// MARK: - BatteryInfo

struct BatteryInfo {
    var percentage:  Int    = 0
    var isCharging:  Bool   = false
    var isPluggedIn: Bool   = false
    var hasBattery:  Bool   = true
    var timeToEmpty: Int    = -1   // minutes; -1 = unknown/calculating
    var timeToFull:  Int    = -1   // minutes; -1 = not charging
    var cycleCount:  Int    = 0

    var statusText: String {
        guard hasBattery else { return "No Battery" }
        if isCharging  { return "Charging" }
        if isPluggedIn { return "Fully Charged" }
        let suffix = timeToEmpty > 0 ? " (\(formatMinutes(timeToEmpty)))" : ""
        switch percentage {
        case 50...: return "Discharging\(suffix)"
        case 20...: return "Low Battery\(suffix)"
        default:    return "Critical Battery\(suffix)"
        }
    }

    var statusColor: Color {
        guard hasBattery else { return .gray }
        if isCharging || isPluggedIn { return Color(red: 0, green: 0.85, blue: 1) }
        switch percentage {
        case 50...: return .green
        case 20...: return .yellow
        default:    return .red
        }
    }

    var batteryImageName: String {
        guard hasBattery else { return "powerplug" }
        if isCharging { return "battery.100.bolt" }
        switch percentage {
        case 75...: return "battery.100"
        case 50...: return "battery.75"
        case 25...: return "battery.50"
        case 10...: return "battery.25"
        default:    return "battery.0"
        }
    }

    var timeRemainingText: String? {
        if isCharging && timeToFull > 0 {
            return "Full in \(formatMinutes(timeToFull))"
        }
        if !isPluggedIn && !isCharging && timeToEmpty > 0 {
            return "\(formatMinutes(timeToEmpty)) remaining"
        }
        return nil
    }

    private func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60, m = mins % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - BatteryService

enum BatteryService {
    static func read() -> BatteryInfo {
        var info = BatteryInfo()

        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]

        guard !list.isEmpty else {
            info.hasBattery = false
            return info
        }

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)
                    .takeUnretainedValue() as? [String: Any] else { continue }
            guard (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            let cap    = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey]     as? Int ?? 100

            info.hasBattery  = true
            info.percentage  = maxCap > 0 ? min(100, cap * 100 / maxCap) : 0
            info.isCharging  = desc[kIOPSIsChargingKey] as? Bool ?? false
            info.isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            info.timeToEmpty = desc[kIOPSTimeToEmptyKey]       as? Int ?? -1
            info.timeToFull  = desc[kIOPSTimeToFullChargeKey]  as? Int ?? -1
            break  // first internal battery is sufficient
        }

        info.cycleCount = readCycleCount() ?? 0
        return info
    }

    private static func readCycleCount() -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props,
                                                kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any]
        else { return nil }

        return dict["CycleCount"] as? Int
    }
}
