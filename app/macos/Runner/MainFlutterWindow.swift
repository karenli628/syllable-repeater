// AI-Generate
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.contentMinSize = NSSize(width: 1100, height: 700)
    if self.contentLayoutRect.width < self.contentMinSize.width ||
        self.contentLayoutRect.height < self.contentMinSize.height {
      self.setContentSize(self.contentMinSize)
      self.center()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
