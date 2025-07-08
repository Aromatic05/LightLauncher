// LightLauncher Todo 插件全新实现
let currentInput = "";

class TodoPlugin {
    constructor() {
        this.config = {
            dataFile: "todos.json"
        };
        this.todos = [];
        this.permissions = {};
        this.loadTodos();
        lightlauncher.registerCallback(this.handleSearch.bind(this));
        lightlauncher.registerActionHandler(this.handleAction.bind(this));
        this.checkPermissions();
        this.displayAllTodos();
        lightlauncher.log("Todo plugin initialized todos");
    }

    checkPermissions() {
        this.permissions.fileWrite = lightlauncher.hasFileWritePermission();
        this.permissions.network = lightlauncher.hasNetworkPermission();
    }

    loadTodos() {
        try {
            const path = lightlauncher.getDataPath() + "/" + this.config.dataFile;
            const data = lightlauncher.readFile(path);
            if (data) this.todos = JSON.parse(data);
        } catch {}
    }

    saveTodos() {
        try {
            const path = lightlauncher.getDataPath() + "/" + this.config.dataFile;
            lightlauncher.writeFile({path, content: JSON.stringify(this.todos, null, 2)});
        } catch {}
    }

    handleSearch(query) {
        if (query && query.trim()) currentInput = query.trim();
        if (!query || !query.trim()) {
            this.displayAllTodos();
        } else {
            this.searchTodos(query);
        }
    }

    handleAction(action) {
        if (action.startsWith("add_new")) {
            let text = "";
            const idx = action.indexOf(":");
            if (idx !== -1) text = action.substring(idx + 1).trim();
            else text = currentInput;
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
        const results = this.todos.map(todo => ({
            title: (todo.completed ? "✅ " : "⭕ ") + todo.text,
            subtitle: todo.completed ? "Completed" : "Todo",
            icon: todo.completed ? "checkmark.circle.fill" : "circle",
            action: "toggle_" + todo.id
        }));
        results.unshift({
            title: "Add new todo...",
            subtitle: currentInput ? `添加：${currentInput}` : "Type and click to add new todo",
            icon: "plus.circle",
            action: `add_new:${currentInput}`
        });
        lightlauncher.display(results);
    }

    addTodo(text) {
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
        if (filtered.length === 0) {
            lightlauncher.display([{
                title: "No todos found",
                subtitle: "Try a different search term",
                icon: "magnifyingglass",
                action: "show_all"
            }]);
            return;
        }
        const results = filtered.map(todo => ({
            title: (todo.completed ? "✅ " : "⭕ ") + todo.text,
            subtitle: todo.completed ? "Completed" : "Todo",
            icon: todo.completed ? "checkmark.circle.fill" : "circle",
            action: "toggle_" + todo.id
        }));
        lightlauncher.display(results);
    }
}

const todoPlugin = new TodoPlugin();
