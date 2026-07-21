import Foundation
import ServiceManagement

enum LoginItemManager {
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Error? {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                return error
            }
        }
        return nil
    }
}
