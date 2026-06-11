import AppKit
import CoreGraphics
import ServiceManagement
import UserNotifications

enum ReminderStyle: String, CaseIterable {
    case fullScreen
    case popup
    case notification

    var title: String {
        switch self {
        case .fullScreen: "Full-screen overlay"
        case .popup: "Small center popup"
        case .notification: "macOS notification"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var controller = ReminderController(appDelegate: self)
    private var userRequestedQuit = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSLog("BlinkBar will finish launching")
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("BlinkBar did finish launching")
        controller.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if userRequestedQuit {
            return .terminateNow
        }

        NSLog("BlinkBar blocked unexpected terminate request")
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("BlinkBar will terminate")
    }

    func quitFromMenu() {
        userRequestedQuit = true
        NSApp.terminate(nil)
    }
}

@main
struct BlinkBarApp {
    @MainActor
    private static let delegate = AppDelegate()

    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.disableRelaunchOnLogin()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class ReminderController: NSObject {
    private let appDelegate: AppDelegate

    private let intervalKey = "blinkReminder.intervalSeconds"
    private let enabledKey = "blinkReminder.enabled"
    private let styleKey = "blinkReminder.style"
    private let launchAtLoginKey = "blinkReminder.launchAtLogin"
    private let notificationIdentifier = "blinkBar.notification"
    private let notificationSettingsPath = "System Settings > Notifications > BlinkBar > Allow Notifications"

    private let callAppBundleIDs: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "com.cisco.webexmeetingsapp",
        "com.google.Chrome",
        "com.apple.Safari",
        "company.thebrowser.Browser"
    ]

    private var statusItem: NSStatusItem?
    private var reminderTimer: Timer?
    private var autoDismissTimer: Timer?
    private var notificationCleanupTimer: Timer?
    private let notificationDelegate = BlinkBarNotificationDelegate()
    private var reminderWindows: [NSWindow] = []
    private var fullScreenWindows: [NSWindow] = []
    private var popupWindow: NSWindow?
    private var notificationStatusText = "Notification status: Checking..."
    private var notificationHelpShownThisSession = false

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
    }

    private var intervalSeconds: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: intervalKey)
            return stored > 0 ? stored : 20 * 60
        }
        set {
            UserDefaults.standard.set(newValue, forKey: intervalKey)
        }
    }

    private var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    private var reminderStyle: ReminderStyle {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: styleKey),
                let style = ReminderStyle(rawValue: rawValue)
            else {
                return .fullScreen
            }
            return style
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: styleKey)
        }
    }

    private var launchAtLoginEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: launchAtLoginKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: launchAtLoginKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: launchAtLoginKey)
        }
    }

    func start() {
        installStatusItem()
        configureNotifications()
        scheduleReminderTimer()
    }

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "BlinkBar")
        image?.isTemplate = true
        statusItem.button?.title = ""
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "BlinkBar"
        statusItem.menu = makeMenu()
        self.statusItem = statusItem
    }

    private func configureNotifications() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        refreshNotificationStatus()
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized:
                text = "Notification status: Allowed"
            case .denied:
                text = "Notification status: Denied"
            case .notDetermined:
                text = "Notification status: Not Asked"
            case .provisional:
                text = "Notification status: Provisional"
            case .ephemeral:
                text = "Notification status: Temporary"
            @unknown default:
                text = "Notification status: Unknown"
            }

            Task { @MainActor in
                self?.notificationStatusText = text
                self?.refreshMenu()
            }
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(
            title: isEnabled ? "Reminder: On" : "Reminder: Off",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        status.target = self
        menu.addItem(status)

        let interval = NSMenuItem(title: "Every \(formatInterval(intervalSeconds))", action: nil, keyEquivalent: "")
        interval.isEnabled = false
        menu.addItem(interval)

        menu.addItem(NSMenuItem.separator())
        addIntervalItem(minutes: 5, to: menu)
        addIntervalItem(minutes: 10, to: menu)
        addIntervalItem(minutes: 20, to: menu)
        addIntervalItem(minutes: 30, to: menu)
        addIntervalItem(minutes: 60, to: menu)

        let custom = NSMenuItem(title: "Custom interval...", action: #selector(promptForCustomInterval), keyEquivalent: "")
        custom.target = self
        menu.addItem(custom)

        menu.addItem(NSMenuItem.separator())
        for style in ReminderStyle.allCases {
            let item = NSMenuItem(title: style.title, action: #selector(selectStyle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = style.rawValue
            item.state = reminderStyle == style ? .on : .off
            menu.addItem(item)
        }

        let notificationStatus = NSMenuItem(title: notificationStatusText, action: #selector(refreshNotificationStatusFromMenu), keyEquivalent: "")
        notificationStatus.target = self
        menu.addItem(notificationStatus)

        let notificationSettings = NSMenuItem(
            title: "Open Notification Settings...",
            action: #selector(openNotificationSettingsFromMenu),
            keyEquivalent: ""
        )
        notificationSettings.target = self
        menu.addItem(notificationSettings)

        menu.addItem(NSMenuItem.separator())
        let launchAtLogin = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLogin.target = self
        launchAtLogin.state = launchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLogin)

        menu.addItem(NSMenuItem.separator())
        let test = NSMenuItem(title: "Show reminder now", action: #selector(showReminderNow), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Quit BlinkBar", action: #selector(quitFromMenu), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func addIntervalItem(minutes: Int, to menu: NSMenu) {
        let item = NSMenuItem(title: "Every \(minutes) minutes", action: #selector(selectInterval(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = minutes
        item.state = Int(intervalSeconds / 60) == minutes ? .on : .off
        menu.addItem(item)
    }

    private func refreshMenu() {
        statusItem?.menu = makeMenu()
    }

    private func scheduleReminderTimer() {
        reminderTimer?.invalidate()

        guard isEnabled else {
            refreshMenu()
            return
        }

        reminderTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.showReminderIfAppropriate()
            }
        }
        refreshMenu()
    }

    private func showReminderIfAppropriate() {
        guard isEnabled else { return }

        if shouldPauseForCurrentContext() {
            scheduleShortRetry()
            return
        }

        showReminder()
    }

    private func scheduleShortRetry() {
        reminderTimer?.invalidate()
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleReminderTimer()
                self?.showReminderIfAppropriate()
            }
        }
    }

    private func shouldPauseForCurrentContext() -> Bool {
        isFrontmostCallAppActive() || isFrontmostWindowFullScreen()
    }

    private func isFrontmostCallAppActive() -> Bool {
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return callAppBundleIDs.contains(bundleIdentifier)
    }

    private func isFrontmostWindowFullScreen() -> Bool {
        guard
            let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else {
            return false
        }

        for window in windows {
            guard
                let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID == frontmostPID,
                let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                let x = numberValue(boundsDict["X"]),
                let y = numberValue(boundsDict["Y"]),
                let width = numberValue(boundsDict["Width"]),
                let height = numberValue(boundsDict["Height"])
            else {
                continue
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)
            if NSScreen.screens.contains(where: { screen in
                abs(screen.frame.minX - bounds.minX) < 2 &&
                abs(screen.frame.minY - bounds.minY) < 2 &&
                abs(screen.frame.width - bounds.width) < 2 &&
                abs(screen.frame.height - bounds.height) < 2
            }) {
                return true
            }
        }

        return false
    }

    private func numberValue(_ value: Any?) -> CGFloat? {
        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }
        if let double = value as? Double {
            return CGFloat(double)
        }
        if let cgFloat = value as? CGFloat {
            return cgFloat
        }
        return nil
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        scheduleReminderTimer()
    }

    @objc private func selectInterval(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        intervalSeconds = TimeInterval(minutes * 60)
        isEnabled = true
        scheduleReminderTimer()
    }

    @objc private func selectStyle(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let style = ReminderStyle(rawValue: rawValue)
        else {
            return
        }

        if style == .notification {
            enableNotificationStyle()
        } else {
            reminderStyle = style
            refreshMenu()
        }
    }

    private func enableNotificationStyle() {
        reminderStyle = .notification
        refreshMenu()

        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Task { @MainActor in
                    self?.refreshNotificationStatus()
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
                    if let error {
                        NSLog("BlinkBar notification authorization failed: \(error.localizedDescription)")
                    }
                    Task { @MainActor in
                        self?.refreshNotificationStatus()
                        if !granted {
                            self?.showNotificationSettingsHelp()
                        }
                    }
                }
            case .denied:
                Task { @MainActor in
                    self?.notificationStatusText = "Notification status: Denied"
                    self?.refreshMenu()
                    self?.showNotificationSettingsHelp()
                }
            @unknown default:
                Task { @MainActor in
                    self?.notificationStatusText = "Notification status: Unknown"
                    self?.refreshMenu()
                    self?.showNotificationSettingsHelp()
                }
            }
        }
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginEnabled.toggle()
        applyLaunchAtLoginPreference()
        refreshMenu()
    }

    private func applyLaunchAtLoginPreference() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("BlinkBar login item update failed: \(error.localizedDescription)")
        }
    }

    @objc private func promptForCustomInterval() {
        let alert = NSAlert()
        alert.messageText = "Set blink reminder interval"
        alert.informativeText = "Enter the number of minutes between reminders."
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.placeholderString = "Minutes"
        input.stringValue = String(Int(intervalSeconds / 60))
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let minutes = Double(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard minutes > 0 else {
            NSSound.beep()
            return
        }

        intervalSeconds = minutes * 60
        isEnabled = true
        scheduleReminderTimer()
    }

    @objc private func showReminderNow() {
        showReminder()
    }

    @objc private func refreshNotificationStatusFromMenu() {
        refreshNotificationStatus()
    }

    @objc private func openNotificationSettingsFromMenu() {
        openNotificationSettings()
    }

    @objc private func quitFromMenu() {
        appDelegate.quitFromMenu()
    }

    private func showReminder() {
        dismissCurrentReminder()

        switch reminderStyle {
        case .fullScreen:
            showFullScreenOverlay()
        case .popup:
            showPopup()
        case .notification:
            showNotification()
        }
    }

    private func showFullScreenOverlay() {
        reminderWindows = NSScreen.screens.enumerated().map { index, screen in
            let window: NSWindow
            if index < fullScreenWindows.count {
                window = fullScreenWindows[index]
                window.setFrame(screen.frame, display: true)
            } else {
                window = makeReminderWindow(frame: screen.frame, screen: screen)
                fullScreenWindows.append(window)
            }

            window.contentView = ReminderView(style: .fullScreen, onDone: { [weak self] in
                self?.dismissCurrentReminder()
            })
            window.makeKeyAndOrderFront(nil)
            return window
        }
        scheduleAutoDismiss()
    }

    private func showPopup() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = NSSize(width: 420, height: 260)
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        let window: NSWindow
        if let existingWindow = popupWindow {
            window = existingWindow
            window.setFrame(frame, display: true)
        } else {
            window = makeReminderWindow(frame: frame, screen: screen)
            popupWindow = window
        }

        window.contentView = ReminderView(style: .popup, onDone: { [weak self] in
            self?.dismissCurrentReminder()
        })
        window.makeKeyAndOrderFront(nil)
        reminderWindows = [window]
        scheduleAutoDismiss()
    }

    private func makeReminderWindow(frame: NSRect, screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.alphaValue = 1
        return window
    }

    private func scheduleAutoDismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissCurrentReminder()
            }
        }
    }

    private func dismissCurrentReminder() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil

        let windows = reminderWindows
        reminderWindows.removeAll()

        guard !windows.isEmpty else { return }
        windows.forEach { $0.orderOut(nil) }
    }

    private func showNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let canNotify: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                canNotify = true
            case .notDetermined, .denied:
                canNotify = false
            @unknown default:
                canNotify = false
            }

            guard canNotify else {
                let statusText = settings.authorizationStatus == .denied
                    ? "Notification status: Denied"
                    : "Notification status: Not Asked"
                NSLog("BlinkBar notification unavailable; falling back to popup")
                Task { @MainActor in
                    self?.notificationStatusText = statusText
                    self?.refreshMenu()
                    self?.showNotificationSettingsHelp()
                    self?.showPopup()
                }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "BlinkBar"
            content.body = "Look away and blink a few times."

            let identifier = self?.notificationIdentifier ?? "blinkBar.notification"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    NSLog("BlinkBar notification failed: \(error.localizedDescription)")
                    Task { @MainActor in
                        self?.showPopup()
                    }
                }
            }

            Task { @MainActor in
                self?.notificationCleanupTimer?.invalidate()
                self?.notificationCleanupTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { _ in
                    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
                }
            }
        }
    }

    private func formatInterval(_ seconds: TimeInterval) -> String {
        let minutes = seconds / 60
        if minutes.rounded() == minutes {
            return "\(Int(minutes)) minutes"
        }
        return String(format: "%.1f minutes", minutes)
    }

    private func showNotificationSettingsHelp() {
        guard !notificationHelpShownThisSession else { return }
        notificationHelpShownThisSession = true

        let alert = NSAlert()
        alert.messageText = "Enable BlinkBar notifications"
        alert.informativeText = "To use macOS notification reminders, enable:\n\n\(notificationSettingsPath)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openNotificationSettings()
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

final class BlinkBarNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        center.removeDeliveredNotifications(withIdentifiers: ["blinkBar.notification"])
        completionHandler()
    }
}

final class ReminderView: NSView {
    private let style: ReminderStyle
    private let onDone: () -> Void

    init(style: ReminderStyle, onDone: @escaping () -> Void) {
        self.style = style
        self.onDone = onDone
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.style = .fullScreen
        self.onDone = {}
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = backgroundColor.cgColor
        if style == .popup {
            layer?.cornerRadius = 18
            layer?.shadowColor = NSColor.black.cgColor
            layer?.shadowOpacity = 0.25
            layer?.shadowRadius = 24
            layer?.shadowOffset = NSSize(width: 0, height: -8)
        }

        let icon = NSImageView(image: NSImage(systemSymbolName: "eye", accessibilityDescription: "Eye icon") ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: style == .fullScreen ? 68 : 44, weight: .regular)
        icon.contentTintColor = .white

        let title = NSTextField(labelWithString: "Blink")
        title.font = .systemFont(ofSize: style == .fullScreen ? 46 : 34, weight: .bold)
        title.textColor = .white
        title.alignment = .center

        let subtitle = NSTextField(labelWithString: "Look away and blink a few times")
        subtitle.font = .systemFont(ofSize: style == .fullScreen ? 20 : 16, weight: .medium)
        subtitle.textColor = NSColor.white.withAlphaComponent(0.9)
        subtitle.alignment = .center

        let doneButton = NSButton(title: "Done", target: self, action: #selector(doneTapped))
        doneButton.bezelStyle = .rounded
        doneButton.controlSize = .large
        doneButton.keyEquivalent = "\r"

        let hint = NSTextField(labelWithString: "This reminder closes automatically in 20 seconds.")
        hint.font = .systemFont(ofSize: 12, weight: .regular)
        hint.textColor = NSColor.white.withAlphaComponent(0.7)
        hint.alignment = .center

        let stack = NSStackView(views: [icon, title, subtitle, doneButton, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = style == .fullScreen ? 13 : 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            subtitle.widthAnchor.constraint(lessThanOrEqualToConstant: style == .fullScreen ? 520 : 340),
            hint.widthAnchor.constraint(lessThanOrEqualToConstant: style == .fullScreen ? 520 : 340)
        ])
    }

    private var backgroundColor: NSColor {
        switch style {
        case .fullScreen:
            NSColor.black.withAlphaComponent(0.42)
        case .popup:
            NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.17, alpha: 0.95)
        case .notification:
            .clear
        }
    }

    @objc private func doneTapped() {
        onDone()
    }
}
