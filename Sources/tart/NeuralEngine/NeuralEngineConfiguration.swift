import Foundation
import Dynamic
import Virtualization

#if arch(arm64)

/// Wrapper for the private _VZMacNeuralEngineDeviceConfiguration API
/// This enables hardware-accelerated neural network inference in macOS guest VMs
/// using the Apple Neural Engine (ANE)
///
/// The Neural Engine uses a per-VM cache directory based on the ECID:
/// ~/Library/Caches/com.apple.appleneuralengine-<ECID>/
class NeuralEngineConfiguration {
  /// Create a Neural Engine device configuration
  /// - Parameter signatureMismatchAllowed: Whether to allow signature mismatches (useful for development/testing)
  ///   Default is false (signatures are validated) for production/security
  /// - Returns: The configured device object, or nil if not supported
  static func createDeviceConfiguration(signatureMismatchAllowed: Bool = false) -> Any? {
    // Create an instance of _VZMacNeuralEngineDeviceConfiguration
    let config = Dynamic._VZMacNeuralEngineDeviceConfiguration()
    
    // Set the signature mismatch property explicitly
    // Note: By default, signature validation is enabled (signatureMismatchAllowed = false)
    // Only set to true for development/testing when you need to bypass signature checks
    config._setSignatureMismatchAllowed(signatureMismatchAllowed)
    
    return config.asObject
  }
  
  /// Get the ECID from a machine identifier for cache directory purposes
  /// The Neural Engine creates a cache at: ~/Library/Caches/com.apple.appleneuralengine-<ECID>/
  /// - Parameter machineIdentifier: The VZMacMachineIdentifier to extract ECID from
  /// - Returns: The ECID as a UInt64, or nil if not available
  static func getECID(from machineIdentifier: VZMacMachineIdentifier) -> UInt64? {
    return machineIdentifier.ecid
  }
  
  /// Get the expected cache directory path for a given machine identifier
  /// - Parameter machineIdentifier: The VZMacMachineIdentifier
  /// - Returns: The expected cache directory path, or nil if ECID is not available
  static func getCacheDirectoryPath(for machineIdentifier: VZMacMachineIdentifier) -> String? {
    guard let ecid = getECID(from: machineIdentifier) else {
      return nil
    }
    
    // Get user cache directory
    let cacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? ""
    
    // Build path: <cacheDir>/com.apple.appleneuralengine-<ECID>
    let aneCachePath = (cacheDir as NSString).appendingPathComponent("com.apple.appleneuralengine-\(ecid)")
    
    return aneCachePath
  }
  
  /// Add Neural Engine device to the VM configuration
  /// - Parameters:
  ///   - configuration: The VZVirtualMachineConfiguration to modify
  ///   - signatureMismatchAllowed: Whether to allow signature mismatches (default: false for production)
  /// - Returns: true if Neural Engine device was added, false otherwise
  @discardableResult
  static func addToConfiguration(
    _ configuration: VZVirtualMachineConfiguration,
    signatureMismatchAllowed: Bool = false
  ) -> Bool {
    guard let neConfig = createDeviceConfiguration(signatureMismatchAllowed: signatureMismatchAllowed) else {
      return false
    }
    
    // Use Key-Value Coding to access the private _acceleratorDevices property
    let dynamicConfig = Dynamic(configuration)
    
    // Get existing accelerator devices (if any)
    var accelerators: [Any] = []
    if let existing = dynamicConfig._acceleratorDevices.asObject as? [Any] {
      accelerators = existing
    }
    
    // Add the Neural Engine device
    accelerators.append(neConfig)
    
    // Set the accelerator devices array
    dynamicConfig._setAcceleratorDevices(accelerators)
    
    return true
  }
}

#endif
