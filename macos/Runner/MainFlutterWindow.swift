import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    
    // Set fixed window size: 1080x2340
    let fixedWidth: CGFloat = 1080
    let fixedHeight: CGFloat = 2340
    
    // Calculate window frame centered on screen
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let x = (screenRect.width - fixedWidth) / 2 + screenRect.origin.x
      let y = (screenRect.height - fixedHeight) / 2 + screenRect.origin.y
      let windowFrame = NSRect(x: x, y: y, width: fixedWidth, height: fixedHeight)
      self.setFrame(windowFrame, display: true)
    } else {
      // Fallback if screen is not available
      let windowFrame = NSRect(x: 0, y: 0, width: fixedWidth, height: fixedHeight)
      self.setFrame(windowFrame, display: true)
    }
    
    // Set fixed size (non-resizable)
    self.minSize = NSSize(width: fixedWidth, height: fixedHeight)
    self.maxSize = NSSize(width: fixedWidth, height: fixedHeight)
    
    // Remove resizable mask - set styleMask without .resizable
    var styleMask = self.styleMask
    styleMask.remove(.resizable)
    self.styleMask = styleMask
    
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
