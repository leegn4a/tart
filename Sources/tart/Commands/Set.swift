import ArgumentParser
import Foundation
import Virtualization

struct Set: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "set", abstract: "Modify VM's configuration")

  @Argument(help: "VM name", completion: .custom(completeLocalMachines))
  var name: String

  @Option(help: "Number of VM CPUs")
  var cpu: UInt16?

  @Option(help: "VM memory size in megabytes")
  var memory: UInt64?

  @Option(help: "VM display resolution in a format of WIDTHxHEIGHT[pt|px]. For example, 1200x800, 1200x800pt or 1920x1080px. Units are treated as hints and default to \"pt\" (points) for macOS VMs and \"px\" (pixels) for Linux VMs when not specified.")
  var display: VMDisplayConfig?

  @Flag(inversion: .prefixedNo, help: ArgumentHelp("Whether to automatically reconfigure the VM's display to fit the window"))
  var displayRefit: Bool? = nil

  @Option(help: ArgumentHelp("Enable hardware-accelerated video encoding/decoding via VideoToolbox (macOS guests only). --video-toolbox=1 to enable, --video-toolbox=0 to disable."))
  var videoToolbox: UInt8?

  @Option(help: ArgumentHelp("Enable hardware-accelerated neural network inference via Apple Neural Engine (macOS guests only). --neural-engine=1 to enable, --neural-engine=0 to disable."))
  var neuralEngine: UInt8?

  @Option(help: ArgumentHelp("Allow signature mismatches for Neural Engine. --neural-engine-signature-mismatch-allowed=1 to enable, --neural-engine-signature-mismatch-allowed=0 to disable. Requires os_variant_has_internal_content(\"com.apple.virtualization\") == 1."))
  var neuralEngineSignatureMismatchAllowed: UInt8?

  @Option(help: ArgumentHelp("Enable hardware-accelerated image/video scaling via M2 Scaler (macOS guests on M2+ hosts only). --m2-scaler=1 to enable, --m2-scaler=0 to disable."))
  var m2Scaler: UInt8?

  @Option(help: ArgumentHelp("Generate a new random MAC address for the VM. --random-mac=1 to generate."))
  var randomMAC: UInt8?

  #if arch(arm64)
    @Option(help: ArgumentHelp("Generate a new random serial number for the macOS VM. Use --random-serial=1 to generate."))
  #endif
  var randomSerial: UInt8?

  #if arch(arm64)
    @Option(help: ArgumentHelp("Set a custom serial number for the macOS VM (must be exactly 10 characters). Example: --serial-number=C02XL0ABHT"))
  #endif
  var serialNumber: String?

  @Option(help: ArgumentHelp("Replace the VM's disk contents with the disk contents at path.", valueName: "path"))
  var disk: String?

  @Option(help: ArgumentHelp("Resize the VMs disk to the specified size in GB (note that the disk size can only be increased to avoid losing data)",
                             discussion: """
                             See https://tart.run/faq/#disk-resizing for more details.
                             """))
  var diskSize: UInt16?

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    var vmConfig = try VMConfig(fromURL: vmDir.configURL)

    if let cpu = cpu {
      try vmConfig.setCPU(cpuCount: Int(cpu))
    }

    if let memory = memory {
      try vmConfig.setMemory(memorySize: memory * 1024 * 1024)
    }

    if let display = display {
      if (display.width > 0) {
        vmConfig.display.width = display.width
      }
      if (display.height > 0) {
        vmConfig.display.height = display.height
      }
      vmConfig.display.unit = display.unit
    }

    vmConfig.displayRefit = displayRefit

    if let videoToolbox = videoToolbox {
      vmConfig.videoToolbox = (videoToolbox == 1)
    }

    if let neuralEngine = neuralEngine {
      vmConfig.neuralEngine = (neuralEngine == 1)
    }

    if let neuralEngineSignatureMismatchAllowed = neuralEngineSignatureMismatchAllowed {
      vmConfig.neuralEngineSignatureMismatchAllowed = (neuralEngineSignatureMismatchAllowed == 1)
    }

    if let m2Scaler = m2Scaler {
      vmConfig.m2Scaler = (m2Scaler == 1)
    }

    if let randomMAC = randomMAC, randomMAC == 1 {
      vmConfig.macAddress = VZMACAddress.randomLocallyAdministered()
    }

    #if arch(arm64)
      if let randomSerial = randomSerial, randomSerial == 1, let oldPlatform = vmConfig.platform as? Darwin {
        vmConfig.platform = Darwin(ecid: VZMacMachineIdentifier(), hardwareModel: oldPlatform.hardwareModel)
      }

      // Handle custom serial number
      if let serialNumber = serialNumber {
        // Validate serial number
        guard let macSerialNumber = MacSerialNumber(serialString: serialNumber) else {
          throw ValidationError("Invalid serial number '\(serialNumber)': must be exactly 10 characters and valid format")
        }
        
        // Store the serial number in the config
        vmConfig.serialNumber = serialNumber
        
        // Update the machine identifier with the custom serial number while preserving ECID
        if let oldPlatform = vmConfig.platform as? Darwin {
          guard let newMachineIdentifier = VZMacMachineIdentifier.create(
            withSerialNumber: macSerialNumber,
            ecid: oldPlatform.ecid.ecid  // Extract UInt64 ECID from the machine identifier
          ) else {
            throw ValidationError("Failed to create machine identifier with serial number '\(serialNumber)'")
          }
          vmConfig.platform = Darwin(ecid: newMachineIdentifier, hardwareModel: oldPlatform.hardwareModel)
        }
      }
    #endif

    try vmConfig.save(toURL: vmDir.configURL)

    if let disk = disk {
      let temporaryDiskURL = try Config().tartTmpDir.appendingPathComponent("set-disk-\(UUID().uuidString)")

      try FileManager.default.copyItem(atPath: disk, toPath: temporaryDiskURL.path())

      _ = try FileManager.default.replaceItemAt(vmDir.diskURL, withItemAt: temporaryDiskURL)
    }

    if diskSize != nil {
      try vmDir.resizeDisk(diskSize!)
    }
  }
}

extension VMDisplayConfig: ExpressibleByArgument {
  public init(argument: String) {
    var argument = argument
    var unit: Unit? = nil

    if argument.hasSuffix(Unit.pixel.rawValue) {
      argument = String(argument.dropLast(Unit.pixel.rawValue.count))
      unit = Unit.pixel
    } else if argument.hasSuffix(Unit.point.rawValue) {
      argument = String(argument.dropLast(Unit.point.rawValue.count))
      unit = Unit.point
    }

    let parts = argument.components(separatedBy: "x").map {
      Int($0) ?? 0
    }
    self = VMDisplayConfig(
      width: parts[safe: 0] ?? 0,
      height: parts[safe: 1] ?? 0,
      unit: unit,
    )
  }
}
