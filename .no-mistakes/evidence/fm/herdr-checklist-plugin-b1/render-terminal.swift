import AppKit
import WebKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
class Capture: NSObject, WKNavigationDelegate {
    let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 1760, height: 760))
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            webView.evaluateJavaScript("window.captureReady === true") { ready, error in
                guard error == nil, ready as? Bool == true else {
                    print("Terminal recording did not render:", String(describing: error)); exit(2)
                }
                let config = WKSnapshotConfiguration()
                config.rect = webView.bounds
                webView.takeSnapshot(with: config) { image, error in
                    guard let image = image, let tiff = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiff),
                          let png = bitmap.representation(using: .png, properties: [:]) else {
                        print("Snapshot failed:", String(describing: error)); exit(3)
                    }
                    do { try png.write(to: output); print("Captured actual Herdr terminal recording:", output.path); exit(0) }
                    catch { print(error); exit(4) }
                }
            }
        }
    }
}
let capture = Capture()
let window = NSWindow(contentRect: capture.view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
window.contentView = capture.view
capture.view.navigationDelegate = capture
capture.view.loadFileURL(input, allowingReadAccessTo: input.deletingLastPathComponent())
DispatchQueue.main.asyncAfter(deadline: .now() + 20) { print("WebKit snapshot timed out"); exit(5) }
app.run()
