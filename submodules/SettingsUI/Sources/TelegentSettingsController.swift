import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

private final class TelegentSettingsArguments {
    let context: AccountContext
    let updateEnableSystemContacts: (Bool) -> Void
    let updateShowContactsTab: (Bool) -> Void
    let updateShowCallsTab: (Bool) -> Void

    init(context: AccountContext, updateEnableSystemContacts: @escaping (Bool) -> Void, updateShowContactsTab: @escaping (Bool) -> Void, updateShowCallsTab: @escaping (Bool) -> Void) {
        self.context = context
        self.updateEnableSystemContacts = updateEnableSystemContacts
        self.updateShowContactsTab = updateShowContactsTab
        self.updateShowCallsTab = updateShowCallsTab
    }
}

private enum TelegentSettingsSection: Int32 {
    case contacts
    case calls
}

private enum TelegentSettingsEntry: ItemListNodeEntry {
    case contactsHeader(PresentationTheme, String)
    case enableSystemContacts(PresentationTheme, String, Bool)
    case enableSystemContactsInfo(PresentationTheme, String)
    case showContactsTab(PresentationTheme, String, Bool)
    case callsHeader(PresentationTheme, String)
    case showCallsTab(PresentationTheme, String, Bool)

    var section: ItemListSectionId {
        switch self {
        case .contactsHeader, .enableSystemContacts, .enableSystemContactsInfo, .showContactsTab:
            return TelegentSettingsSection.contacts.rawValue
        case .callsHeader, .showCallsTab:
            return TelegentSettingsSection.calls.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .contactsHeader: return 0
        case .enableSystemContacts: return 1
        case .enableSystemContactsInfo: return 2
        case .showContactsTab: return 3
        case .callsHeader: return 4
        case .showCallsTab: return 5
        }
    }

    static func ==(lhs: TelegentSettingsEntry, rhs: TelegentSettingsEntry) -> Bool {
        switch lhs {
        case let .contactsHeader(lhsTheme, lhsText):
            if case let .contactsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .enableSystemContacts(lhsTheme, lhsText, lhsValue):
            if case let .enableSystemContacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .enableSystemContactsInfo(lhsTheme, lhsText):
            if case let .enableSystemContactsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .showContactsTab(lhsTheme, lhsText, lhsValue):
            if case let .showContactsTab(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .callsHeader(lhsTheme, lhsText):
            if case let .callsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText { return true } else { return false }
        case let .showCallsTab(lhsTheme, lhsText, lhsValue):
            if case let .showCallsTab(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        }
    }

    static func <(lhs: TelegentSettingsEntry, rhs: TelegentSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TelegentSettingsArguments
        switch self {
        case let .contactsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .enableSystemContacts(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.updateEnableSystemContacts(updatedValue)
            })
        case let .enableSystemContactsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .showContactsTab(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.updateShowContactsTab(updatedValue)
            })
        case let .callsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .showCallsTab(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.updateShowCallsTab(updatedValue)
            })
        }
    }
}

private func telegentSettingsEntries(presentationData: PresentationData, synchronizeContacts: Bool, telegentSettings: TelegentSettings) -> [TelegentSettingsEntry] {
    var entries: [TelegentSettingsEntry] = []

    entries.append(.contactsHeader(presentationData.theme, "CONTACTS"))
    entries.append(.enableSystemContacts(presentationData.theme, "Enable System Contacts", synchronizeContacts))
    entries.append(.enableSystemContactsInfo(presentationData.theme, "When enabled, Telegent will request access to your system contacts and sync them with Telegram servers. This is disabled by default for privacy."))
    entries.append(.showContactsTab(presentationData.theme, "Show Contacts Tab", telegentSettings.showContactsTab))

    entries.append(.callsHeader(presentationData.theme, "CALLS"))
    entries.append(.showCallsTab(presentationData.theme, "Show Calls Tab", telegentSettings.showCallsTab))

    return entries
}

public func telegentSettingsController(context: AccountContext) -> ViewController {
    let arguments = TelegentSettingsArguments(
        context: context,
        updateEnableSystemContacts: { value in
            let _ = context.engine.contacts.updateIsContactSynchronizationEnabled(isContactSynchronizationEnabled: value).startStandalone()
            let _ = updateContactSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                var settings = $0
                settings._legacySynchronizeDeviceContacts = value
                return settings
            }).startStandalone()
        },
        updateShowContactsTab: { value in
            let _ = updateTelegentSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                var settings = $0
                settings.showContactsTab = value
                return settings
            }).startStandalone()
        },
        updateShowCallsTab: { value in
            let _ = updateTelegentSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                var settings = $0
                settings.showCallsTab = value
                return settings
            }).startStandalone()
        }
    )

    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.account.postbox.preferencesView(keys: [PreferencesKeys.contactsSettings]),
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.telegentSettings])
    )
    |> map { presentationData, preferences, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let contactsSettings: ContactsSettings = preferences.values[PreferencesKeys.contactsSettings]?.get(ContactsSettings.self) ?? ContactsSettings.defaultSettings
        let telegentSettings: TelegentSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.telegentSettings]?.get(TelegentSettings.self) ?? .defaultSettings
        let entries = telegentSettingsEntries(presentationData: presentationData, synchronizeContacts: contactsSettings.synchronizeContacts, telegentSettings: telegentSettings)

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Telegent"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
