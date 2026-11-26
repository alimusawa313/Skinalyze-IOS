// Folds or opens the iPhone Duo simulator by pressing Device Hub's own buttons (there is no command for it).
// From the Sandboxy project (Tools/duo-pose.swift); the inspector offset is new here.
// usage: duo-pose closed|half|open|turn (turn: a quarter turn)     (build: swiftc -O Tools/duo-pose.swift -o <somewhere>/duo-pose)
// It brings Device Hub to the front, clicks once, and puts the pointer back. Needs the Accessibility permission.
import AppKit
import ApplicationServices
import CoreGraphics

let offsets: [String: CGFloat] = ["turn": 5, "closed": 42.5, "half": 75.5, "open": 110]
guard CommandLine.arguments.count > 1, let dx = offsets[CommandLine.arguments[1]] else { print("usage: duo-pose closed|half|open|turn"); exit(2) }
guard AXIsProcessTrusted() else { print("no Accessibility permission: cannot press Device Hub's buttons"); exit(3) }
// (the script brings Device Hub forward first: a command-line tool may not do that itself)
func hubWindow() -> [String: Any]? {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.first { ($0[kCGWindowOwnerName as String] as? String) == "Device Hub" && ($0[kCGWindowLayer as String] as? Int) == 0
        && (($0[kCGWindowBounds as String] as? [String: CGFloat])?["Height"] ?? 0) > 200 }
}
var found: [String: Any]?
for _ in 0..<20 where found == nil { usleep(250_000); found = hubWindow() }
guard let window = found,
      let b = window[kCGWindowBounds as String] as? [String: CGFloat], let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"] else {
    print("Device Hub has no window on screen"); exit(5)
}
// The pose buttons sit in the bar under the device, centred in the part of the window between the device list and,
// when it's open, the inspector on the right (DUO_INSPECTOR=<points>, about 280; 0 when the inspector is closed).
let sidebar: CGFloat = 240
let inspector = CGFloat(Double(ProcessInfo.processInfo.environment["DUO_INSPECTOR"] ?? "0") ?? 0)
let point = CGPoint(x: (x + sidebar + x + w - inspector) / 2 + dx, y: y + h - 26.5)
// Never click into someone else's window: the frontmost normal window under the point must be Device Hub's.
let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let topmost = onScreen.first { info in
    guard (info[kCGWindowLayer as String] as? Int) == 0, let r = info[kCGWindowBounds as String] as? [String: CGFloat],
          let rx = r["X"], let ry = r["Y"], let rw = r["Width"], let rh = r["Height"] else { return false }
    return CGRect(x: rx, y: ry, width: rw, height: rh).contains(point)
}
guard (topmost?[kCGWindowOwnerName as String] as? String) == "Device Hub" else {
    print("not clicking: \(topmost?[kCGWindowOwnerName as String] as? String ?? "nothing") is on top of Device Hub's buttons")
    exit(6)
}
let before = CGEvent(source: nil)?.location ?? .zero
for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(120_000)
}
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: before, mouseButton: .left)?.post(tap: .cghidEventTap)
print("pressed \(CommandLine.arguments[1]) at \(Int(point.x)),\(Int(point.y)) window \(window[kCGWindowNumber as String] ?? 0)")
