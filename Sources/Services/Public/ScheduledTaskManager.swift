import Foundation

/// 计划任务管理器
/// 用于管理应用中的定时任务，支持添加、移除、暂停和恢复任务
@MainActor
class ScheduledTaskManager {
    static let shared = ScheduledTaskManager()

    /// 定时任务项
    private struct ScheduledTask {
        let id: String
        let interval: TimeInterval
        let task: @MainActor () -> Void
        var timer: Timer?
        var isPaused: Bool = false
    }

    private var tasks: [String: ScheduledTask] = [:]

    private init() {}

    /// 添加一个定时任务
    /// - Parameters:
    ///   - id: 任务唯一标识符
    ///   - interval: 执行间隔（秒）
    ///   - executeImmediately: 是否立即执行一次，默认为 true
    ///   - task: 要执行的任务闭包
    func addTask(
        id: String,
        interval: TimeInterval,
        executeImmediately: Bool = true,
        task: @escaping @MainActor () -> Void
    ) {
        // 如果已存在同名任务，先移除
        removeTask(id: id)

        // 如果需要立即执行
        if executeImmediately {
            task()
        }

        // 创建定时器
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                task()
            }
        }

        let scheduledTask = ScheduledTask(id: id, interval: interval, task: task, timer: timer)
        tasks[id] = scheduledTask

        Logger.shared.info("✅ 已添加定时任务: \(id), 间隔: \(interval)秒", owner: self)
    }

    /// 移除一个定时任务
    /// - Parameter id: 任务唯一标识符
    func removeTask(id: String) {
        guard let task = tasks[id] else { return }
        task.timer?.invalidate()
        tasks.removeValue(forKey: id)
        Logger.shared.info("🗑️ 已移除定时任务: \(id)", owner: self)
    }

    /// 暂停一个定时任务
    /// - Parameter id: 任务唯一标识符
    func pauseTask(id: String) {
        guard var task = tasks[id], !task.isPaused else { return }
        task.timer?.invalidate()
        task.timer = nil
        task.isPaused = true
        tasks[id] = task
        Logger.shared.info("⏸️ 已暂停定时任务: \(id)", owner: self)
    }

    /// 恢复一个定时任务
    /// - Parameter id: 任务唯一标识符
    func resumeTask(id: String) {
        guard var task = tasks[id], task.isPaused else { return }

        // 捕获任务闭包
        let taskClosure = task.task

        // 重新创建定时器
        let timer = Timer.scheduledTimer(withTimeInterval: task.interval, repeats: true) { _ in
            Task { @MainActor in
                taskClosure()
            }
        }

        task.timer = timer
        task.isPaused = false
        tasks[id] = task
        Logger.shared.info("▶️ 已恢复定时任务: \(id)", owner: self)
    }

    /// 移除所有定时任务
    func removeAllTasks() {
        for (_, task) in tasks {
            task.timer?.invalidate()
        }
        tasks.removeAll()
        Logger.shared.info("🗑️ 已移除所有定时任务", owner: self)
    }

    /// 获取所有任务的 ID 列表
    func getAllTaskIds() -> [String] {
        return Array(tasks.keys)
    }

    /// 检查任务是否存在
    /// - Parameter id: 任务唯一标识符
    /// - Returns: 任务是否存在
    func hasTask(id: String) -> Bool {
        return tasks[id] != nil
    }

    /// 检查任务是否已暂停
    /// - Parameter id: 任务唯一标识符
    /// - Returns: 任务是否已暂停
    func isTaskPaused(id: String) -> Bool {
        return tasks[id]?.isPaused ?? false
    }
}
