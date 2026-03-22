import Foundation
import SwiftSignalKit
import TelegramCore
import Display
import DeviceAccess
import AccountContext
import AlertUI
import PresentationDataUtils
import PeerInfoUI
import ShareController

func openAddContactImpl(context: AccountContext, firstName: String = "", lastName: String = "", phoneNumber: String, label: String = "_$!<Mobile>!$_", present: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void, completed: @escaping () -> Void = {}) {
    // Telegent: skip system contacts permission check
    let controller = context.sharedContext.makeNewContactScreen(
        context: context,
        peer: nil,
        phoneNumber: phoneNumber,
        shareViaException: false,
        completion: { peer, stableId, contactData in
            if let peer = peer {
                if let infoController = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                    pushController(infoController)
                }
            } else if let stableId, let contactData {
                pushController(deviceContactInfoController(context: ShareControllerAppAccountContext(context: context), environment: ShareControllerAppEnvironment(sharedContext: context.sharedContext), subject: .vcard(nil, stableId, contactData), completed: nil, cancelled: nil))
            }
            completed()
        }
    )
    pushController(controller)
}
