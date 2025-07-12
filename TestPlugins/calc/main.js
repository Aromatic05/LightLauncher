// LightLauncher Calc 插件 - 简易 eval 计算器
// 与新插件架构兼容

class CalcPlugin {
    constructor() {
        this.config = lightlauncher.getConfig();
        lightlauncher.registerCallback(this.handleInput.bind(this));
        lightlauncher.registerActionHandler(this.handleAction.bind(this));
        this.lastResult = null;
        lightlauncher.log("Calc plugin initialized successfully");
    }

    /**
     * 处理用户输入
     */
    handleInput(query) {
        let cleanQuery = query ? query.trim() : "";
        if (cleanQuery.startsWith("/calc")) {
            cleanQuery = cleanQuery.replace(/^\/calc\s*/, "");
        }
        if (cleanQuery.length === 0) {
            this.displayWelcome();
            return;
        }
        let result, error = null;
        try {
            // 只允许安全字符
            if (/^[0-9+\-*/().%\s]+$/.test(cleanQuery)) {
                result = eval(cleanQuery);
                this.lastResult = result;
            } else {
                error = "表达式包含非法字符";
            }
        } catch (e) {
            error = e.message;
        }
        this.displayResult(cleanQuery, result, error);
        if (typeof lightlauncher.refresh === "function") {
            lightlauncher.refresh();
        }
    }

    /**
     * 处理用户动作（无特殊动作）
     */
    handleAction(action) {
        // 计算器无需特殊动作
        return false;
    }

    /**
     * 显示计算结果
     */
    displayResult(expr, result, error) {
        let results = [];
        if (error) {
            results.push({
                title: `❌ 错误: ${error}`,
                subtitle: `表达式: ${expr}`,
                icon: "SF:xmark.circle.fill",
                action: ""
            });
        } else {
            results.push({
                title: `🧮 结果: ${result}`,
                subtitle: `表达式: ${expr}`,
                icon: "SF:equal.circle.fill",
                action: ""
            });
        }
        lightlauncher.display(results);
    }

    /**
     * 欢迎界面
     */
    displayWelcome() {
        lightlauncher.display([
            {
                title: "🧮 输入表达式进行计算",
                subtitle: "支持 + - * / % ()，如 1+2*3",
                icon: "SF:plus.slash.minus",
                action: ""
            }
        ]);
    }
}

// 初始化插件
let calcPlugin;
try {
    calcPlugin = new CalcPlugin();
    lightlauncher.log("Calc plugin loaded successfully");
} catch (error) {
    lightlauncher.log(`Plugin initialization error: ${error.message}`);
}
calcPlugin; // 让 JSContext 返回插件实例
