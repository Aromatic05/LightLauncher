extension ConfigManager{
    func updateDefaultSearchEngine(_ engine: String) {
        config.modes.defaultSearchEngine = engine
        saveConfig()
    }
}