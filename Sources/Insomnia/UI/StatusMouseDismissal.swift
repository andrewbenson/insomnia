import CoreGraphics

enum StatusMouseDismissal {
    static func shouldDismiss(isOwnWindow: Bool, location: CGPoint, statusFrame: CGRect?) -> Bool {
        !isOwnWindow && !(statusFrame?.contains(location) ?? false)
    }
}
