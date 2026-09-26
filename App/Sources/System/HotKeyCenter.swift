import Carbon
import Foundation

/// System-wide hot keys through Carbon's RegisterEventHotKey (no permission needed).
final class HotKeyCenter {
    var onAction: ((HotKeyAction) -> Void)?

    private var handler: EventHandlerRef?
    private var registered: [EventHotKeyRef] = []
    private var actions: [UInt32: HotKeyAction] = [:]
    private static let signature: OSType = 0x444C_4B59 // "DLKY"

    /// Registers the enabled bindings, replacing earlier ones. Returns the actions that could not be
    /// registered (usually because another app already owns the shortcut).
    @discardableResult
    func register(_ bindings: [HotKeyBinding]) -> [HotKeyAction] {
        installHandlerIfNeeded()
        unregisterAll()
        var failed: [HotKeyAction] = []
        for (index, binding) in bindings.enumerated() where binding.enabled {
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.keyCode, binding.modifiers.carbonFlags,
                                             EventHotKeyID(signature: Self.signature, id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registered.append(ref)
                actions[id] = binding.action
            } else {
                failed.append(binding.action)
            }
        }
        return failed
    }

    func unregisterAll() {
        for ref in registered { UnregisterEventHotKey(ref) }
        registered.removeAll()
        actions.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            center.fire(hotKeyID.id)
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    private func fire(_ id: UInt32) {
        guard let action = actions[id] else { return }
        DispatchQueue.main.async { [weak self] in self?.onAction?(action) }
    }
}
