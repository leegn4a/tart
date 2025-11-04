import Foundation
import Dynamic
import Virtualization

#if arch(arm64)

/// Wrapper for the private _VZMacVideoToolboxDeviceConfiguration API
/// This enables hardware-accelerated video encoding/decoding in macOS guest VMs
class VideoToolboxConfiguration {
  /// Check if VideoToolbox paravirtualization is supported on the current platform
  static func isSupported() -> Bool {
    // Call the private _isSupported class method
    let configClass = Dynamic._VZMacVideoToolboxDeviceConfiguration
    if let isSupported = configClass._isSupported.asBool {
      return isSupported
    }
    return false
  }
  
  /// Create a VideoToolbox device configuration
  /// Returns nil if VideoToolbox is not supported on this platform
  static func createDeviceConfiguration() -> Any? {
    guard isSupported() else {
      return nil
    }
    
    // Create an instance of _VZMacVideoToolboxDeviceConfiguration
    let config = Dynamic._VZMacVideoToolboxDeviceConfiguration()
    return config.asObject
  }
  
  /// Add VideoToolbox device to the VM configuration if supported
  /// - Parameter configuration: The VZVirtualMachineConfiguration to modify
  /// - Returns: true if VideoToolbox device was added, false otherwise
  @discardableResult
  static func addToConfiguration(_ configuration: VZVirtualMachineConfiguration) -> Bool {
    guard let vtConfig = createDeviceConfiguration() else {
      return false
    }
    
    // Use Key-Value Coding to access the private _acceleratorDevices property
    let dynamicConfig = Dynamic(configuration)
    
    // Get existing accelerator devices (if any)
    var accelerators: [Any] = []
    if let existing = dynamicConfig._acceleratorDevices.asObject as? [Any] {
      accelerators = existing
    }
    
    // Add the VideoToolbox device
    accelerators.append(vtConfig)
    
    // Set the accelerator devices array
    dynamicConfig._setAcceleratorDevices(accelerators)
    
    return true
  }
}

#endif
