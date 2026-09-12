import Foundation
import IOKit

/// Thin wrapper over the IOKit registry for the few services mcenergy reads.
public enum IOKitRegistry {
    public static func properties(ofService className: String) -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(className))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        let status = IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
        guard status == KERN_SUCCESS, let dictionary = unmanaged?.takeRetainedValue() else { return nil }
        return dictionary as? [String: Any]
    }

    public static func platformSerialNumber() -> String? {
        properties(ofService: "IOPlatformExpertDevice")?["IOPlatformSerialNumber"] as? String
    }
}
