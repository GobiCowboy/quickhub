import AppKit

// 将 delegate 提升为全局持有，防止其被 ARC 意外回收导致 EXC_BAD_ACCESS
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

// 启动应用主循环
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
