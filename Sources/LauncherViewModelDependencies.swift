import Combine
import Foundation

@MainActor
protocol CommandRegistryManaging: AnyObject {
    func register(_ controller: ModeStateController)
    func findCommand(for text: String) -> (record: CommandRecord, arguments: String)?
    func getCommandSuggestions() -> [CommandRecord]
}

extension CommandRegistry: CommandRegistryManaging {}

@MainActor
protocol KeyboardEventManaging: AnyObject {
    var keyEvents: AnyPublisher<KeyEvent, Never> { get }
    func updateInterceptionRules(for modeKeys: Set<KeyEvent>)
}

extension KeyboardEventHandler: KeyboardEventManaging {
    var keyEvents: AnyPublisher<KeyEvent, Never> {
        keyEventPublisher.eraseToAnyPublisher()
    }
}

@MainActor
protocol CommandSuggestionSettingsProviding: AnyObject {
    var showCommandSuggestionsEnabled: Bool { get }
}

extension SettingsManager: CommandSuggestionSettingsProviding {
    var showCommandSuggestionsEnabled: Bool {
        showCommandSuggestions
    }
}
