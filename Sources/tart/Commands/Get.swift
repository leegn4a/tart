import ArgumentParser
import Foundation

fileprivate struct VMInfo: Encodable {
  let OS: OS
  let CPU: Int
  let Memory: UInt64
  let Disk: Int
  let DiskFormat: String
  let Size: String
  let Display: String
  let Running: Bool
  let State: String
  let VideoToolbox: Bool
  let NeuralEngine: Bool
  let NeuralEngineSignatureMismatchAllowed: Bool
  let M2Scaler: Bool
  let SerialNumber: String?
}

struct Get: AsyncParsableCommand {
  static var configuration = CommandConfiguration(commandName: "get", abstract: "Get a VM's configuration")

  @Argument(help: "VM name.", completion: .custom(completeLocalMachines))
  var name: String

  @Option(help: "Output format: text or json")
  var format: Format = .text

  func run() async throws {
    let vmDir = try VMStorageLocal().open(name)
    let vmConfig = try VMConfig(fromURL: vmDir.configURL)
    let memorySizeInMb = vmConfig.memorySize / 1024 / 1024

    let info = VMInfo(OS: vmConfig.os, CPU: vmConfig.cpuCount, Memory: memorySizeInMb, Disk: try vmDir.sizeGB(), DiskFormat: vmConfig.diskFormat.rawValue, Size: String(format: "%.3f", Float(try vmDir.allocatedSizeBytes()) / 1000 / 1000 / 1000), Display: vmConfig.display.description, Running: try vmDir.running(), State: try vmDir.state().rawValue, VideoToolbox: vmConfig.videoToolbox, NeuralEngine: vmConfig.neuralEngine, NeuralEngineSignatureMismatchAllowed: vmConfig.neuralEngineSignatureMismatchAllowed, M2Scaler: vmConfig.m2Scaler, SerialNumber: vmConfig.serialNumber)
    print(format.renderSingle(info))
  }
}
