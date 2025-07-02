// Todo 插件示例
class TodoPlugin {
    constructor() {
        this.todos = [
            { id: 1, text: "Learn JavaScript", completed: false },
            { id: 2, text: "Build a plugin system", completed: true },
            { id: 3, text: "Test the plugin", completed: false }
        ];
        
        // 注册搜索回调
        lightlauncher.registerCallback(this.handleSearch.bind(this));
        lightlauncher.log("Todo plugin initialized");
    }
    
    handleSearch(query) {
        lightlauncher.log("Todo plugin received query: " + query);
        
        if (!query || query.trim() === "") {
            // 显示所有待办事项
            this.displayAllTodos();
        } else if (query.startsWith("add ")) {
            // 添加新的待办事项
            const todoText = query.substring(4).trim();
            if (todoText) {
                this.addTodo(todoText);
            }
        } else {
            // 搜索待办事项
            this.searchTodos(query);
        }
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
        
        lightlauncher.display(results);
    }
    
    addTodo(text) {
        const newId = Math.max(...this.todos.map(t => t.id)) + 1;
        this.todos.push({
            id: newId,
            text: text,
            completed: false
        });
        
        lightlauncher.display([{
            title: "✅ Added: " + text,
            subtitle: "Todo added successfully",
            icon: "checkmark.circle.fill",
            action: "show_all"
        }]);
        
        lightlauncher.log("Added new todo: " + text);
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
}

// 初始化插件
const todoPlugin = new TodoPlugin();
