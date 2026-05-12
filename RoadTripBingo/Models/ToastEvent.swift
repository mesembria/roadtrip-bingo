import Foundation

enum ToastStyle: Equatable { case earn, threat }

struct ToastEvent: Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}
