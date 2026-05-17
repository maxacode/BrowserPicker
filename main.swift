import AppKit
import SwiftUI
import ApplicationServices

// Define a struct to hold browser information
struct BrowserItem: Equatable {
    let name: String
    let bundleId: String
    let icon: NSImage
    let profileArg: String? // e.g. "--profile-directory=Profile 1"
    
    // Unique ID for SwiftUI
    var id: String {
        return bundleId + (profileArg ?? "")
    }
}

// Function to parse Brave profiles
func getBraveProfiles() -> [(name: String, arg: String)] {
    let path = NSString(string: "~/Library/Application Support/BraveSoftware/Brave-Browser/Local State").expandingTildeInPath
    
    var profiles: [(name: String, arg: String)] = []
    
    if FileManager.default.fileExists(atPath: path) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let profileNode = json["profile"] as? [String: Any],
               let infoCache = profileNode["info_cache"] as? [String: [String: Any]] {
                
                for (dirName, cacheData) in infoCache {
                    if let name = cacheData["name"] as? String {
                        profiles.append((name: name, arg: "--profile-directory=\(dirName)"))
                    }
                }
            }
        } catch {
            print("Error parsing Brave profiles: \(error)")
        }
    }
    
    // Sort profiles alphabetically
    profiles.sort { $0.name < $1.name }
    return profiles
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
            
            // Special handling for Brave profiles
            if bundleId == "com.brave.Browser" {
                let profiles = getBraveProfiles()
                if profiles.count > 0 {
                    for profile in profiles {
                        installed.append(BrowserItem(name: "Brave (\(profile.name))", bundleId: bundleId, icon: icon, profileArg: profile.arg))
                    }
                } else {
                    installed.append(BrowserItem(name: name, bundleId: bundleId, icon: icon, profileArg: nil))
                }
            } else {
                installed.append(BrowserItem(name: name, bundleId: bundleId, icon: icon, profileArg: nil))
            }
        }
    }
    
    return installed
}

class BrowserSettings: ObservableObject {
    @Published var hiddenBrowsers: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenBrowsers), forKey: "hiddenBrowsers")
        }
    }
    
    @Published var allBrowsers: [BrowserItem] = []
    
    init() {
        if let saved = UserDefaults.standard.array(forKey: "hiddenBrowsers") as? [String] {
            self.hiddenBrowsers = Set(saved)
        } else {
            self.hiddenBrowsers = []
        }
        self.refresh()
    }
    
    func refresh() {
        self.allBrowsers = getInstalledBrowsers()
    }
    
    var visibleBrowsers: [BrowserItem] {
        allBrowsers.filter { !hiddenBrowsers.contains($0.id) }
    }
}

struct ContentView: View {
    let url: URL?
    @ObservedObject var settings = BrowserSettings()
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let url = url {
                    Text(url.absoluteString)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(showingSettings ? "Settings" : "Select a Browser")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingSettings.toggle()
                    }
                }) {
                    Image(systemName: showingSettings ? "xmark.circle.fill" : "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            
            Divider()
            
            if showingSettings {
                SettingsView(settings: settings)
            } else {
                BrowserListView(browsers: settings.visibleBrowsers, url: url)
            }
        }
        .frame(width: 340)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}

struct SettingsView: View {
    @ObservedObject var settings: BrowserSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Installed Browsers")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Refresh") {
                    settings.refresh()
                }
                .buttonStyle(BorderlessButtonStyle())
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(settings.allBrowsers, id: \.id) { browser in
                        HStack {
                            Image(nsImage: browser.icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(browser.name)
                                .font(.system(size: 14))
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { !settings.hiddenBrowsers.contains(browser.id) },
                                set: { show in
                                    if show {
                                        settings.hiddenBrowsers.remove(browser.id)
                                    } else {
                                        settings.hiddenBrowsers.insert(browser.id)
                                    }
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 250)
            
            Text("Tip: Hidden browsers will not appear in the picker.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
    }
}

struct BrowserListView: View {
    let browsers: [BrowserItem]
    let url: URL?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if browsers.isEmpty {
                Text("No visible browsers found.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
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
                    // Make clickable
                    .onTapGesture {
                        AppDelegate.shared.openURL(in: browser)
                    }
                }
            }
        }
        .padding()
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
    static let shared = AppDelegate()
    var window: NSWindow!
    var openedURL: URL?
    var eventMonitor: Any?
    let settingsStore = BrowserSettings()

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
        NSApp.activate(ignoringOtherApps: true)
        
        let contentView = ContentView(url: openedURL, settings: settingsStore)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 100),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        
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
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.keyCode == 53 { // Esc key
                NSApplication.shared.terminate(nil)
                return nil
            }
            
            // Only process number keys if we are NOT in the settings view.
            // But we don't strictly know state here easily. So we just map numbers to visible browsers.
            if let chars = event.charactersIgnoringModifiers, let num = Int(chars) {
                let visible = self.settingsStore.visibleBrowsers
                if num > 0 && num <= visible.count {
                    self.openURL(in: visible[num - 1])
                    return nil
                }
            }
            return event
        }
    }

    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
           let url = URL(string: urlString) {
            self.openedURL = url
        }
    }
    
    func openURL(in browser: BrowserItem) {
        guard let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleId) else {
            NSApplication.shared.terminate(nil)
            return
        }
        
        if let arg = browser.profileArg {
            // For Chromium profiles, we must force a new process instance so the argument is respected.
            // Chromium will intercept the launch, open the profile, and exit the duplicate process.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            var args = ["-n", "-a", appUrl.path, "--args", arg]
            if let urlToOpen = openedURL {
                args.append(urlToOpen.absoluteString)
            }
            process.arguments = args
            
            do {
                try process.run()
            } catch {
                print("Failed to run profile process: \(error)")
            }
            
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        } else {
            let config = NSWorkspace.OpenConfiguration()
            if let urlToOpen = openedURL {
                NSWorkspace.shared.open([urlToOpen], withApplicationAt: appUrl, configuration: config) { _, _ in
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                }
            } else {
                NSWorkspace.shared.openApplication(at: appUrl, configuration: config) { _, _ in
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
}

let app = NSApplication.shared
app.delegate = AppDelegate.shared
app.run()
