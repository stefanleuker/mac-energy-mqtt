import Foundation

// IOReport is a private but long-stable Apple library (libIOReport.dylib).
// It exposes the SoC energy counters that `powermetrics` reports, without needing root.

@_silgen_name("IOReportCopyChannelsInGroup")
func IOReportCopyChannelsInGroup(_ group: CFString?, _ subgroup: CFString?, _ a: UInt64, _ b: UInt64, _ c: UInt64) -> Unmanaged<CFMutableDictionary>?

@_silgen_name("IOReportCreateSubscription")
func IOReportCreateSubscription(_ allocator: UnsafeRawPointer?, _ desiredChannels: CFMutableDictionary, _ subscribedChannels: UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, _ channelID: UInt64, _ options: CFTypeRef?) -> UnsafeMutableRawPointer?

@_silgen_name("IOReportCreateSamples")
func IOReportCreateSamples(_ subscription: UnsafeMutableRawPointer, _ subscribedChannels: CFMutableDictionary, _ options: CFTypeRef?) -> Unmanaged<CFDictionary>?

@_silgen_name("IOReportCreateSamplesDelta")
func IOReportCreateSamplesDelta(_ previous: CFDictionary, _ current: CFDictionary, _ options: CFTypeRef?) -> Unmanaged<CFDictionary>?

@_silgen_name("IOReportChannelGetChannelName")
func IOReportChannelGetChannelName(_ channel: CFDictionary) -> Unmanaged<CFString>?

@_silgen_name("IOReportChannelGetUnitLabel")
func IOReportChannelGetUnitLabel(_ channel: CFDictionary) -> Unmanaged<CFString>?

@_silgen_name("IOReportSimpleGetIntegerValue")
func IOReportSimpleGetIntegerValue(_ channel: CFDictionary, _ index: Int32) -> Int64
