// LightLauncher Todo 插件全新实现
class TodoPlugin {
    constructor() {
        this.config = {
            dataFile: "todos.json"
        };
        this.todos = [];
        this.permissions = {};
        this.currentInput = "";
        this.lastNonEmptyInput = "";
        this.loadTodos();
        lightlauncher.registerCallback(this.handleSearch.bind(this));
        lightlauncher.registerActionHandler(this.handleAction.bind(this));
        this.checkPermissions();
        this.displayAllTodos();
        lightlauncher.log("Todo plugin initialized todos");
    }

    // 新增：插件被重建时自动恢复 currentInput 状态
    restoreState(state) {
        if (state && typeof state.currentInput === "string") {
            this.currentInput = state.currentInput;
        }
    }
    // 新增：插件被销毁前保存 currentInput 状态
    getState() {
        return { currentInput: this.currentInput };
    }

    checkPermissions() {
        this.permissions.fileWrite = lightlauncher.hasFileWritePermission();
        this.permissions.network = lightlauncher.hasNetworkPermission();
    }

    loadTodos() {
        lightlauncher.log("Loading todos from file");
        try {
            const path = lightlauncher.getDataPath() + "/" + this.config.dataFile;
            const data = lightlauncher.readFile(path);
            if (data) this.todos = JSON.parse(data);
            lightlauncher.log(`Loaded ${this.todos.length} todos`);
        } catch {}
    }

    saveTodos() {
        try {
            const path = lightlauncher.getDataPath() + "/" + this.config.dataFile;
            lightlauncher.writeFile({path, content: JSON.stringify(this.todos, null, 2)});
        } catch {}
    }

    handleSearch(query) {
        let cleanQuery = query ? query.trim() : "";
        if (cleanQuery.startsWith("/todo")) {
            cleanQuery = cleanQuery.replace(/^\/todo\s*/, "");
        }
        if (cleanQuery) {
            this.currentInput = cleanQuery;
            this.lastNonEmptyInput = cleanQuery;
            this.searchTodos(cleanQuery);
        } else {
            // 不清空 lastNonEmptyInput，保持上次输入
            this.currentInput = "";
            this.displayAllTodos();
        }
        lightlauncher.log(`currentInput: ${this.currentInput}, lastNonEmptyInput: ${this.lastNonEmptyInput}`);
    }

    handleAction(action) {
        if (action.startsWith("add_new")) {
            lightlauncher.log("Adding new todo from action");
            let text = "";
            const idx = action.indexOf(":");
            if (idx !== -1) text = action.substring(idx + 1).trim();
            else text = this.currentInput;
            if (text) this.addTodo(text);
            return true;
        } else if (action.startsWith("toggle_")) {
            const id = parseInt(action.substring(7));
            this.toggleTodo(id);
            return true;
        } else if (action.startsWith("delete_")) {
            const id = parseInt(action.substring(7));
            this.deleteTodo(id);
            return true;
        } else if (action === "show_all") {
            this.displayAllTodos();
            return true;
        }
        return false;
    }

    displayAllTodos() {
        lightlauncher.log("Displaying all todos");
        lightlauncher.log(`Current input: ${this.currentInput}`);
        lightlauncher.log(`Todos : ${JSON.stringify(this.todos)}`);
        const results = this.todos.map(todo => ({
            title: (todo.completed ? "✅ " : "⭕ ") + todo.text,
            subtitle: todo.completed ? "Completed" : "Todo",
            icon: todo.completed ? "checkmark.circle.fill" : "circle",
            action: "toggle_" + todo.id
        }));
        results.unshift({
            title: "Add new todo...",
            subtitle: this.lastNonEmptyInput ? `添加：${this.lastNonEmptyInput}` : "Type and click to add new todo",
            icon: "plus.circle",
            action: `add_new:${this.lastNonEmptyInput}`
        });
        lightlauncher.display(JSON.parse(JSON.stringify(results)));
    }

    addTodo(text) {
        lightlauncher.log(`Adding new todo: ${text}`);
        const newId = this.todos.length > 0 ? Math.max(...this.todos.map(t => t.id)) + 1 : 1;
        this.todos.push({ id: newId, text, completed: false });
        this.saveTodos();
        this.displayAllTodos();
    }

    toggleTodo(id) {
        const todo = this.todos.find(t => t.id === id);
        if (todo) {
            todo.completed = !todo.completed;
            this.saveTodos();
            this.displayAllTodos();
        }
    }

    deleteTodo(id) {
        const idx = this.todos.findIndex(t => t.id === id);
        if (idx !== -1) {
            this.todos.splice(idx, 1);
            this.saveTodos();
            this.displayAllTodos();
        }
    }

    searchTodos(query) {
        const filtered = this.todos.filter(todo => todo.text.toLowerCase().includes(query.toLowerCase()));
        const results = filtered.map(todo => ({
            title: (todo.completed ? "✅ " : "⭕ ") + todo.text,
            subtitle: todo.completed ? "Completed" : "Todo",
            icon: todo.completed ? "checkmark.circle.fill" : "circle",
            action: "toggle_" + todo.id
        }));
        // 无论有无结果，都插入 add_new 行
        results.unshift({
            title: "Add new todo...",
            subtitle: query ? `添加：${query}` : "Type and click to add new todo",
            icon: "plus.circle",
            action: `add_new:${query}`
        });
        if (filtered.length === 0) {
            results.push({
                title: "No todos found",
                subtitle: "Try a different search term",
                icon: "magnifyingglass",
                action: "show_all"
            });
        }
        lightlauncher.display(JSON.parse(JSON.stringify(results)));
    }
}

const todoPlugin = new TodoPlugin();
// 新增：插件主程序可通过 lightlauncher.getPluginState()/setPluginState() 调用 getState/restoreState
if (typeof lightlauncher.setPluginStateHandler === "function") {
    lightlauncher.setPluginStateHandler(
        () => todoPlugin.getState(),
        (state) => todoPlugin.restoreState(state)
    );
}
