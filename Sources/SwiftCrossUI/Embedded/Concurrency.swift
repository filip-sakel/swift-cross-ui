import _EmbdeddedShims

#if hasFeature(Embedded)

// Extract from Swift's stdlib's Concurrency module

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public typealias TimeInterval = Double

import _Concurrency

// MARK: - Task

// extension Task where Success == Never, Failure == Never {
//   /// Suspends the current task for the specified duration.
//   ///
//   /// This function does not block the underlying thread.
//   static func _sleep(
//     until deadline: ContinuousClock.Instant,
//     tolerance: Swift.Duration?,
//     clock: ContinuousClock
//   ) async throws {
//     let deadline = deadline._value
//     let tolerance = tolerance.map { $0._value }
//     try await Task._sleep(until: deadline, tolerance: tolerance)
//   }
// }

// MARK: - ContinuousClock

public struct ContinuousClock: Sendable {
  /// A continuous point in time used for `ContinuousClock`.
  public struct Instant: Sendable {
    internal var _value: Swift.Duration

    internal init(_value: Swift.Duration) {
      self._value = _value
    }
  }

  public init() { }
}

fileprivate func _getTime(
  seconds: UnsafeMutablePointer<Int64>,
  nanoseconds: UnsafeMutablePointer<Int64>,
  clock: Int32
) -> Void {
  fatalError()
  // _EmbdeddedShims.swift_get_time(seconds, nanoseconds, unsafeBitCast(clock, to: swift_clock_id.self))
}

fileprivate func _getClockRes(
  seconds: UnsafeMutablePointer<Int64>,
  nanoseconds: UnsafeMutablePointer<Int64>,
  clock: CInt) {
    fatalError()
  // _EmbdeddedShims.swift_get_clock_res(seconds, nanoseconds, unsafeBitCast(clock, to: swift_clock_id.self))
}

enum _ClockID: Int32 {
  case continuous = 1
  case suspending = 2
}

extension Duration {
  internal init(_seconds s: Int64, nanoseconds n: Int64) {
    let (secHi, secLo) = s.multipliedFullWidth(by: 1_000_000_000_000_000_000)
    // _nanoseconds is in 0 ..< 1_000_000_000, so the conversion to UInt64
    // and multiply cannot overflow. If you somehow trap here, it is because
    // the underlying clock hook that produced the time value is implemented
    // incorrectly on your platform, but because we trap we can't silently
    // get bogus data.
    let (low, carry) = secLo.addingReportingOverflow(UInt64(n) * 1_000_000_000)
    let high = secHi &+ (carry ? 1 : 0)
    self.init(_high: high, low: low)
  }
}

extension ContinuousClock: Clock {
  public var minimumResolution: Duration {
      var seconds = Int64(0)
      var nanoseconds = Int64(0)
      _getClockRes(
        seconds: &seconds,
        nanoseconds: &nanoseconds,
        clock: _ClockID.continuous.rawValue)
      return Duration(_seconds: seconds, nanoseconds: nanoseconds)
  }

  /// The current continuous instant.
  public var now: ContinuousClock.Instant {
    ContinuousClock.now
  }

  // /// The minimum non-zero resolution between any two calls to `now`.
  // public var minimumResolution: Swift.Duration {
  //   var seconds = Int64(0)
  //   var nanoseconds = Int64(0)
  //   unsafe _getClockRes(
  //     seconds: &seconds,
  //     nanoseconds: &nanoseconds,
  //     clock: _ClockID.continuous.rawValue)
  //   return Duration(_seconds: seconds, nanoseconds: nanoseconds)
  // }

  /// The current continuous instant.
  public static var now: ContinuousClock.Instant {
    var seconds = Int64(0)
    var nanoseconds = Int64(0)
    _getTime(
      seconds: &seconds,
      nanoseconds: &nanoseconds,
      clock: _ClockID.continuous.rawValue)
    return Instant(
      _value: Duration(_seconds: seconds, nanoseconds: nanoseconds)
    )
  }


  /// Suspend task execution until a given deadline within a tolerance.
  /// If no tolerance is specified then the system may adjust the deadline
  /// to coalesce CPU wake-ups to more efficiently process the wake-ups in
  /// a more power efficient manner.
  ///
  /// If the task is canceled before the time ends, this function throws
  /// `CancellationError`.
  ///
  /// This function doesn't block the underlying thread.
  public func sleep(
    until deadline: Instant, tolerance: Swift.Duration? = nil
  ) async throws {
    // try await Task._sleep(until: deadline,
    //                         tolerance: tolerance,
    //                         clock: self)
  }
}

extension ContinuousClock.Instant: InstantProtocol {
  public static var now: ContinuousClock.Instant { ContinuousClock.now }

  public func advanced(by duration: Swift.Duration) -> ContinuousClock.Instant {
    return ContinuousClock.Instant(_value: _value + duration)
  }

  public func duration(to other: ContinuousClock.Instant) -> Swift.Duration {
    other._value - _value
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(_value)
  }

  public static func == (
    _ lhs: ContinuousClock.Instant, _ rhs: ContinuousClock.Instant
  ) -> Bool {
    return lhs._value == rhs._value
  }

  public static func < (
    _ lhs: ContinuousClock.Instant, _ rhs: ContinuousClock.Instant
  ) -> Bool {
    return lhs._value < rhs._value
  }

  @_alwaysEmitIntoClient
  @inlinable
  public static func + (
    _ lhs: ContinuousClock.Instant, _ rhs: Swift.Duration
  ) -> ContinuousClock.Instant {
    lhs.advanced(by: rhs)
  }

  @_alwaysEmitIntoClient
  @inlinable
  public static func += (
    _ lhs: inout ContinuousClock.Instant, _ rhs: Swift.Duration
  ) {
    lhs = lhs.advanced(by: rhs)
  }

  @_alwaysEmitIntoClient
  @inlinable
  public static func - (
    _ lhs: ContinuousClock.Instant, _ rhs: Swift.Duration
  ) -> ContinuousClock.Instant {
    lhs.advanced(by: .zero - rhs)
  }

  @_alwaysEmitIntoClient
  @inlinable
  public static func -= (
    _ lhs: inout ContinuousClock.Instant, _ rhs: Swift.Duration
  ) {
    lhs = lhs.advanced(by: .zero - rhs)
  }

  @_alwaysEmitIntoClient
  @inlinable
  public static func - (
    _ lhs: ContinuousClock.Instant, _ rhs: ContinuousClock.Instant
  ) -> Swift.Duration {
    rhs.duration(to: lhs)
  }
}


#endif // hasFeature(Embedded)