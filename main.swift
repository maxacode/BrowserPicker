import AppKit
import SwiftUI
import ApplicationServices

// MARK: - Models

struct BrowserItem: Equatable {
    let name: String
    let bundleId: String
    let icon: NSImage
    let profileArg: String?

    var id: String {
        return bundleId + (profileArg ?? "")
    }
}

struct URLRule: Codable, Identifiable, Equatable {
    let id: UUID
    var domainPattern: String
    var browserId: String

    init(domainPattern: String, browserId: String) {
        self.id = UUID()
        self.domainPattern = domainPattern
        self.browserId = browserId
    }
}

struct AppRule: Codable, Identifiable, Equatable {
    let id: UUID
    var appBundleId: String
    var appName: String
    var browserId: String

    init(appBundleId: String, appName: String, browserId: String) {
        self.id = UUID()
        self.appBundleId = appBundleId
        self.appName = appName
        self.browserId = browserId
    }
}

struct RunningAppInfo: Identifiable, Equatable {
    var id: String { bundleId }
    let name: String
    let bundleId: String
}


enum AppearanceMode: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

enum AccentColor: String, CaseIterable, Codable {
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green"
    case orange = "Orange"
    case red = "Red"
    case pink = "Pink"

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        }
    }
}

// MARK: - Chromium Profile Detection

func getChromiumProfiles(bundleId: String) -> [(name: String, arg: String)] {
    let localStatePaths: [String: String] = [
        "com.brave.Browser": "~/Library/Application Support/BraveSoftware/Brave-Browser/Local State",
        "com.google.Chrome": "~/Library/Application Support/Google/Chrome/Local State",
        "com.microsoft.edgemac": "~/Library/Application Support/Microsoft Edge/Local State",
        "com.vivaldi.Vivaldi": "~/Library/Application Support/Vivaldi/Local State"
    ]

    guard let pathTemplate = localStatePaths[bundleId] else { return [] }
    let path = NSString(string: pathTemplate).expandingTildeInPath

    var profiles: [(name: String, arg: String)] = []

    guard FileManager.default.fileExists(atPath: path) else { return [] }

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
        print("Error parsing Chromium profiles for \(bundleId): \(error)")
    }

    profiles.sort { $0.name < $1.name }
    return profiles
}

// MARK: - Browser Detection

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

    let chromiumBundleIds: Set<String> = [
        "com.brave.Browser",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi"
    ]

    var installed: [BrowserItem] = []

    for (name, bundleId) in commonBrowsers {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            if chromiumBundleIds.contains(bundleId) {
                let profiles = getChromiumProfiles(bundleId: bundleId)
                if profiles.count > 0 {
                    for profile in profiles {
                        installed.append(BrowserItem(name: "\(name) (\(profile.name))", bundleId: bundleId, icon: icon, profileArg: profile.arg))
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

// MARK: - Settings

class BrowserSettings: ObservableObject {
    @Published var hiddenBrowsers: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenBrowsers), forKey: "hiddenBrowsers") }
    }

    @Published var browserOrder: [String] {
        didSet { UserDefaults.standard.set(browserOrder, forKey: "browserOrder") }
    }

    @Published var urlRules: [URLRule] {
        didSet { saveRules() }
    }

    @Published var appRules: [AppRule] {
        didSet { saveAppRules() }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }

    @Published var accentColor: AccentColor {
        didSet { UserDefaults.standard.set(accentColor.rawValue, forKey: "accentColor") }
    }

    @Published var allBrowsers: [BrowserItem] = []
    @Published var isDefaultBrowser: Bool = false
    @Published var showingSettings: Bool = false
    @Published var settingsTab: SettingsTab = .browsers

    enum SettingsTab: String, CaseIterable {
        case browsers = "Browsers"
        case rules = "Rules"
        case appearance = "Appearance"
    }

    init() {
        if let savedHidden = UserDefaults.standard.array(forKey: "hiddenBrowsers") as? [String] {
            self.hiddenBrowsers = Set(savedHidden)
        } else {
            self.hiddenBrowsers = []
        }

        if let savedOrder = UserDefaults.standard.array(forKey: "browserOrder") as? [String] {
            self.browserOrder = savedOrder
        } else {
            self.browserOrder = []
        }

        if let rulesData = UserDefaults.standard.data(forKey: "urlRules"),
           let decoded = try? JSONDecoder().decode([URLRule].self, from: rulesData) {
            self.urlRules = decoded
        } else {
            self.urlRules = []
        }

        if let appRulesData = UserDefaults.standard.data(forKey: "appRules"),
           let decoded = try? JSONDecoder().decode([AppRule].self, from: appRulesData) {
            self.appRules = decoded
        } else {
            self.appRules = []
        }

        if let modeStr = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: modeStr) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }

        if let colorStr = UserDefaults.standard.string(forKey: "accentColor"),
           let color = AccentColor(rawValue: colorStr) {
            self.accentColor = color
        } else {
            self.accentColor = .blue
        }

        self.refresh()
        self.checkDefaultBrowserStatus()
        self.applyAppearance()
    }

    func saveRules() {
        if let data = try? JSONEncoder().encode(urlRules) {
            UserDefaults.standard.set(data, forKey: "urlRules")
        }
    }

    func saveAppRules() {
        if let data = try? JSONEncoder().encode(appRules) {
            UserDefaults.standard.set(data, forKey: "appRules")
        }
    }

    func matchingRule(for url: URL) -> URLRule? {
        guard let host = url.host?.lowercased() else { return nil }
        return urlRules.first { rule in
            let pattern = rule.domainPattern.lowercased()
            return host == pattern || host.hasSuffix("." + pattern)
        }
    }

    func matchingAppRule(for bundleId: String) -> AppRule? {
        let lowercasedId = bundleId.lowercased()
        return appRules.first { $0.appBundleId.lowercased() == lowercasedId }
    }

    func rememberChoice(url: URL, browserId: String) {
        guard let host = url.host?.lowercased() else { return }
        urlRules.removeAll { $0.domainPattern.lowercased() == host }
        urlRules.append(URLRule(domainPattern: host, browserId: browserId))
    }

    func applyAppearance() {
        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func refresh() {
        let detected = getInstalledBrowsers()
        var ordered: [BrowserItem] = []

        for id in browserOrder {
            if let match = detected.first(where: { $0.id == id }) {
                ordered.append(match)
            }
        }

        for browser in detected {
            if !browserOrder.contains(browser.id) {
                ordered.append(browser)
            }
        }

        self.allBrowsers = ordered
        self.syncOrder()
    }

    func syncOrder() {
        self.browserOrder = allBrowsers.map { $0.id }
    }

    func moveBrowser(from source: IndexSet, to destination: Int) {
        allBrowsers.move(fromOffsets: source, toOffset: destination)
        syncOrder()
    }

    func checkDefaultBrowserStatus() {
        let bundleId = (Bundle.main.bundleIdentifier ?? "com.user.BrowserPicker").lowercased()
        let testURL = URL(string: "https://example.com")!
        if let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: testURL) {
            let defaultBundleId = Bundle(url: defaultAppURL)?.bundleIdentifier?.lowercased()
                ?? defaultAppURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
                    .replacingOccurrences(of: ".app", with: "").lowercased()
            isDefaultBrowser = (defaultBundleId == bundleId || defaultAppURL.path.lowercased().contains("browserpicker"))
        } else {
            isDefaultBrowser = false
        }
    }

    func setAsDefaultBrowser() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.user.BrowserPicker"
        LSSetDefaultHandlerForURLScheme("http" as CFString, bundleId as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, bundleId as CFString)
        LSSetDefaultRoleHandlerForContentType("public.html" as CFString, .viewer, bundleId as CFString)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkDefaultBrowserStatus()
        }
    }

    var visibleBrowsers: [BrowserItem] {
        allBrowsers.filter { !hiddenBrowsers.contains($0.id) }
    }
}

// MARK: - Views

struct ContentView: View {
    let url: URL?
    @ObservedObject var settings: BrowserSettings

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let url = url, !settings.showingSettings {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.absoluteString)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let senderName = AppDelegate.shared.senderAppName {
                            Text("From \(senderName)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(settings.accentColor.color)
                        }
                    }
                } else {
                    Text(settings.showingSettings ? "Settings" : "Select a Browser")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    withAnimation { settings.showingSettings.toggle() }
                }) {
                    Image(systemName: settings.showingSettings ? "xmark.circle.fill" : "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()

            Divider()

            if settings.showingSettings {
                SettingsView(settings: settings)
            } else {
                BrowserListView(browsers: settings.visibleBrowsers, url: url, settings: settings)
            }
        }
        .frame(width: settings.showingSettings ? 500 : 340, height: settings.showingSettings ? 500 : nil, alignment: .top)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }
}

struct SettingsView: View {
    @ObservedObject var settings: BrowserSettings

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $settings.settingsTab) {
                ForEach(BrowserSettings.SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 8)

            switch settings.settingsTab {
            case .browsers:
                BrowserSettingsView(settings: settings)
            case .rules:
                RulesSettingsView(settings: settings)
            case .appearance:
                AppearanceSettingsView(settings: settings)
            }
        }
    }
}

struct BrowserSettingsView: View {
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
                .foregroundColor(settings.accentColor.color)
            }

            List {
                ForEach(settings.allBrowsers, id: \.id) { browser in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))

                        Image(nsImage: browser.icon)
                            .resizable()
                            .frame(width: 20, height: 20)

                        Text(browser.name)
                            .font(.system(size: 13))

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
                        .toggleStyle(SwitchToggleStyle(tint: settings.accentColor.color))
                        .scaleEffect(0.8)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: settings.moveBrowser)
            }
            .listStyle(PlainListStyle())
            .frame(maxHeight: 450)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Default Browser")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(settings.isDefaultBrowser ? "Currently set as default" : "Not set as default")
                        .font(.caption)
                        .foregroundColor(settings.isDefaultBrowser ? .green : .secondary)
                }

                Spacer()

                if !settings.isDefaultBrowser {
                    Button("Set as Default") {
                        settings.setAsDefaultBrowser()
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(settings.accentColor.color)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding(.top, 4)

            Text("Tip: Drag to reorder. Hold \u{21E7} Shift when picking a browser to remember choice for that domain.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
    }
}

struct RulesSettingsView: View {
    @ObservedObject var settings: BrowserSettings
    @State private var rulesTab: RulesTab = .domain
    
    enum RulesTab: String, CaseIterable {
        case domain = "Domains"
        case app = "Applications"
    }
    
    // For domain rules
    @State private var newDomain: String = ""
    @State private var newBrowserId: String = ""
    
    // For app rules
    @State private var selectedAppBundleId: String = ""
    @State private var selectedAppName: String = ""
    @State private var newAppBrowserId: String = ""
    @State private var runningApps: [RunningAppInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $rulesTab) {
                ForEach(RulesTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 4)
            
            if rulesTab == .domain {
                domainRulesView
            } else {
                appRulesView
            }
        }
        .padding()
        .onAppear {
            refreshRunningApps()
        }
    }
    
    private var domainRulesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("URL Rules")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Links matching a domain open automatically in the assigned browser.")
                .font(.caption)
                .foregroundColor(.secondary)

            if settings.urlRules.isEmpty {
                Text("No rules yet. Add one below, or hold \u{21E7} Shift when picking a browser to remember your choice.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(settings.urlRules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.domainPattern)
                                    .font(.system(size: 13, weight: .medium))
                                if let browser = settings.allBrowsers.first(where: { $0.id == rule.browserId }) {
                                    HStack(spacing: 4) {
                                        Image(nsImage: browser.icon)
                                            .resizable()
                                            .frame(width: 14, height: 14)
                                        Text(browser.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Unknown browser")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            Spacer()

                            Button(action: {
                                settings.urlRules.removeAll { $0.id == rule.id }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 300)
            }

            Divider()

            Text("Add Domain Rule")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField("Domain (e.g. github.com)", text: $newDomain)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 12))

            HStack {
                Picker("Browser:", selection: $newBrowserId) {
                    Text("Select...").tag("")
                    ForEach(settings.visibleBrowsers, id: \.id) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                .font(.system(size: 12))

                Spacer()

                Button("Add") {
                    guard !newDomain.isEmpty, !newBrowserId.isEmpty else { return }
                    let domain = newDomain.lowercased()
                        .replacingOccurrences(of: "https://", with: "")
                        .replacingOccurrences(of: "http://", with: "")
                        .components(separatedBy: "/").first ?? newDomain
                    settings.urlRules.removeAll { $0.domainPattern.lowercased() == domain }
                    settings.urlRules.append(URLRule(domainPattern: domain, browserId: newBrowserId))
                    newDomain = ""
                    newBrowserId = ""
                }
                .disabled(newDomain.isEmpty || newBrowserId.isEmpty)
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(newDomain.isEmpty || newBrowserId.isEmpty ? Color.gray : settings.accentColor.color)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }

    private var appRulesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application Rules")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Links clicked from an application open automatically in the assigned browser.")
                .font(.caption)
                .foregroundColor(.secondary)

            if settings.appRules.isEmpty {
                Text("No application rules yet. Add one below.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(settings.appRules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(nsImage: getAppIcon(for: rule.appBundleId))
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                    Text(rule.appName)
                                        .font(.system(size: 13, weight: .medium))
                                }
                                if let browser = settings.allBrowsers.first(where: { $0.id == rule.browserId }) {
                                    HStack(spacing: 4) {
                                        Image(nsImage: browser.icon)
                                            .resizable()
                                            .frame(width: 14, height: 14)
                                        Text(browser.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Unknown browser")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }

                            Spacer()

                            Button(action: {
                                settings.appRules.removeAll { $0.id == rule.id }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 300)
            }

            Divider()

            Text("Add Application Rule")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                Text("App:")
                    .font(.system(size: 12))
                
                Menu {
                    Button("Select App from Disk...") {
                        chooseAppFromDisk()
                    }
                    if !runningApps.isEmpty {
                        Divider()
                        ForEach(runningApps) { app in
                            Button(app.name) {
                                self.selectedAppBundleId = app.bundleId
                                self.selectedAppName = app.name
                            }
                        }
                    }
                } label: {
                    HStack {
                        if !selectedAppBundleId.isEmpty {
                            Image(nsImage: getAppIcon(for: selectedAppBundleId))
                                .resizable()
                                .frame(width: 14, height: 14)
                            Text(selectedAppName)
                                .font(.system(size: 12))
                        } else {
                            Text("Select application...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(maxWidth: .infinity)
            }

            HStack {
                Picker("Browser:", selection: $newAppBrowserId) {
                    Text("Select...").tag("")
                    ForEach(settings.visibleBrowsers, id: \.id) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                .font(.system(size: 12))

                Spacer()

                Button("Add") {
                    guard !selectedAppBundleId.isEmpty, !newAppBrowserId.isEmpty else { return }
                    settings.appRules.removeAll { $0.appBundleId.lowercased() == selectedAppBundleId.lowercased() }
                    settings.appRules.append(AppRule(appBundleId: selectedAppBundleId, appName: selectedAppName, browserId: newAppBrowserId))
                    selectedAppBundleId = ""
                    selectedAppName = ""
                    newAppBrowserId = ""
                }
                .disabled(selectedAppBundleId.isEmpty || newAppBrowserId.isEmpty)
                .buttonStyle(BorderlessButtonStyle())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selectedAppBundleId.isEmpty || newAppBrowserId.isEmpty ? Color.gray : settings.accentColor.color)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }

    func getAppIcon(for bundleId: String) -> NSImage {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appUrl.path)
        }
        return NSWorkspace.shared.icon(forFileType: "app")
    }

    func chooseAppFromDisk() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["app"]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                let appName = url.deletingPathExtension().lastPathComponent
                if let bundle = Bundle(url: url), let bid = bundle.bundleIdentifier {
                    self.selectedAppBundleId = bid
                    self.selectedAppName = appName
                } else {
                    let infoPlistPath = url.appendingPathComponent("Contents/Info.plist")
                    if let dict = NSDictionary(contentsOf: infoPlistPath),
                       let bid = dict["CFBundleIdentifier"] as? String {
                        self.selectedAppBundleId = bid
                        self.selectedAppName = dict["CFBundleName"] as? String ?? appName
                    }
                }
            }
        }
    }

    func refreshRunningApps() {
        let ownBundleId = Bundle.main.bundleIdentifier ?? "com.user.BrowserPicker"
        self.runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != ownBundleId }
            .compactMap { app in
                guard let name = app.localizedName, let bid = app.bundleIdentifier else { return nil }
                return RunningAppInfo(name: name, bundleId: bid)
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

struct AppearanceSettingsView: View {
    @ObservedObject var settings: BrowserSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Picker("", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent Color")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    ForEach(AccentColor.allCases, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: settings.accentColor == color ? 2.5 : 0)
                            )
                            .scaleEffect(settings.accentColor == color ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: settings.accentColor)
                            .onTapGesture {
                                settings.accentColor = color
                            }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Window Position")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Button("Save Current Position") {
                        if let frame = AppDelegate.shared.window?.frame {
                            UserDefaults.standard.set(NSStringFromRect(frame), forKey: "windowFrame")
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(settings.accentColor.color)
                    .foregroundColor(.white)
                    .cornerRadius(6)

                    Button("Reset") {
                        UserDefaults.standard.removeObject(forKey: "windowFrame")
                        AppDelegate.shared.window?.center()
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                }

                Text("Save to remember where the picker appears.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

struct BrowserListView: View {
    let browsers: [BrowserItem]
    let url: URL?
    @ObservedObject var settings: BrowserSettings

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
                            .background(settings.accentColor.color)
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
                    .background(Color(NSColor.unemphasizedSelectedContentBackgroundColor).opacity(0.3))
                    .cornerRadius(8)
                    .onTapGesture {
                        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                        if shiftHeld, let url = url {
                            settings.rememberChoice(url: url, browserId: browser.id)
                        }
                        AppDelegate.shared.openURL(in: browser)
                    }
                }
            }
        }
        .padding()
    }
}

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

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    var window: NSWindow!
    var openedURL: URL?
    var senderBundleId: String?
    var senderAppName: String?
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
        if let url = openedURL, let rule = settingsStore.matchingRule(for: url) {
            if let browser = settingsStore.allBrowsers.first(where: { $0.id == rule.browserId }) {
                openURL(in: browser)
                return
            }
        }

        if let senderId = senderBundleId, let rule = settingsStore.matchingAppRule(for: senderId) {
            if let browser = settingsStore.allBrowsers.first(where: { $0.id == rule.browserId }) {
                openURL(in: browser)
                return
            }
        }

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

        if let frameStr = UserDefaults.standard.string(forKey: "windowFrame") {
            let frame = NSRectFromString(frameStr)
            if frame.width > 0 && frame.height > 0 {
                window.setFrameOrigin(frame.origin)
            } else {
                window.center()
            }
        } else {
            window.center()
        }

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            if event.keyCode == 53 {
                NSApplication.shared.terminate(nil)
                return nil
            }

            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "," {
                withAnimation { self.settingsStore.showingSettings = true }
                return nil
            }

            if let chars = event.charactersIgnoringModifiers, let num = Int(chars) {
                let visible = self.settingsStore.visibleBrowsers
                if num > 0 && num <= visible.count {
                    let browser = visible[num - 1]
                    if event.modifierFlags.contains(.shift), let url = self.openedURL {
                        self.settingsStore.rememberChoice(url: url, browserId: browser.id)
                    }
                    self.openURL(in: browser)
                    return nil
                }
            }
            return event
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        settingsStore.checkDefaultBrowserStatus()
    }

    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
           let url = URL(string: urlString) {
            self.openedURL = url
            
            // Extract sender process ID (PID)
            if let pidDescriptor = event.attributeDescriptor(forKeyword: AEKeyword(0x73706964)) {
                let pid = pid_t(pidDescriptor.int32Value)
                if let app = NSRunningApplication(processIdentifier: pid) {
                    self.senderBundleId = app.bundleIdentifier
                    self.senderAppName = app.localizedName
                }
            }
        }
    }

    func openURL(in browser: BrowserItem) {
        guard let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.bundleId) else {
            NSApplication.shared.terminate(nil)
            return
        }

        if let arg = browser.profileArg {
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
