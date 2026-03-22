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

    init(context: AccountContext, updateEnableSystemContacts: @escaping (Bool) -> Void) {
        self.context = context
        self.updateEnableSystemContacts = updateEnableSystemContacts
    }
}

private enum TelegentSettingsSection: Int32 {
    case contacts
}

private enum TelegentSettingsEntry: ItemListNodeEntry {
    case contactsHeader(PresentationTheme, String)
    case enableSystemContacts(PresentationTheme, String, Bool)
    case enableSystemContactsInfo(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .contactsHeader, .enableSystemContacts, .enableSystemContactsInfo:
            return TelegentSettingsSection.contacts.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .contactsHeader:
            return 0
        case .enableSystemContacts:
            return 1
        case .enableSystemContactsInfo:
            return 2
        }
    }

    static func ==(lhs: TelegentSettingsEntry, rhs: TelegentSettingsEntry) -> Bool {
        switch lhs {
        case let .contactsHeader(lhsTheme, lhsText):
            if case let .contactsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .enableSystemContacts(lhsTheme, lhsText, lhsValue):
            if case let .enableSystemContacts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .enableSystemContactsInfo(lhsTheme, lhsText):
            if case let .enableSystemContactsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
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
        }
    }
}

private func telegentSettingsEntries(presentationData: PresentationData, synchronizeContacts: Bool) -> [TelegentSettingsEntry] {
    var entries: [TelegentSettingsEntry] = []

    entries.append(.contactsHeader(presentationData.theme, "CONTACTS"))
    entries.append(.enableSystemContacts(presentationData.theme, "Enable System Contacts", synchronizeContacts))
    entries.append(.enableSystemContactsInfo(presentationData.theme, "When enabled, Telegent will request access to your system contacts and sync them with Telegram servers. This is disabled by default for privacy."))

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
        }
    )

    let signal = combineLatest(
        queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.account.postbox.preferencesView(keys: [PreferencesKeys.contactsSettings])
    )
    |> map { presentationData, preferences -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings: ContactsSettings = preferences.values[PreferencesKeys.contactsSettings]?.get(ContactsSettings.self) ?? ContactsSettings.defaultSettings
        let entries = telegentSettingsEntries(presentationData: presentationData, synchronizeContacts: settings.synchronizeContacts)

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Telegent"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
