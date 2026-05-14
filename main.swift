import AppKit
import SwiftUI
import ApplicationServices

// Define a struct to hold browser information
struct BrowserItem {
    let name: String
    let bundleId: String
    let icon: NSImage
}

// Function to find installed browsers
func getInstalledBrowsers() -> [BrowserItem] {
    let commonBrowsers = [
        ("Safari", "com.apple.Safari"),
        ("Chrome", "com.google.Chrome"),
        ("Firefox", "org.mozilla.firefox"),
        ("Brave", "com.brave.Browser"),
        ("Arc", "company.thebrowser.Browser"),
        ("Edge", "com.microsoft.edgemac"),
        ("Orion", "com.kagi.kagimacOS"),
        ("Opera", "com.operasoftware.Opera"),
        ("Vivaldi", "com.vivaldi.Vivaldi")
    ]
    
    var installed: [BrowserItem] = []
    
    for (name, bundleId) in commonBrowsers {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            installed.append(BrowserItem(name: name, bundleId: bundleId, icon: icon))
        }
    }
    
    return installed
}

struct ContentView: View {
    let url: URL?
    let browsers: [BrowserItem]
    
    var body: some View {
        VStack(spacing: 20) {
            if let url = url {
                Text(url.absoluteString)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.horizontal)
                    .padding(.top, 20)
            } else {
                Text("Select a Browser")
                    .font(.headline)
                    .padding(.top, 20)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(browsers.enumerated()), id: \.element.bundleId) { index, browser in
                    HStack(spacing: 16) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 1)
                        
                        Image(nsImage: browser.icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                        
                        Text(browser.name)
                            .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(width: 320)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

// SwiftUI wrapper for NSVisualEffectView
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var openedURL: URL?
    var browsers: [BrowserItem] = []
    var eventMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(event:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App behaves as an LSUIElement, so we must manually ensure it gets focus
        NSApp.activate(ignoringOtherApps: true)
        
        browsers = getInstalledBrowsers()
        
        // Setup the window
        let contentView = ContentView(url: openedURL, browsers: browsers)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        
        // Hide title bar
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        
        // Monitor keyboard events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.keyCode == 53 { // Esc key
                NSApplication.shared.terminate(nil)
                return nil
            }
            
            if let chars = event.charactersIgnoringModifiers, let num = Int(chars) {
                if num > 0 && num <= self.browsers.count {
                    self.openURL(in: self.browsers[num - 1].bundleId)
                    return nil
                }
            }
            return event
        }
        
        // If we didn't receive a URL on launch, we might just be testing the app
        if openedURL == nil {
            print("Launched without URL. Showing UI for testing.")
        }
    }

    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
           let url = URL(string: urlString) {
            self.openedURL = url
            
            // If the window is already up (e.g. app was somehow running), update it.
            // But usually this app will launch, get the URL, show window, open, and terminate.
        }
    }
    
    func openURL(in bundleId: String) {
        guard let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            NSApplication.shared.terminate(nil)
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        if let urlToOpen = openedURL {
            NSWorkspace.shared.open([urlToOpen], withApplicationAt: appUrl, configuration: config) { _, _ in
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        } else {
            // Just open the browser if no URL was provided
            NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { _, _ in
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

// Entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
