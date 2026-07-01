import AppKit
import Foundation

func applyBorders() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let bordersrc = "\(home)/.config/borders/bordersrc"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [bordersrc]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fputs("Failed to apply borders: \(error)\n", stderr)
    }
}

applyBorders()

// Retry after login while the window server and borders are coming up.
for delay in [3.0, 10.0] {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        applyBorders()
    }
}

let center = DistributedNotificationCenter.default()
let observer = center.addObserver(
    forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
    object: nil,
    queue: .main
) { _ in
    applyBorders()
}

RunLoop.main.run()

_ = observer
