extension View {
    /// Starts a task before a view appears (but after ``View/body`` has been
    /// accessed), and cancels the task when the view disappears. Additionally,
    /// if `id` changes the current task is cancelled and a new one is started.
    ///
    /// This variant of `task` can be useful when the lifetime of the task
    /// must be linked to a value with a potentially shorter lifetime than the
    /// view.
    public nonisolated func task<Id: Equatable>(
        id: Id,
        priority: TaskPriority = .userInitiated,
        _ action: @Sendable @escaping () async -> Void
    ) -> some View {
        TaskModifier(
            id: id,
            content: TupleView1(self),
            priority: priority,
            action: action
        )
    }

    /// Starts a task before a view appears (but after ``View/body`` has been
    /// accessed), and cancels the task when the view disappears.
    public nonisolated func task(
        priority: TaskPriority = .userInitiated,
        _ action: @Sendable @escaping () async -> Void
    ) -> some View {
        TaskModifier(
            id: 0,
            content: TupleView1(self),
            priority: priority,
            action: action
        )
    }
}

@View(checkBody: false, checkConformance: false)
struct TaskModifier<Id: Equatable, Content: View> {
    @State var task: Task<(), Never>? = nil

    let id: Id
    let content: Content
    let priority: TaskPriority
    let action: @Sendable () async -> Void

    nonisolated init(
        id: Id,
        content: sending Content,
        priority: TaskPriority,
        action: @Sendable @escaping () async -> Void
    ) {
        self.id = id
        self.content = content
        self.priority = priority
        self.action = action
    }
    
    var body: some View {
        // Explicitly return to disable result builder (we don't want an extra
        // layer of views).
        return
            content
            .onChange(of: id, initial: true) { [action] in
                task?.cancel()
                task = Task(priority: priority) {
                    await action()
                }
            }
            .onDisappear { [task] in
                task?.cancel()
            }
    }
}