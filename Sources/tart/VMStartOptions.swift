struct VMStartOptions {
    var startUpFromMacOSRecovery: Bool
    var forceDFU: Bool
    var haltOnFatalError: Bool
    var haltOnPanic: Bool
    var haltOnIbootStage1: Bool
    var haltOnIbootStage2: Bool
}