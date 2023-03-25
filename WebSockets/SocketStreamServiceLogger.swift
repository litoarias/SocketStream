import Foundation

typealias WebSocketLogger = SocketStreamServiceLogger

struct SocketStreamServiceLogger {
    static var url: URL?
    
    static func log(_ text: String, level: ErrorLevel = .error) {
        let mytime = Date()
        let format = DateFormatter()
        format.dateFormat = "HH:mm:ss"
        debugPrint(NSString(string: "🚀 SOCKET STREAM - \(format.string(from: mytime)) - (\(url?.absoluteString ?? "Empty url")): \n    \(level.rawValue) \(text)"))
    }
    
    static func log(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            log(((String(data: data, encoding: .utf8) ?? "Empty") as String), level: .messageReceived)
        case .string(let string):
            log(string, level: .messageReceived)
        @unknown default:
            break
        }
    }
    
    enum ErrorLevel: String {
        case info = "⚠️:"
        case messageReceived = "💬-⬅️:"
        case messageSended = "💬-➡️:"
        case error = "🚫:"
    }
}
