// TODO: Should be ~Copyable when we get non-copyable dictionaries.
@usableFromInline
struct _UnsafeAnyType {
    @usableFromInline
    let _pointer: UnsafeMutableRawPointer

    @_transparent
    @usableFromInline
    init<T: ~Copyable>(_ value: consuming T) {
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        ptr.initialize(to: value)
        self._pointer = UnsafeMutableRawPointer(ptr)
    }

    @usableFromInline
    subscript<T: ~Copyable>(type: T.Type) -> T {
        @_transparent
        _read {
            yield _pointer.bindMemory(to: T.self, capacity: 1).pointee
        }
        @_transparent
        _modify {
            yield &_pointer.bindMemory(to: T.self, capacity: 1).pointee
        }
    }

    @_transparent
    @usableFromInline
    consuming func destroy<T: ~Copyable>(_ type: T.Type) {
        _pointer.bindMemory(to: T.self, capacity: 1).deinitialize(count: 1)
        _pointer.deallocate()
    }
}