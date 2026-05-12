import Foundation

enum ToastStyle: Equatable { case earn, threat }

struct ToastEvent: Equatable, Identifiable {
    let id = UUID()
    let message: String
    let style: ToastStyle

    static func == (lhs: ToastEvent, rhs: ToastEvent) -> Bool {
        lhs.id == rhs.id
    }
}
