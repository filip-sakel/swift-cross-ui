// Extracted from swift-numerics/NumericsShims/NumericsShims.h

// #include <stdint.h>
#define HEADER_SHIM static inline __attribute__((__always_inline__))

// This header uses most of the libm functions, but we don't want to end up
// exporting the libm declarations to modules that include NumericsShims, so
// we don't want to actually #include <math.h>.
//
// For most of the functions, we can get around this by using __builtin_func
// instead of func, since the compiler knows about these operations, but for
// the non-standard extensions, we need to include our own declarations. This
// is a little bit risky, in that we might end up missing an attribute that
// gets added and effects calling conventions, etc, but that's expected to be
// exceedingly rare.
//
// Still, we'll eventually want to find a better solution to this problem,
// especially if people start using this package on systems that are not
// Darwin or Ubuntu.

// MARK: - math functions for float
HEADER_SHIM float libm_cosf(float x) {
  return __builtin_cosf(x);
}

HEADER_SHIM float libm_sinf(float x) {
  return __builtin_sinf(x);
}

// MARK: - math functions for double

HEADER_SHIM double libm_cos(double x) {
  return __builtin_cos(x);
}

HEADER_SHIM double libm_sin(double x) {
  return __builtin_sin(x);
}


// Extracted from Swift stdlib Concurrency cpp clock files

// typedef enum swift_clock_id {
//   swift_clock_id_continuous = 1,
//   swift_clock_id_suspending = 2
// } swift_clock_id;


// #include <time.h>
// #if defined(_WIN32)
// #define WIN32_LEAN_AND_MEAN
// #define NOMINMAX
// #include <Windows.h>
// #include <realtimeapiset.h>
// #endif
// // #include <bits/time.h>
// // #include <bits/time.h>
// #ifndef __itimerspec_defined
// #include <linux/time.h>
// #endif
// #include <stdint.h>


// void swift_get_time(
//   long long *seconds,
//   long long *nanoseconds,
//   swift_clock_id clock_id) {
//       #warning("Enable for Embedded")
//       // TODO: Enable
// //   struct timespec continuous;

// #if defined(__linux__)
//       // TODO: Enable
//       // clock_gettime(CLOCK_BOOTTIME, &continuous);
// #elif defined(__APPLE__)
//       clock_gettime(CLOCK_MONOTONIC_RAW, &continuous);
// #elif (defined(__OpenBSD__) || defined(__FreeBSD__) || defined(__wasi__))
//       clock_gettime(CLOCK_MONOTONIC, &continuous);
// #elif defined(_WIN32)
//       // This needs to match what swift-corelibs-libdispatch does

//       // QueryInterruptTimePrecise() outputs a value measured in 100ns
//       // units. We must divide the output by 10,000,000 to get a value in
//       // seconds and multiply the remainder by 100 to get nanoseconds.
//       ULONGLONG interruptTime;
//       (void)QueryInterruptTimePrecise(&interruptTime);
//       continuous.tv_sec = interruptTime / 10'000'000;
//       continuous.tv_nsec = (interruptTime % 10'000'000) * 100;
// #elif WE_HAVE_STD_CHRONO
//       auto now = std::chrono::steady_clock::now();
//       auto epoch = std::chrono::steady_clock::min();
//       auto timeSinceEpoch = now - epoch;
//       auto sec = std::chrono::duration_cast<std::chrono::seconds>(timeSinceEpoch);
//       auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(timeSinceEpoch - sec);
//       continuous.tv_sec = sec;
//       continuous.tv_nsec = ns;
// #else
// #error Missing platform continuous time definition
// #endif
//       // TODO: Enable
// //     *seconds = continuous.tv_sec;
// //     *nanoseconds = continuous.tv_nsec;
//     return;
// }
// void swift_get_clock_res(
//   long long *seconds,
//   long long *nanoseconds,
//   swift_clock_id clock_id) {
//       #warning("Enable for Embedded")
//       // TODO: Enable
// switch (clock_id) {
//     case swift_clock_id_continuous: {
//       // struct timespec continuous;
// #if defined(__linux__)
//       // clock_getres(CLOCK_BOOTTIME, &continuous);
// #elif defined(__APPLE__)
//       clock_getres(CLOCK_MONOTONIC_RAW, &continuous);
// #elif (defined(__OpenBSD__) || defined(__FreeBSD__) || defined(__wasi__))
//       clock_getres(CLOCK_MONOTONIC, &continuous);
// #elif defined(_WIN32)
//       continuous.tv_sec = 0;
//       continuous.tv_nsec = 100;
// #elif WE_HAVE_STD_CHRONO
//       auto num = std::chrono::steady_clock::period::num;
//       auto den = std::chrono::steady_clock::period::den;
//       continuous.tv_sec = num / den;
//       continuous.tv_nsec = (num * 1000000000ll) % den
// #else
// #error Missing platform continuous time definition
// #endif
//       // *seconds = continuous.tv_sec;
//       // *nanoseconds = continuous.tv_nsec;
//       return;
//     }
//     case swift_clock_id_suspending: {
//       // struct timespec suspending;
// #if defined(__linux__)
//       // clock_getres(CLOCK_MONOTONIC_RAW, &suspending);
// #elif defined(__APPLE__)
//       clock_getres(CLOCK_UPTIME_RAW, &suspending);
// #elif defined(__wasi__)
//       clock_getres(CLOCK_MONOTONIC, &suspending);
// #elif (defined(__OpenBSD__) || defined(__FreeBSD__))
//       clock_getres(CLOCK_UPTIME, &suspending);
// #elif defined(_WIN32)
//       suspending.tv_sec = 0;
//       suspending.tv_nsec = 100;
// #elif WE_HAVE_STD_CHRONO
//       auto num = std::chrono::steady_clock::period::num;
//       auto den = std::chrono::steady_clock::period::den;
//       continuous.tv_sec = num / den;
//       continuous.tv_nsec = (num * 1'000'000'000ll) % den
// #else
// #error Missing platform suspending time definition
// #endif
//       // *seconds = suspending.tv_sec;
//       // *nanoseconds = suspending.tv_nsec;
//       return;
//     }
//   }
//   return;
// }

// Extracted from JavaScriptKit/_CJavaScriptEventLoop.h

// #define SWIFT_CC(CC) SWIFT_CC_##CC
// #define SWIFT_CC_swift __attribute__((swiftcall))

// #define SWIFT_EXPORT_FROM(LIBRARY) __attribute__((__visibility__("default")))

// #define SWIFT_NONISOLATED_UNSAFE __attribute__((swift_attr("nonisolated(unsafe)")))

// typedef unsigned int uint32_t;
// typedef int int32_t;
// typedef long long int64_t;
// typedef unsigned long long uint64_t;

// /// A schedulable unit
// /// Note that this type layout is a part of public ABI, so we expect this field layout won't break in the future versions.
// /// Current implementation refers the `swift-5.5-RELEASE` implementation.
// /// https://github.com/apple/swift/blob/swift-5.5-RELEASE/include/swift/ABI/Task.h#L43-L129
// /// This definition is used to retrieve priority value of a job. After custom-executor API will be introduced officially,
// /// the job priority API will be provided in the Swift world.
// typedef __attribute__((aligned(2 * _Alignof(void *)))) struct {
//     void *_Nonnull Metadata;
//     int32_t RefCounts;
//     void *_Nullable SchedulerPrivate[2];
//     uint32_t Flags;
// } Job;

// /// A hook to take over global enqueuing.
// typedef SWIFT_CC(swift) void (*swift_task_enqueueGlobal_original)(
//     Job *_Nonnull job);

// SWIFT_EXPORT_FROM(swift_Concurrency)
// extern void *_Nullable swift_task_enqueueGlobal_hook SWIFT_NONISOLATED_UNSAFE;

// /// A hook to take over global enqueuing with delay.
// typedef SWIFT_CC(swift) void (*swift_task_enqueueGlobalWithDelay_original)(
//     unsigned long long delay, Job *_Nonnull job);
// SWIFT_EXPORT_FROM(swift_Concurrency)
// extern void *_Nullable swift_task_enqueueGlobalWithDelay_hook SWIFT_NONISOLATED_UNSAFE;

// typedef SWIFT_CC(swift) void (*swift_task_enqueueGlobalWithDeadline_original)(
//     long long sec,
//     long long nsec,
//     long long tsec,
//     long long tnsec,
//     int clock, Job *_Nonnull job);
// SWIFT_EXPORT_FROM(swift_Concurrency)
// extern void *_Nullable swift_task_enqueueGlobalWithDeadline_hook SWIFT_NONISOLATED_UNSAFE;

// /// A hook to take over main executor enqueueing.
// typedef SWIFT_CC(swift) void (*swift_task_enqueueMainExecutor_original)(
//     Job *_Nonnull job);
// SWIFT_EXPORT_FROM(swift_Concurrency)
// extern void *_Nullable swift_task_enqueueMainExecutor_hook SWIFT_NONISOLATED_UNSAFE;

// /// A hook to override the entrypoint to the main runloop used to drive the
// /// concurrency runtime and drain the main queue. This function must not return.
// /// Note: If the hook is wrapping the original function and the `compatOverride`
// ///       is passed in, the `original` function pointer must be passed into the
// ///       compatibility override function as the original function.
// typedef SWIFT_CC(swift) void (*swift_task_asyncMainDrainQueue_original)();
// typedef SWIFT_CC(swift) void (*swift_task_asyncMainDrainQueue_override)(
//     swift_task_asyncMainDrainQueue_original _Nullable original);
// SWIFT_EXPORT_FROM(swift_Concurrency)
// extern void *_Nullable swift_task_asyncMainDrainQueue_hook SWIFT_NONISOLATED_UNSAFE;


// /// MARK: - thread local storage

// extern _Thread_local void * _Nullable swjs_thread_local_event_loop SWIFT_NONISOLATED_UNSAFE;

// extern _Thread_local void * _Nullable swjs_thread_local_task_executor_worker SWIFT_NONISOLATED_UNSAFE;

// #ifndef TIMER_FD_SHIMS_H
// #define TIMER_FD_SHIMS_H

// // #include <stdint.h>
// // #include <time.h>
// // #include <sys/timerfd.h>
// // #include <unistd.h>

// #ifdef __cplusplus
// extern "C" {
// #endif

// /// Create a timerfd using CLOCK_MONOTONIC and return its file descriptor.
// /// Returns -1 on failure.
// int swift_timerfd_create(void);

// /// Set the timerfd with a delay in milliseconds.
// /// Returns 0 on success, -1 on failure.
// int swift_timerfd_settime(int fd, int64_t delay_ms);

// /// Read and clear the timerfd. Returns the number of expirations.
// uint64_t swift_timerfd_read(int fd);

// #ifdef __cplusplus
// }
// #endif

// #endif /* TIMER_FD_SHIMS_H */

// // EpollShims.h

// #ifndef EPOLL_SHIMS_H
// #define EPOLL_SHIMS_H

// // #include <stdint.h>
// // #include <sys/epoll.h>

// #ifdef __cplusplus
// extern "C" {
// #endif

// struct epoll_event {
//     uint32_t events;  // Epoll events
//     uint64_t data;    // User data variable
// };


// /// Expose EPOLLIN to Swift
// #define SWIFT_EPOLLIN_VALUE EPOLLIN

// /// Create an epoll instance. Returns the epoll file descriptor, or -1 on failure.
// int swift_epoll_create(void);

// /// Register an fd with the epoll instance. Returns 0 on success, -1 on failure.
// int swift_epoll_ctl_add(int epoll_fd, int fd, uint32_t events);

// /// Wait for events. Returns the number of ready fds, or -1 on failure.
// int swift_epoll_wait(int epoll_fd, struct epoll_event *events, int max_events, int timeout_ms);

// #ifdef __cplusplus
// }
// #endif

// #endif /* EPOLL_SHIMS_H */

// int getpagesize() {
//       // FIXME: Enable
//       return 4096;
// };