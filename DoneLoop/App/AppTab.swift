import SwiftUI

enum AppTab: Hashable {
    case capture
    case today
    case inbox
    case settings

    var title: String {
        switch self {
        case .capture: "Capture"
        case .today: "Today"
        case .inbox: "Inbox"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .capture: "mic.fill"
        case .today: "sun.max"
        case .inbox: "tray"
        case .settings: "gearshape"
        }
    }
}
