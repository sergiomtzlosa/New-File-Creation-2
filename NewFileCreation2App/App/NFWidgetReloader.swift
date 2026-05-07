import Foundation
import WidgetKit

/// Small Objective-C bridge so the app can refresh WidgetKit timelines when
/// the shared configuration changes. The widget target is the only part of the
/// project that is otherwise written in Swift.
@objc(NFWidgetReloader)
final class NFWidgetReloader: NSObject {
    @objc static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
