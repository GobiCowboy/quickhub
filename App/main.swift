import AppKit

// 这里必须定义在顶级作用域以确保全局持有，防止 AppDelegate 被释放
// NSApplication.delegate 是弱引用，如果这里不持有，Delegate 会在 app.run() 开始不久后被销毁
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
