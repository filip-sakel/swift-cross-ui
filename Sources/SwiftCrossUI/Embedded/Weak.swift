// final class WeakBox<T: AnyObject> {
//     weak var value: T?
//     init(value: T) {
//         self.value = value
//     }
// }

// public struct Weak<T: AnyObject> {
//     private let box: WeakBox<T>

//     public init(_ value: borrowing T) {
//         self.box = WeakBox(value: value)
//     }

//     public var value: T? {
//         return box.value
//     }
// }
