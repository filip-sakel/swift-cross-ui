// Extracted from Swift stdlib's MainActor and from JavaScriptKit's Event Loop.

// MARK: - MainActor

import _Concurrency
// import _EmbdeddedShims

#if hasFeature(Embedded)

// // Linux support
// #warning("Should support all platforms, not just Linux")

// private func createTimerFd(afterMilliseconds delay: Double) -> Int32 {
//     let fd = timerfd_create(CLOCK_MONOTONIC, 0)
//     guard fd >= 0 else {
//         fatalError("timerfd_create failed")
//     }

//     var newValue = itimerspec()
//     let seconds = Int(delay / 1000)
//     let nanoseconds = Int((delay.truncatingRemainder(dividingBy: 1000)) * 1_000_000)

//     newValue.it_value.tv_sec = __time_t(seconds)
//     newValue.it_value.tv_nsec = __suseconds_t(nanoseconds)

//     let result = timerfd_settime(fd, 0, &newValue, nil)
//     guard result == 0 else {
//         fatalError("timerfd_settime failed")
//     }

//     return fd
// }

// final class TimerQueue {
//     static let shared = TimerQueue()

//     private let epollFd: Int32
//     private var jobs: [Int32: UnownedJob] = [:]

//     private init() {
//         self.epollFd = _EmbdeddedShims.swift_epoll_create()
//         guard epollFd >= 0 else {
//             fatalError("epoll_create failed")
//         }
//     }

//     func register(fd: Int32, job: UnownedJob) {
//         let result = _EmbdeddedShims.swift_epoll_ctl_add(epollFd, fd, _EmbdeddedShims.EPOLLIN)
//         guard result == 0 else {
//             close(fd)
//             return
//         }
//         jobs[fd] = job
//     }

//     func poll(timeoutMs: Int32 = -1) {
//         var events = [epoll_event](repeating: epoll_event(), count: 16)
//         let n = _EmbdeddedShims.swift_epoll_wait(
//             epollFd,
//             &events,
//             Int32(events.count),
//             timeoutMs
//         )

//         for i in 0..<n {
//             let fd = Int32(events[Int(i)].data.fd)
//             _ = swift_timerfd_read(fd)
//             close(fd)

//             if let job = jobs.removeValue(forKey: fd) {
//                 EventLoop.shared.insertJobQueue(job: job)
//             }
//         }
//     }
// }

// @globalActor public final actor MainActor: GlobalActor {
//   public static let shared = MainActor()

//   @inlinable
//   public nonisolated var unownedExecutor: UnownedSerialExecutor {
//     return EventLoop.shared.asUnownedSerialExecutor()
//   }

//   @inlinable
//   public static var sharedUnownedExecutor: UnownedSerialExecutor {
//     return EventLoop.shared.asUnownedSerialExecutor()
//   }

//   public nonisolated func enqueue(_ job: UnownedJob) {
//     EventLoop.shared.unsafeEnqueue(job)
//   }
// }

// #if compiler(>=5.5)

// @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
// struct QueueState: Sendable {
//     fileprivate var headJob: UnownedJob? = nil
//     fileprivate var isSpinning: Bool = false
// }

// @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
// extension EventLoop {

//     func insertJobQueue(job newJob: UnownedJob) {
//         withUnsafeMutablePointer(to: &queueState.headJob) { headJobPtr in
//             var position = headJobPtr
//             while let cur = position.pointee {
//                 if cur.rawPriority < newJob.rawPriority {
//                     newJob.nextInQueue().pointee = cur
//                     position.pointee = newJob
//                     break
//                 }
//                 position = cur.nextInQueue()
//             }
//             if position.pointee == nil {
//                 newJob.nextInQueue().pointee = nil
//                 position.pointee = newJob
//             }
//         }

//         if !queueState.isSpinning {
//             queueState.isSpinning = true
//             self.runAllJobs()
//         }
//     }

//     func runAllJobs() {
//         assert(queueState.isSpinning)

//         while let job = self.claimNextFromQueue() {
//             #if compiler(>=5.9)
//             job.runSynchronously(on: self.asUnownedSerialExecutor())
//             #else
//             job._runSynchronously(on: self.asUnownedSerialExecutor())
//             #endif
//         }

//         queueState.isSpinning = false
//     }

//     func claimNextFromQueue() -> UnownedJob? {
//         if let job = self.queueState.headJob {
//             self.queueState.headJob = job.nextInQueue().pointee
//             return job
//         }
//         return nil
//     }
// }

// @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
// extension UnownedJob {
//     private func asImpl() -> UnsafeMutablePointer<_EmbdeddedShims.Job> {
//         unsafeBitCast(self, to: UnsafeMutablePointer<_EmbdeddedShims.Job>.self)
//     }

//     fileprivate var flags: JobFlags {
//         JobFlags(bits: asImpl().pointee.Flags)
//     }

//     fileprivate var rawPriority: UInt32 { flags.priority }

//     fileprivate func nextInQueue() -> UnsafeMutablePointer<UnownedJob?> {
//         return withUnsafeMutablePointer(to: &asImpl().pointee.SchedulerPrivate.0) { rawNextJobPtr in
//             let nextJobPtr = UnsafeMutableRawPointer(rawNextJobPtr).bindMemory(to: UnownedJob?.self, capacity: 1)
//             return nextJobPtr
//         }
//     }

// }

// private struct JobFlags {
//     var bits: UInt32 = 0

//     var priority: UInt32 {
//         (bits & 0xFF00) >> 8
//     }
// }
// #endif

// #if compiler(>=5.5)

// /// Singleton type responsible for integrating JavaScript event loop as a Swift concurrency executor, conforming to
// /// `SerialExecutor` protocol from the standard library. To utilize it:
// ///
// /// 1. Make sure that your target depends on `JavaScriptEventLoop` in your `Packages.swift`:
// ///
// /// ```swift
// /// .target(
// ///    name: "JavaScriptKitExample",
// ///    dependencies: [
// ///        "JavaScriptKit",
// ///        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit")
// ///    ]
// /// )
// /// ```
// ///
// /// 2. Add an explicit import in the code that executes **before* you start using `await` and/or `Task`
// /// APIs (most likely in `main.swift`):
// ///
// /// ```swift
// /// import JavaScriptEventLoop
// /// ```
// ///
// /// 3. Run this function **before* you start using `await` and/or `Task` APIs (again, most likely in
// /// `main.swift`):
// ///
// /// ```swift
// /// JavaScriptEventLoop.installGlobalExecutor()
// /// ```
// @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
// public final class EventLoop: SerialExecutor, @unchecked Sendable {

//     /// A function that queues a given closure as a microtask into JavaScript event loop.
//     /// See also: https://developer.mozilla.org/en-US/docs/Web/API/HTML_DOM_API/Microtask_guide
//     public var queueMicrotask: (UnownedJob) -> Void
//     /// A function that invokes a given closure after a specified number of milliseconds.
//     public var setTimeout: (Double, UnownedJob) -> Void

//     /// A mutable state to manage internal job queue
//     /// Note that this should be guarded atomically when supporting multi-threaded environment.
//     var queueState = QueueState()

//     private init(
//         queueTask: @escaping (UnownedJob) -> Void,
//         setTimeout: @escaping (Double, UnownedJob) -> Void
//     ) {
//         self.queueMicrotask = queueTask
//         self.setTimeout = setTimeout
//     }

//     /// A per-thread singleton instance of the Executor
//     public static var shared: EventLoop {
//         return _shared
//     }

//     #if compiler(>=6.1) && _runtime(_multithreaded)
//     // In multi-threaded environment, we have an event loop executor per
//     // thread (per Web Worker). A job enqueued in one thread should be
//     // executed in the same thread under this global executor.
//     private static var _shared: EventLoop {
//         if let tls = swjs_thread_local_event_loop {
//             let eventLoop = Unmanaged<EventLoop>.fromOpaque(tls).takeUnretainedValue()
//             return eventLoop
//         }
//         let eventLoop = create()
//         swjs_thread_local_event_loop = Unmanaged.passRetained(eventLoop).toOpaque()
//         return eventLoop
//     }
//     #else
//     private static let _shared: JavaScriptEventLoop = create()
//     #endif

//     private static func create() -> EventLoop {
//         let eventLoop = EventLoop(
//             queueTask: { job in
//                 EventLoop.shared.insertJobQueue(job: job)
//             },
//             setTimeout: { delayMs, job in
//                 let fd = swift_timerfd_create()
//                 guard fd >= 0 else {
//                     EventLoop.shared.insertJobQueue(job: job)
//                     return
//                 }

//                 guard swift_timerfd_settime(fd, Int64(delayMs)) == 0 else {
//                     close(fd)
//                     EventLoop.shared.insertJobQueue(job: job)
//                     return
//                 }

//                 TimerQueue.shared.register(fd: fd, job: job)
//             }
//         )
//         return eventLoop
//     }

//     private nonisolated(unsafe) static var didInstallGlobalExecutor = false

//     /// Set JavaScript event loop based executor to be the global executor
//     /// Note that this should be called before any of the jobs are created.
//     /// This installation step will be unnecessary after custom executor are
//     /// introduced officially. See also [a draft proposal for custom
//     /// executors](https://github.com/rjmccall/swift-evolution/blob/custom-executors/proposals/0000-custom-executors.md#the-default-global-concurrent-executor)
//     public static func installGlobalExecutor() {
//         Self.installGlobalExecutorIsolated()
//     }

//     private static func installGlobalExecutorIsolated() {
//         guard !didInstallGlobalExecutor else { return }
//         didInstallGlobalExecutor = true
//         #if compiler(>=6.2)
//         if #available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999, *) {
//             // For Swift 6.2 and above, we can use the new `ExecutorFactory` API
//             _Concurrency._createExecutors(factory: JavaScriptEventLoop.self)
//         }
//         #else
//         // For Swift 6.1 and below, we need to install the global executor by hook API
//         installByLegacyHook()
//         #endif
//     }

//     internal func enqueue(_ job: UnownedJob, withDelay milliseconds: Double) {
//         setTimeout(
//             milliseconds,
//             job
//         )
//     }

//     internal func unsafeEnqueue(_ job: UnownedJob) {
//         #if canImport(wasi_pthread) && compiler(>=6.1) && _runtime(_multithreaded)
//         guard swjs_get_worker_thread_id_cached() == SWJS_MAIN_THREAD_ID else {
//             // Notify the main thread to execute the job when a job is
//             // enqueued from a Web Worker thread but without an executor preference.
//             // This is usually the case when hopping back to the main thread
//             // at the end of a task.
//             let jobBitPattern = unsafeBitCast(job, to: UInt.self)
//             swjs_send_job_to_main_thread(jobBitPattern)
//             return
//         }
//         // If the current thread is the main thread, do nothing special.
//         #endif
//         insertJobQueue(job: job)
//     }

//     #if compiler(>=5.9)
//     @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
//     public func enqueue(_ job: consuming ExecutorJob) {
//         // NOTE: Converting a `ExecutorJob` to an ``UnownedJob`` and invoking
//         // ``UnownedJob/runSynchronously(_:)` on it multiple times is undefined behavior.
//         unsafeEnqueue(UnownedJob(job))
//     }
//     #else
//     public func enqueue(_ job: UnownedJob) {
//         unsafeEnqueue(job)
//     }
//     #endif

//     public func asUnownedSerialExecutor() -> UnownedSerialExecutor {
//         return UnownedSerialExecutor(ordinary: self)
//     }
// }
// #endif // compiler(>=5.5)


// #if compiler(>=6.2)

// // MARK: - MainExecutor Implementation
// // MainExecutor is used by the main actor to execute tasks on the main thread
// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999, *)
// extension EventLoop: MainExecutor {
//     public func run() throws {
//         // This method is called from `swift_task_asyncMainDrainQueueImpl`.
//         // https://github.com/swiftlang/swift/blob/swift-DEVELOPMENT-SNAPSHOT-2025-04-12-a/stdlib/public/Concurrency/ExecutorImpl.swift#L28
//         // Yield control to the JavaScript event loop to skip the `exit(0)`
//         // call by `swift_task_asyncMainDrainQueueImpl`.
//         swjs_unsafe_event_loop_yield()
//     }
//     public func stop() {}
// }

// @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
// extension EventLoop: TaskExecutor {}

// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999, *)
// extension EventLoop: SchedulableExecutor {
//     public func enqueue<C: Clock>(
//         _ job: consuming ExecutorJob,
//         after delay: C.Duration,
//         tolerance: C.Duration?,
//         clock: C
//     ) {
//         let milliseconds = Self.delayInMilliseconds(from: delay, clock: clock)
//         self.enqueue(
//             UnownedJob(job),
//             withDelay: milliseconds
//         )
//     }

//     private static func delayInMilliseconds<C: Clock>(from duration: C.Duration, clock: C) -> Double {
//         let swiftDuration = clock.convert(from: duration)!
//         let (seconds, attoseconds) = swiftDuration.components
//         return Double(seconds) * 1_000 + (Double(attoseconds) / 1_000_000_000_000_000)
//     }
// }

// // MARK: - ExecutorFactory Implementation
// @available(macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999, *)
// extension EventLoop: ExecutorFactory {
//     // Forward all operations to the current thread's JavaScriptEventLoop instance
//     final class CurrentThread: TaskExecutor, SchedulableExecutor, MainExecutor, SerialExecutor {
//         func checkIsolated() {}

//         func enqueue(_ job: consuming ExecutorJob) {
//             JavaScriptEventLoop.shared.enqueue(job)
//         }

//         func enqueue<C: Clock>(
//             _ job: consuming ExecutorJob,
//             after delay: C.Duration,
//             tolerance: C.Duration?,
//             clock: C
//         ) {
//             JavaScriptEventLoop.shared.enqueue(
//                 job,
//                 after: delay,
//                 tolerance: tolerance,
//                 clock: clock
//             )
//         }
//         func run() throws {
//             try JavaScriptEventLoop.shared.run()
//         }
//         func stop() {
//             JavaScriptEventLoop.shared.stop()
//         }
//     }

//     public static var mainExecutor: any MainExecutor {
//         CurrentThread()
//     }

//     public static var defaultExecutor: any TaskExecutor {
//         CurrentThread()
//     }
// }

// #endif  // compiler(>=6.2)

// @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
// extension EventLoop {

//     static func installByLegacyHook() {
//         #if compiler(>=5.9)
//         typealias swift_task_asyncMainDrainQueue_hook_Fn = @convention(thin) (
//             swift_task_asyncMainDrainQueue_original, swift_task_asyncMainDrainQueue_override
//         ) -> Void
//         let swift_task_asyncMainDrainQueue_hook_impl: swift_task_asyncMainDrainQueue_hook_Fn = { _, _ in
//             swjs_unsafe_event_loop_yield()
//         }
//         swift_task_asyncMainDrainQueue_hook = unsafeBitCast(
//             swift_task_asyncMainDrainQueue_hook_impl,
//             to: UnsafeMutableRawPointer?.self
//         )
//         #endif

//         typealias swift_task_enqueueGlobal_hook_Fn = @convention(thin) (UnownedJob, swift_task_enqueueGlobal_original)
//             -> Void
//         let swift_task_enqueueGlobal_hook_impl: swift_task_enqueueGlobal_hook_Fn = { job, original in
//             EventLoop.shared.unsafeEnqueue(job)
//         }
//         swift_task_enqueueGlobal_hook = unsafeBitCast(
//             swift_task_enqueueGlobal_hook_impl,
//             to: UnsafeMutableRawPointer?.self
//         )

//         typealias swift_task_enqueueGlobalWithDelay_hook_Fn = @convention(thin) (
//             UInt64, UnownedJob, swift_task_enqueueGlobalWithDelay_original
//         ) -> Void
//         let swift_task_enqueueGlobalWithDelay_hook_impl: swift_task_enqueueGlobalWithDelay_hook_Fn = {
//             nanoseconds,
//             job,
//             original in
//             let milliseconds = Double(nanoseconds / 1_000_000)
//             EventLoop.shared.enqueue(job, withDelay: milliseconds)
//         }
//         swift_task_enqueueGlobalWithDelay_hook = unsafeBitCast(
//             swift_task_enqueueGlobalWithDelay_hook_impl,
//             to: UnsafeMutableRawPointer?.self
//         )

//         #if compiler(>=5.7)
//         typealias swift_task_enqueueGlobalWithDeadline_hook_Fn = @convention(thin) (
//             Int64, Int64, Int64, Int64, Int32, UnownedJob, swift_task_enqueueGlobalWithDelay_original
//         ) -> Void
//         let swift_task_enqueueGlobalWithDeadline_hook_impl: swift_task_enqueueGlobalWithDeadline_hook_Fn = {
//             sec,
//             nsec,
//             tsec,
//             tnsec,
//             clock,
//             job,
//             original in
//             EventLoop.shared.enqueue(job, withDelay: sec, nsec, tsec, tnsec, clock)
//         }
//         swift_task_enqueueGlobalWithDeadline_hook = unsafeBitCast(
//             swift_task_enqueueGlobalWithDeadline_hook_impl,
//             to: UnsafeMutableRawPointer?.self
//         )
//         #endif

//         typealias swift_task_enqueueMainExecutor_hook_Fn = @convention(thin) (
//             UnownedJob, swift_task_enqueueMainExecutor_original
//         ) -> Void
//         let swift_task_enqueueMainExecutor_hook_impl: swift_task_enqueueMainExecutor_hook_Fn = { job, original in
//             EventLoop.shared.unsafeEnqueue(job)
//         }
//         swift_task_enqueueMainExecutor_hook = unsafeBitCast(
//             swift_task_enqueueMainExecutor_hook_impl,
//             to: UnsafeMutableRawPointer?.self
//         )

//     }
// }

// #if compiler(>=5.7)
// /// Taken from https://github.com/apple/swift/blob/d375c972f12128ec6055ed5f5337bfcae3ec67d8/stdlib/public/Concurrency/Clock.swift#L84-L88
// @_silgen_name("swift_get_time")
// internal func swift_get_time(
//     _ seconds: UnsafeMutablePointer<Int64>,
//     _ nanoseconds: UnsafeMutablePointer<Int64>,
//     _ clock: CInt
// )

// @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
// extension EventLoop {
//     fileprivate func enqueue(
//         _ job: UnownedJob,
//         withDelay seconds: Int64,
//         _ nanoseconds: Int64,
//         _ toleranceSec: Int64,
//         _ toleranceNSec: Int64,
//         _ clock: Int32
//     ) {
//         var nowSec: Int64 = 0
//         var nowNSec: Int64 = 0
//         swift_get_time(&nowSec, &nowNSec, clock)
//         let delayMilliseconds = (seconds - nowSec) * 1_000 + (nanoseconds - nowNSec) / 1_000_000
//         enqueue(job, withDelay: delayMilliseconds <= 0 ? 0 : Double(delayMilliseconds))
//     }
// }
// #endif

// // FIXME: Actually implement
// fileprivate func swjs_unsafe_event_loop_yield() {}






@_extern(c, "epoll_create1")
func epoll_create1(_ flags: Int32) -> Int32

@_extern(c, "epoll_ctl")
func epoll_ctl(_ epfd: Int32, _ op: Int32, _ fd: Int32, _ event: UnsafeMutablePointer<Int>) -> Int32

@_extern(c, "epoll_wait")
func epoll_wait(_ epfd: Int32, _ events: UnsafeMutablePointer<Int>, _ maxevents: Int32, _ timeout: Int32) -> Int32

@_extern(c, "eventfd")
func eventfd(_ initval: UInt32, _ flags: Int32) -> Int32

@_extern(c, "read")
func read(_ fd: Int32, _ buf: UnsafeMutableRawPointer, _ count: Int) -> Int

@_extern(c, "write")
func write(_ fd: Int32, _ buf: UnsafeRawPointer, _ count: Int) -> Int

@_extern(c, "close")
func close(_ fd: Int32) -> Int32

@_extern(c, "timerfd_create")
func timerfd_create(_ clockid: Int32, _ flags: Int32) -> Int32

@_extern(c, "timerfd_settime")
func timerfd_settime(_ fd: Int32, _ flags: Int32, _ new_value: UnsafePointer<Int>, _ old_value: UnsafeMutablePointer<Int>?) -> Int32


public struct timespec {
    public var tv_sec: Int64
    public var tv_nsec: Int64
    public init(tv_sec: Int64, tv_nsec: Int64) {
        self.tv_sec = tv_sec
        self.tv_nsec = tv_nsec
    }
}

public struct itimerspec {
    public var it_interval: timespec
    public var it_value: timespec
    public init(it_interval: timespec, it_value: timespec) {
        self.it_interval = it_interval
        self.it_value = it_value
    }
}

public struct epoll_event {
    public var events: UInt32
    public var data: UInt64
    public init(events: UInt32 = 0, data: UInt64 = 0) {
        self.events = events
        self.data = data
    }
}

let EPOLL_CTL_ADD: Int32 = 1
let EPOLLIN: UInt32 = 0x001
let CLOCK_MONOTONIC: Int32 = 1


final class LinuxEventLoop {
    init() {
    }

    func enqueue(_ job: UnownedJob) {
        fatalError("Not implemented")
    }

    func enqueue<C: Clock>(
        _ job: consuming ExecutorJob,
        after delay: C.Duration,
        tolerance: C.Duration?,
        clock: C
    ) {
        fatalError("Not implemented")
    }

    func run() {
        fatalError("Not implemented")
    }
}




#endif // hasFeature(Embedded)
