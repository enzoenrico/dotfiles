#!/usr/bin/env swift

import AppKit
import Foundation

func applyBorders() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-lc", "~/.config/borders/bordersrc"]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fputs("Failed to apply borders: \(error)\n", stderr)
    }
}

applyBorders()

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
