// Copyright (c) 2026 LanDen Labs - Dennis Lang
import IOKit
import IOBluetooth
import Foundation

// MARK: - BluetoothDeviceInfo

struct BluetoothDeviceInfo: Identifiable {
    var id: String { address.isEmpty ? name : address }
    let name:         String
    let address:      String
    let batteryLevel: Int   // 0–100, or -1 = unknown
}

// MARK: - BluetoothBatteryService

enum BluetoothBatteryService {

    /// Returns currently-connected Bluetooth devices with battery info where available.
    static func connectedDevices() -> [BluetoothDeviceInfo] {
        var results: [BluetoothDeviceInfo] = []
        var seen     = Set<String>()

        // Pass 1: IORegistry HID drivers — covers Magic accessories, AirPods, many headphones.
        // Only entries that expose "BatteryPercent" are included.
        let driverClasses = [
            "AppleHSBluetoothHIDDriver",
            "AppleBluetoothHIDDriver",
            "AppleDeviceManagementHIDEventService",
            "IOBluetoothHIDDriver",
        ]
        for cls in driverClasses {
            results += scanRegistry(forClass: cls, seen: &seen)
        }

        // Pass 2: IOBluetooth connected devices — adds anything the registry scan missed,
        // shown with an unknown battery level.
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        for dev in paired where dev.isConnected() {
            let name = dev.name ?? "Unknown"
            guard !seen.contains(name) else { continue }
            seen.insert(name)
            results.append(BluetoothDeviceInfo(
                name:         name,
                address:      dev.addressString ?? "",
                batteryLevel: -1
            ))
        }

        return results.sorted { $0.name < $1.name }
    }

    // MARK: - Private

    private static func scanRegistry(
        forClass className: String,
        seen: inout Set<String>
    ) -> [BluetoothDeviceInfo] {
        var results: [BluetoothDeviceInfo] = []
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching(className), &iter
        ) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iter) }

        while case let svc = IOIteratorNext(iter), svc != IO_OBJECT_NULL {
            defer { IOObjectRelease(svc) }
            var propsCF: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                svc, &propsCF, kCFAllocatorDefault, 0
            ) == KERN_SUCCESS,
                  let dict    = propsCF?.takeRetainedValue() as? [String: Any],
                  let battery = dict["BatteryPercent"] as? Int
            else { continue }

            let name = dict["Product"]    as? String
                    ?? dict["DeviceName"] as? String
                    ?? "Unknown"
            guard !seen.contains(name) else { continue }
            seen.insert(name)

            let addr = dict["DeviceAddress"]          as? String
                    ?? dict["BluetoothDeviceAddress"] as? String
                    ?? ""
            results.append(BluetoothDeviceInfo(name: name, address: addr, batteryLevel: battery))
        }
        return results
    }
}
