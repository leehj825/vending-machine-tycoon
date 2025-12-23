import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    super.awakeFromNib()
    
    let flutterViewController = FlutterViewController()
    
    // Set initial window size: 540x1170
    let initialWidth: CGFloat = 540
    let initialHeight: CGFloat = 1170
    
    // Set minimum size (allow resizing)
    self.minSize = NSSize(width: 400, height: 600)
    
    // Calculate window frame centered on screen
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let x = (screenRect.width - initialWidth) / 2 + screenRect.origin.x
      let y = (screenRect.height - initialHeight) / 2 + screenRect.origin.y
      let windowFrame = NSRect(x: x, y: y, width: initialWidth, height: initialHeight)
      self.setFrame(windowFrame, display: true)
    } else {
      // Fallback if screen is not available
      let windowFrame = NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight)
      self.setFrame(windowFrame, display: true)
    }
    
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)
  }
}
