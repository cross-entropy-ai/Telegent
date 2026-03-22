import Foundation
import TelegramCore
import SwiftSignalKit

public struct TelegentSettings: Codable, Equatable {
    public var showContactsTab: Bool
    public var showCallsTab: Bool

    public static var defaultSettings: TelegentSettings {
        return TelegentSettings(showContactsTab: true, showCallsTab: false)
    }

    public init(showContactsTab: Bool, showCallsTab: Bool) {
        self.showContactsTab = showContactsTab
        self.showCallsTab = showCallsTab
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.showContactsTab = (try container.decodeIfPresent(Int32.self, forKey: "showContactsTab") ?? 1) != 0
        self.showCallsTab = (try container.decodeIfPresent(Int32.self, forKey: "showCallsTab") ?? 0) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode((self.showContactsTab ? 1 : 0) as Int32, forKey: "showContactsTab")
        try container.encode((self.showCallsTab ? 1 : 0) as Int32, forKey: "showCallsTab")
    }
}

public func updateTelegentSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (TelegentSettings) -> TelegentSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.telegentSettings, { entry in
            let currentSettings: TelegentSettings
            if let entry = entry?.get(TelegentSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
