// LightLauncher Todo 插件 - 重写版本
// 与新插件架构完全兼容

class TodoPlugin {
    constructor() {
        // 初始化配置
        this.config = lightlauncher.getConfig();
        this.dataFile = this.config.dataFile || "todos.json";
        
        // 初始化数据
        this.todos = [];
        this.currentInput = "";
        this.lastQuery = "";
        
        // 注册插件回调
        lightlauncher.registerCallback(this.handleInput.bind(this));
        lightlauncher.registerActionHandler(this.handleAction.bind(this));
        
        // 加载数据
        this.loadTodos();
        
        // 显示初始状态
        this.displayTodos();
        
        lightlauncher.log("Todo plugin initialized successfully");
    }

    /**
     * 处理用户输入
     */
    handleInput(query) {
        // 清理输入
        let cleanQuery = query ? query.trim() : "";
        // 移除命令前缀
        if (cleanQuery.startsWith("/todo")) {
            cleanQuery = cleanQuery.replace(/^\/todo\s*/, "");
        }
        this.currentInput = cleanQuery;
        this.lastQuery = cleanQuery || this.lastQuery;
        if (cleanQuery) {
            // 如果有输入，进行搜索
            this.searchTodos(cleanQuery);
        } else {
            // 显示所有待办事项
            this.displayTodos();
        }
        // 强制刷新视图（兼容部分宿主环境）
        if (typeof lightlauncher.refresh === "function") {
            lightlauncher.refresh();
        }
    }

    /**
     * 处理用户动作
     */
    handleAction(action) {
        lightlauncher.log(`Handling action: ${action}`);
        
        try {
            if (action.startsWith("add:")) {
                // 添加新待办事项
                const text = action.substring(4).trim();
                if (text) {
                    this.addTodo(text);
                    return true;
                }
            } else if (action.startsWith("toggle:")) {
                // 切换完成状态
                const id = parseInt(action.substring(7));
                this.toggleTodo(id);
                return true;
            } else if (action.startsWith("delete:")) {
                // 删除待办事项
                const id = parseInt(action.substring(7));
                this.deleteTodo(id);
                return true;
            } else if (action === "show_all") {
                // 显示所有待办事项
                this.displayTodos();
                return true;
            } else if (action === "clear_completed") {
                // 清除已完成的待办事项
                this.clearCompleted();
                return true;
            }
        } catch (error) {
            lightlauncher.log(`Action error: ${error.message}`);
        }
        
        return false;
    }

    /**
     * 加载待办事项数据
     */
    loadTodos() {
        try {
            const dataPath = lightlauncher.getDataPath();
            const filePath = `${dataPath}/${this.dataFile}`;
            lightlauncher.log(`Loading todos from: ${filePath}`);
            const data = lightlauncher.readFile(filePath);
            if (data) {
                this.todos = JSON.parse(data);
                lightlauncher.log(`Loaded ${this.todos.length} todos`);
            } else {
                // 文件不存在，填充样例数据
                this.todos = [
                    {
                        id: 1,
                        text: "欢迎使用 Todo 插件！",
                        completed: false,
                        createdAt: Date.now(),
                        updatedAt: Date.now()
                    },
                    {
                        id: 2,
                        text: "点击切换完成状态",
                        completed: false,
                        createdAt: Date.now(),
                        updatedAt: Date.now()
                    },
                    {
                        id: 3,
                        text: "点击删除待办事项",
                        completed: false,
                        createdAt: Date.now(),
                        updatedAt: Date.now()
                    }
                ];
                // 创建文件
                const content = JSON.stringify(this.todos, null, 2);
                const success = lightlauncher.writeFile({
                    path: filePath,
                    content: content
                });
                if (success) {
                    lightlauncher.log("Created todos file with sample data");
                } else {
                    lightlauncher.log("Failed to create todos file");
                }
            }
        } catch (error) {
            lightlauncher.log(`Error loading todos: ${error.message}`);
            this.todos = [];
        }
    }

    /**
     * 保存待办事项数据
     */
    saveTodos() {
        try {
            const dataPath = lightlauncher.getDataPath();
            const filePath = `${dataPath}/${this.dataFile}`;
            const content = JSON.stringify(this.todos, null, 2);
            
            const success = lightlauncher.writeFile({
                path: filePath,
                content: content
            });
            
            if (success) {
                lightlauncher.log(`Saved ${this.todos.length} todos`);
            } else {
                lightlauncher.log("Failed to save todos");
            }
        } catch (error) {
            lightlauncher.log(`Error saving todos: ${error.message}`);
        }
    }

    /**
     * 添加新待办事项
     */
    addTodo(text) {
        if (!text || text.trim().length === 0) {
            return;
        }

        const newId = this.todos.length > 0 ? Math.max(...this.todos.map(t => t.id)) + 1 : 1;
        const newTodo = {
            id: newId,
            text: text.trim(),
            completed: false,
            createdAt: Date.now(),
            updatedAt: Date.now()
        };

        this.todos.push(newTodo);
        this.saveTodos();
        this.displayTodos();
        
        lightlauncher.log(`Added todo: "${text}"`);
    }

    /**
     * 切换待办事项完成状态
     */
    toggleTodo(id) {
        const todo = this.todos.find(t => t.id === id);
        if (todo) {
            todo.completed = !todo.completed;
            todo.updatedAt = Date.now();
            this.saveTodos();
            this.displayTodos();
            lightlauncher.log(`Toggled todo ${id}: ${todo.completed ? 'completed' : 'active'}`);
        }
    }

    /**
     * 删除待办事项
     */
    deleteTodo(id) {
        const index = this.todos.findIndex(t => t.id === id);
        if (index !== -1) {
            const deleted = this.todos.splice(index, 1)[0];
            this.saveTodos();
            this.displayTodos();
            lightlauncher.log(`Deleted todo: "${deleted.text}"`);
        }
    }

    /**
     * 清除已完成的待办事项
     */
    clearCompleted() {
        const completedCount = this.todos.filter(t => t.completed).length;
        this.todos = this.todos.filter(t => !t.completed);
        this.saveTodos();
        this.displayTodos();
        lightlauncher.log(`Cleared ${completedCount} completed todos`);
    }

    /**
     * 搜索待办事项
     */
    searchTodos(query) {
        const filtered = this.todos.filter(todo => 
            todo.text.toLowerCase().includes(query.toLowerCase())
        );

        this.displayTodos(filtered, query);
    }

    /**
     * 显示待办事项列表
     */
    displayTodos(todoList = null, searchQuery = "") {
        const todos = todoList || this.todos;
        const query = searchQuery || this.currentInput;
        
        let results = [];

        // 添加"新增待办事项"选项
        if (query && query.trim().length > 0) {
            results.push({
                title: `➕ 添加待办事项: "${query}"`,
                subtitle: "按回车键添加新的待办事项",
                icon: "SF:plus.circle.fill",
                action: `add:${query}`
            });
        } else if (this.lastQuery && this.lastQuery.trim().length > 0) {
            results.push({
                title: `➕ 添加待办事项: "${this.lastQuery}"`,
                subtitle: "按回车键添加新的待办事项",
                icon: "SF:plus.circle.fill", 
                action: `add:${this.lastQuery}`
            });
        } else {
            results.push({
                title: "➕ 添加新的待办事项",
                subtitle: "输入内容后按回车键添加",
                icon: "SF:plus.circle",
                action: "add:"
            });
        }

        // 添加现有待办事项
        if (todos.length > 0) {
            // 按状态排序：未完成在前，已完成在后
            const sortedTodos = [...todos].sort((a, b) => {
                if (a.completed === b.completed) {
                    return b.updatedAt - a.updatedAt; // 最近更新的在前
                }
                return a.completed ? 1 : -1; // 未完成的在前
            });

            sortedTodos.forEach(todo => {
                const icon = todo.completed ? "SF:checkmark.circle.fill" : "SF:circle";
                const statusText = todo.completed ? "已完成" : "待完成";
                
                results.push({
                    title: `${todo.completed ? "✅" : "⭕"} ${todo.text}`,
                    subtitle: `${statusText} • 点击切换状态`,
                    icon: icon,
                    action: `toggle:${todo.id}`
                });
            });

            // 添加管理选项
            results.push({
                title: "🗑️ 清除已完成的待办事项",
                subtitle: `清除 ${todos.filter(t => t.completed).length} 个已完成项目`,
                icon: "SF:trash.circle",
                action: "clear_completed"
            });
        } else if (searchQuery) {
            // 搜索无结果
            results.push({
                title: "🔍 未找到匹配的待办事项",
                subtitle: "尝试其他搜索关键词",
                icon: "SF:magnifyingglass.circle",
                action: "show_all"
            });
        } else {
            // 空状态
            results.push({
                title: "📋 暂无待办事项",
                subtitle: "开始添加你的第一个待办事项吧",
                icon: "SF:list.bullet.circle",
                action: ""
            });
        }

        // 添加统计信息
        const totalCount = this.todos.length;
        const completedCount = this.todos.filter(t => t.completed).length;
        const activeCount = totalCount - completedCount;

        if (totalCount > 0) {
            results.push({
                title: `📊 统计: ${activeCount} 个待完成，${completedCount} 个已完成`,
                subtitle: `共 ${totalCount} 个待办事项`,
                icon: "SF:chart.bar.circle",
                action: ""
            });
        }

        // 显示结果
        lightlauncher.display(results);
    }

    /**
     * 获取插件统计信息
     */
    getStats() {
        const total = this.todos.length;
        const completed = this.todos.filter(t => t.completed).length;
        const active = total - completed;
        
        return {
            total,
            completed,
            active,
            completionRate: total > 0 ? Math.round((completed / total) * 100) : 0
        };
    }
}

// 初始化插件
let todoPlugin;
try {
    todoPlugin = new TodoPlugin();
    lightlauncher.log("Todo plugin loaded successfully");
} catch (error) {
    lightlauncher.log(`Plugin initialization error: ${error.message}`);
}
todoPlugin; // 让 JSContext 返回插件实例
