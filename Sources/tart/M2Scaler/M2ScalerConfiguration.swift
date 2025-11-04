import Foundation
import Dynamic
import Virtualization

#if arch(arm64)

/// Wrapper for the private _VZMacScalerAcceleratorDeviceConfiguration API
/// This enables hardware-accelerated image/video scaling in macOS guest VMs
/// using the M2 (and newer) Scaler hardware
///
/// This is the simplest accelerator configuration with no configurable properties.
/// The M2 Scaler provides dedicated hardware for high-quality, high-performance
/// image scaling operations.
class M2ScalerConfiguration {
  /// Create an M2 Scaler device configuration
  /// - Returns: The configured device object, or nil if not supported
  static func createDeviceConfiguration() -> Any? {
    // Create an instance of _VZMacScalerAcceleratorDeviceConfiguration
    // This is stateless - no properties to configure
    let config = Dynamic._VZMacScalerAcceleratorDeviceConfiguration()
    
    return config.asObject
  }
  
  /// Add M2 Scaler device to the VM configuration
  /// - Parameter configuration: The VZVirtualMachineConfiguration to modify
  /// - Returns: true if M2 Scaler device was added, false otherwise
  @discardableResult
  static func addToConfiguration(_ configuration: VZVirtualMachineConfiguration) -> Bool {
    guard let scalerConfig = createDeviceConfiguration() else {
      return false
    }
    
    // Use Key-Value Coding to access the private _acceleratorDevices property
    let dynamicConfig = Dynamic(configuration)
    
    // Get existing accelerator devices (if any)
    var accelerators: [Any] = []
    if let existing = dynamicConfig._acceleratorDevices.asObject as? [Any] {
      accelerators = existing
    }
    
    // Add the M2 Scaler device
    accelerators.append(scalerConfig)
    
    // Set the accelerator devices array
    dynamicConfig._setAcceleratorDevices(accelerators)
    
    return true
  }
}

#endif
