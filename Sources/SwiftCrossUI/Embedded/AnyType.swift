// TODO: Should be ~Copyable when we get non-copyable dictionaries.
@usableFromInline
final class _UnsafeAnyType {
    @usableFromInline
    let _pointer: UnsafeMutableRawPointer

    @usableFromInline
    let _deinit: (UnsafeMutableRawPointer) -> Void

    private init(_ pointer: UnsafeMutableRawPointer, deinit _deinit: @escaping (UnsafeMutableRawPointer) -> Void) {
        self._pointer = pointer
        self._deinit = _deinit
    }

    @usableFromInline
    convenience init<T: ~Copyable>(_ value: consuming T) {
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        ptr.initialize(to: value)
        self.init(ptr, deinit: { $0.bindMemory(to: T.self, capacity: 1).deinitialize(count: 1) })
    }

    @usableFromInline
    subscript<T: ~Copyable>(type: T.Type) -> T {
        _read {
            yield _pointer.bindMemory(to: T.self, capacity: 1).pointee
        }
        _modify {
            yield &_pointer.bindMemory(to: T.self, capacity: 1).pointee
        }
    }

    deinit {
        _deinit(_pointer)
        _pointer.deallocate()
    }
}