import Foundation
import Dynamic
import Virtualization

#if arch(arm64)

/// Wrapper for the private _VZMacSerialNumber class
/// Represents a 10-byte serial number for macOS virtual machines
class MacSerialNumber {
  private let dynamicSerial: Dynamic
  private let serialString: String
  
  /// Create a serial number from a string
  /// - Parameter serialString: A 10-character serial number string (e.g., "C02XL0ABHT")
  /// - Returns: A MacSerialNumber instance, or nil if the format is invalid
  init?(serialString: String) {
    guard serialString.count == 10 else {
      return nil
    }
    
    // Create _VZMacSerialNumber using initWithString: class method
    // The Dynamic library translates this to [[_VZMacSerialNumber alloc] initWithString:]
    let serial = Dynamic._VZMacSerialNumber.initWithString(serialString)
    
    // Check if initialization succeeded (returns nil for invalid format)
    guard serial.asObject != nil else {
      return nil
    }
    
    self.serialString = serialString
    self.dynamicSerial = serial
  }
  
  /// Create a wrapper around an existing _VZMacSerialNumber object
  /// - Parameter dynamicObject: The Dynamic wrapper of _VZMacSerialNumber
  /// - Parameter serialString: The serial string (needed since we can't reliably extract it from the dynamic object)
  init(dynamicObject: Dynamic, serialString: String) {
    self.dynamicSerial = dynamicObject
    self.serialString = serialString
  }
  
  /// Get the serial number as a string
  var string: String {
    return serialString
  }
  
  /// Get the underlying Dynamic object for use with other APIs
  var asObject: Any {
    return dynamicSerial.asObject!
  }
  
  /// Generate a random valid-looking serial number
  /// Format: CYYXXXXXXX where C=model code, YY=year, X=alphanumeric
  /// - Returns: A MacSerialNumber with a randomly generated serial
  static func random() -> MacSerialNumber {
    let modelCodes = ["C", "D", "F", "G", "J", "K"]
    let years = Array(20...25).map { String(format: "%02d", $0) }
    let chars = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ" // Excluding I and O
    
    let modelCode = modelCodes.randomElement()!
    let year = years.randomElement()!
    let random7 = (0..<7).map { _ in chars.randomElement()! }
    
    let serialString = modelCode + year + String(random7)
    return MacSerialNumber(serialString: serialString)!
  }
}

/// Extension to VZMacMachineIdentifier for serial number support
extension VZMacMachineIdentifier {
  /// Get the serial number from a machine identifier (private API)
  func getSerialNumber() -> MacSerialNumber? {
    let dynamicId = Dynamic(self)
    
    // Call private _serialNumber method
    if let serialObj = dynamicId._serialNumber().asObject {
      // Try to get the string representation from the description
      // _VZMacSerialNumber's description returns the serial string
      let serialString = String(describing: serialObj)
      
      // Create a new MacSerialNumber with the extracted string
      // This validates the format and creates a proper wrapper
      return MacSerialNumber(serialString: serialString)
    }
    
    return nil
  }
  
  /// Create a machine identifier with a specific serial number
  /// - Parameters:
  ///   - serialNumber: The serial number to use
  ///   - ecid: Optional ECID (if nil, a random one will be generated)
  /// - Returns: A new VZMacMachineIdentifier with the serial number
  static func create(withSerialNumber serialNumber: MacSerialNumber, ecid: UInt64? = nil) -> VZMacMachineIdentifier? {
    let serialObj = serialNumber.asObject
    
    if let ecid = ecid {
      // Create with specific ECID
      let identifier = Dynamic.VZMacMachineIdentifier._machineIdentifierWithECID(ecid, serialNumber: serialObj)
      return identifier.asObject as? VZMacMachineIdentifier
    } else {
      // Create with random ECID
      let identifier = Dynamic.VZMacMachineIdentifier._machineIdentifierWithSerialNumber(serialObj)
      return identifier.asObject as? VZMacMachineIdentifier
    }
  }
  
  /// Create a machine identifier for VM cloning (disables ECID checks)
  /// - Parameters:
  ///   - serialNumber: The serial number to use (typically same as original VM)
  ///   - ecid: Optional ECID (if nil, a random one will be generated)
  /// - Returns: A new VZMacMachineIdentifier suitable for cloning
  static func createForClone(withSerialNumber serialNumber: MacSerialNumber, ecid: UInt64? = nil) -> VZMacMachineIdentifier? {
    let serialObj = serialNumber.asObject
    
    if let ecid = ecid {
      // Create clone with specific ECID
      let identifier = Dynamic.VZMacMachineIdentifier._machineIdentifierForVirtualMachineCloneWithECID(ecid, serialNumber: serialObj)
      return identifier.asObject as? VZMacMachineIdentifier
    } else {
      // Create clone with random ECID
      let identifier = Dynamic.VZMacMachineIdentifier._machineIdentifierForVirtualMachineCloneWithSerialNumber(serialObj)
      return identifier.asObject as? VZMacMachineIdentifier
    }
  }
  
  /// Get the ECID from a machine identifier
  var ecid: UInt64 {
    let dynamicId = Dynamic(self)
    return dynamicId._ECID.asUInt64 ?? 0
  }
}

#endif
