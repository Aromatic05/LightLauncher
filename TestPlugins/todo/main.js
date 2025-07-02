// Todo 插件示例
class TodoPlugin {
    constructor() {
        // 默认配置
        this.config = {
            maxItems: 10,
            showCompleted: true,
            dataFile: "todos.json",
            iconTheme: "sf_symbols"
        };
        
        // 权限状态
        this.permissions = {
            fileWrite: false,
            network: false,
            clipboard: false,
            notifications: false
        };
        
        // 默认数据
        this.todos = [
            { id: 1, text: "Learn JavaScript", completed: false, category: "学习" },
            { id: 2, text: "Build a plugin system", completed: true, category: "工作" },
            { id: 3, text: "Test the plugin", completed: false, category: "工作" }
        ];
        
        // 注册搜索回调
        lightlauncher.registerCallback(this.handleSearch.bind(this));
        
        // 注册动作处理器
        lightlauncher.registerActionHandler(this.handleAction.bind(this));
        
        // 直接初始化，不使用 setTimeout（JavaScriptCore 可能不支持）
        this.initialize();
        
        lightlauncher.log("Todo plugin initialized with " + this.todos.length + " items");
    }
    
    initialize() {
        // 检查权限
        this.checkPermissions();
        
        // 加载配置
        this.loadConfig();
        
        // 从数据文件加载待办事项
        this.loadTodos();
    }
    
    checkPermissions() {
        // 检查当前权限状态
        this.permissions.fileWrite = lightlauncher.hasFileWritePermission();
        this.permissions.network = lightlauncher.hasNetworkPermission();
        
        lightlauncher.log("Current permissions - External File Write: " + this.permissions.fileWrite + 
                         ", Network: " + this.permissions.network);
    }
    
    loadConfig() {
        try {
            const configContent = lightlauncher.readConfig();
            if (configContent) {
                // 简单的 YAML 解析（仅支持基本格式）
                const config = this.parseSimpleYAML(configContent);
                if (config.settings) {
                    Object.assign(this.config, config.settings);
                }
                lightlauncher.log("Configuration loaded successfully");
            } else {
                lightlauncher.log("No configuration found, using defaults");
                this.createDefaultConfig();
            }
        } catch (error) {
            lightlauncher.log("Failed to load configuration: " + error);
        }
    }
    
    createDefaultConfig() {
        const defaultConfig = `# Todo 插件配置
enabled: true
version: "1.0.0"
settings:
  max_items: 10
  show_completed: true
  data_file: "todos.json"
  icon_theme: "sf_symbols"
`;
        
        if (lightlauncher.writeConfig(defaultConfig)) {
            lightlauncher.log("Default configuration created");
        }
    }
    
    parseSimpleYAML(yamlContent) {
        // 简单的 YAML 解析器（仅支持基本的键值对）
        const lines = yamlContent.split('\n');
        const config = { settings: {} };
        let currentSection = null;
        
        for (const line of lines) {
            const trimmed = line.trim();
            if (trimmed.startsWith('#') || trimmed === '') continue;
            
            if (trimmed.endsWith(':') && !trimmed.includes(' ')) {
                currentSection = trimmed.slice(0, -1);
                continue;
            }
            
            if (trimmed.includes(': ')) {
                const [key, value] = trimmed.split(': ', 2);
                const cleanKey = key.trim();
                let cleanValue = value.trim();
                
                // 简单类型转换
                if (cleanValue === 'true') cleanValue = true;
                else if (cleanValue === 'false') cleanValue = false;
                else if (!isNaN(cleanValue)) cleanValue = parseInt(cleanValue);
                else if (cleanValue.startsWith('"') && cleanValue.endsWith('"')) {
                    cleanValue = cleanValue.slice(1, -1);
                }
                
                if (currentSection === 'settings') {
                    config.settings[cleanKey] = cleanValue;
                } else {
                    config[cleanKey] = cleanValue;
                }
            }
        }
        
        return config;
    }
    
    loadTodos() {
        try {
            const dataPath = lightlauncher.getDataPath() + "/" + this.config.dataFile;
            const todoData = lightlauncher.readFile(dataPath);
            if (todoData) {
                this.todos = JSON.parse(todoData);
                lightlauncher.log("Loaded " + this.todos.length + " todos from data file");
            }
        } catch (error) {
            lightlauncher.log("Failed to load todos: " + error);
        }
    }
    
    saveTodos() {
        try {
            const dataPath = lightlauncher.getDataPath() + "/" + this.config.dataFile;
            const todoData = JSON.stringify(this.todos, null, 2);
            
            // 使用单参数的 writeFileWithData 方法
            if (typeof lightlauncher.writeFileWithData === 'function') {
                const success = lightlauncher.writeFileWithData({path: dataPath, content: todoData});
                if (success) {
                    lightlauncher.log("Todos saved successfully");
                    return true;
                } else {
                    lightlauncher.log("Failed to save todos");
                }
            } else {
                lightlauncher.log("writeFileWithData method not available");
            }
            
            // 备用方案：使用 writeConfig
            if (typeof lightlauncher.writeConfig === 'function') {
                const configData = `# Todo Plugin Data\ntodos_data: |\n${todoData.split('\n').map(line => '  ' + line).join('\n')}\n`;
                const success = lightlauncher.writeConfig(configData);
                if (success) {
                    lightlauncher.log("Todos saved as config data");
                    return true;
                }
            }
            
            return false;
        } catch (error) {
            lightlauncher.log("Error saving todos: " + error);
            return false;
        }
    }
    
    handleSearch(query) {
        if (!query || query.trim() === "") {
            this.displayAllTodos();
        } else if (query.startsWith("add ")) {
            const todoText = query.substring(4).trim();
            if (todoText) {
                this.addTodo(todoText);
            } else {
                this.displayAllTodos();
            }
        } else {
            this.searchTodos(query);
        }
    }
    
    handleAction(action) {
        if (action === "add_new") {
            lightlauncher.display([{
                title: "Add a new todo",
                subtitle: "Type 'add <your task>' to create a new todo item",
                icon: "plus.circle.fill",
                action: "help_add"
            }]);
            return true;
        } else if (action === "show_all") {
            this.displayAllTodos();
            return true;
        } else if (action === "show_permissions") {
            this.displayPermissionStatus();
            return true;
        } else if (action === "request_file_permission") {
            this.requestFileWritePermission();
            return true;
        } else if (action.startsWith("toggle_")) {
            const todoId = parseInt(action.substring(7));
            return this.toggleTodo(todoId);
        } else if (action.startsWith("delete_")) {
            const todoId = parseInt(action.substring(7));
            return this.deleteTodo(todoId);
        }
        
        return false;
    }
    
    displayAllTodos() {
        const results = this.todos.map(todo => ({
            title: (todo.completed ? "✅ " : "⭕ ") + todo.text,
            subtitle: todo.completed ? "Completed" : "Todo",
            icon: todo.completed ? "checkmark.circle.fill" : "circle",
            action: "toggle_" + todo.id
        }));
        
        results.unshift({
            title: "Add new todo...",
            subtitle: "Type 'add <task>' to create a new todo",
            icon: "plus.circle",
            action: "add_new"
        });
        
        // 添加权限状态选项
        results.push({
            title: "🔒 View Permissions",
            subtitle: "Check plugin permission status",
            icon: "checkmark.shield",
            action: "show_permissions"
        });
        
        lightlauncher.display(results);
    }
    
    addTodo(text) {
        const newId = Math.max(...this.todos.map(t => t.id)) + 1;
        this.todos.push({
            id: newId,
            text: text,
            completed: false
        });
        
        // 尝试保存数据
        this.saveTodos();
        
        lightlauncher.display([{
            title: "✅ Added: " + text,
            subtitle: "Todo added successfully",
            icon: "checkmark.circle.fill",
            action: "show_all"
        }]);
        
        lightlauncher.log("Added new todo: " + text);
    }
    
    toggleTodo(id) {
        const todo = this.todos.find(t => t.id === id);
        if (!todo) {
            lightlauncher.log("Todo not found: " + id);
            return false;
        }
        
        todo.completed = !todo.completed;
        lightlauncher.log("Toggled todo: " + todo.text + " -> " + (todo.completed ? "completed" : "todo"));
        
        // 尝试保存数据
        this.saveTodos();
        
        // 重新显示所有待办事项
        this.displayAllTodos();
        return true;
    }
    
    deleteTodo(id) {
        const index = this.todos.findIndex(t => t.id === id);
        if (index === -1) {
            lightlauncher.log("Todo not found for deletion: " + id);
            return false;
        }
        
        const deletedTodo = this.todos.splice(index, 1)[0];
        lightlauncher.log("Deleted todo: " + deletedTodo.text);
        
        // 尝试保存数据
        this.saveTodos();
        
        // 重新显示所有待办事项
        this.displayAllTodos();
        return true;
    }
    
    searchTodos(query) {
        const filteredTodos = this.todos.filter(todo => 
            todo.text.toLowerCase().includes(query.toLowerCase())
        );
        
        if (filteredTodos.length === 0) {
            lightlauncher.display([{
                title: "No todos found",
                subtitle: "Try a different search term",
                icon: "magnifyingglass",
                action: "show_all"
            }]);
            return;
        }
        
        const results = filteredTodos.map(todo => ({
            title: (todo.completed ? "✅ " : "⭕ ") + todo.text,
            subtitle: todo.completed ? "Completed" : "Todo",
            icon: todo.completed ? "checkmark.circle.fill" : "circle",
            action: "toggle_" + todo.id
        }));
        
        lightlauncher.display(results);
    }
    
    displayPermissionStatus() {
        const results = [];
        
        // 权限状态标题
        results.push({
            title: "📋 Plugin Permissions Status",
            subtitle: "Current permission status for Todo plugin",
            icon: "checkmark.shield",
            action: "show_all"
        });
        
        // 文件写入权限
        results.push({
            title: this.permissions.fileWrite ? "✅ External File Write Access" : "❌ External File Write Access",
            subtitle: this.permissions.fileWrite ? "Granted - Can write files outside plugin data directory" : "Denied - Cannot write files outside plugin data directory",
            icon: this.permissions.fileWrite ? "checkmark.circle.fill" : "xmark.circle.fill",
            action: this.permissions.fileWrite ? "show_all" : "request_file_permission"
        });
        
        // 网络访问权限
        results.push({
            title: this.permissions.network ? "✅ Network Access" : "❌ Network Access",
            subtitle: this.permissions.network ? "Granted - Can sync to cloud" : "Denied - Cannot access network",
            icon: this.permissions.network ? "wifi" : "wifi.slash",
            action: "show_all"
        });
        
        lightlauncher.display(results);
    }
    
    requestFileWritePermission() {
        lightlauncher.log("Requesting external file write permission...");
        
        lightlauncher.requestPermission("file_write", (granted, message) => {
            lightlauncher.log("External file write permission result: " + granted + " - " + message);
            this.permissions.fileWrite = granted;
            
            // 显示结果
            lightlauncher.display([{
                title: granted ? "✅ Permission Granted" : "⏳ Permission Request Sent",
                subtitle: message,
                icon: granted ? "checkmark.circle.fill" : "clock.circle",
                action: "show_permissions"
            }]);
        });
    }
}

// 初始化插件
const todoPlugin = new TodoPlugin();
