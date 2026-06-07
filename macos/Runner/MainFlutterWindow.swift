import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// 初始化主 Flutter 窗口并配置初始窗口大小与居中显示
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 1280, height: 800)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    self.title = "布丁发布"
    self.center()
  }
}
