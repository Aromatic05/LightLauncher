extension ConfigManager {
    func updatePreferredTerminal(_ terminal: String) {
        config.modes.preferredTerminal = terminal
        saveConfig()
    }
}
