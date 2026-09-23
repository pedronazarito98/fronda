import Foundation

@objc public protocol CoordinatorProtocol {
    func handle(_ request: Data, reply: @escaping @Sendable (Data) -> Void)
}
