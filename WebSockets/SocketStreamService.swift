import Foundation

typealias WebSocketStream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>

/**
 🚀 Usage of `SocketStreamService` instance, this wrapper uses a native way with `URLSessionWebSocketTask` and works as an asynchronous (async) functions into Swift, allowing us to run complex asynchronous code almost is if it were synchronous. You don't need to make logs, `SocketStreamService` will emit all necessary logs.
 
 - Note: `SocketStreamService` manage **ping-pong** issues automatically, the problem described below in the **warning** section.
 
 - Warning: 🏓 Ping Pongs:
 *The server may drop your connection due to inactivity if your app is not sending
 messages over WebSocket with "acceptable" frequency. The system uses particular
 ping-pong messages to solve this problem. You will need to send them periodically
 (approximately every 10 seconds). This ensures that the server won't kill the
 connection (using the webSocketTask.sendPing).*
 
 - Copyright: https://www.avanderlee.com/swift/asyncthrowingstream-asyncstream/
 https://appspector.com/blog/websockets-in-ios-using-urlsessionwebsockettask
 https://www.donnywals.com/iterating-over-web-socket-messages-with-async-await-in-swift/
 
 - Important: ✏️ Example of usage:
 
```
 // CONNECT
 let url = URL(string: "wss://socketsbay.com/wss/v2/1/demo/")!
 let stream = SocketStreamService(url: url)
 stream.onConnected = {
     // TODO: Save in keychain?
     debugPrint("Socket connection")
 }
 
 stream.onDisconnect = {
     // TODO: Remove from keychain?
     debugPrint("Socket disconnection")
 }
 
 // SEND MESSAGE
 Task {
    try await stream.send(text: "Test desde app ios")
 }
 
 // RECIVE MESSAGES
 Task {
     do {
         for try await message in stream {
         switch message {
         case .data(let data):
            debugPrint(String(data: data, encoding: .utf8) as Any)
         case .string(let string):
            debugPrint(string)
         @unknown default:
            fatalError()
         }
         }
      } catch {
         print("Error: \(error)")
      }
 }
 ```
 */
final class SocketStreamService: NSObject, AsyncSequence {
    typealias AsyncIterator = WebSocketStream.Iterator
    typealias Element = URLSessionWebSocketTask.Message

    private var continuation: WebSocketStream.Continuation?
    private var task: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let delegateQueue = OperationQueue()
    private var timer: DispatchSourceTimer?
    private var systemEvents: SocketStreamSystemEvents?
    private lazy var stream: WebSocketStream = {
        return WebSocketStream { continuation in
            self.continuation = continuation
            waitForNextValue()
        }
    }()
    
    var onConnected: (() -> Void)?
    var onDisconnect: (() -> Void)?
    
    init(url: URL) {
        super.init()
        systemEvents = SocketStreamSystemEvents(url: url)
        systemEvents?.delegate = self
        startStream(url: url)
    }
    
    deinit {
        Task {
            try await cancel()
        }
    }
    
    func makeAsyncIterator() -> AsyncIterator {
        return stream.makeAsyncIterator()
    }
    
    func cancel() async throws {
        task?.cancel(with: .goingAway, reason: nil)
        continuation?.finish()
    }
    
    func send(text: String) async throws {
        task?.send(URLSessionWebSocketTask.Message.string(text)) { [weak self] error in
            if let error = error {
                self?.continuation?.finish(throwing: error)
            } else {
                WebSocketLogger.log(text,level: .messageSended)
            }
        }
    }
    
    func send(data: Data) async throws {
        task?.send(URLSessionWebSocketTask.Message.data(data)) { [weak self] error in
            if let error = error {
                WebSocketLogger.log(error.localizedDescription)
                self?.continuation?.finish(throwing: error)
            } else {
                WebSocketLogger.log(
                    String(data: data, encoding: .utf8) ?? "Empty sended",
                    level: .messageSended
                )
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension SocketStreamService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onConnected?()
        schedulePing()
        WebSocketLogger.log("onConnected", level: .info)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onDisconnect?()
        stopPing()
        checkDisconnectionReason(closeCode: closeCode)
    }
}

// MARK: - SocketStreamSystemEventsProtocol

extension SocketStreamService: SocketStreamSystemEventsProtocol {
    func enterBackground() {
        Task {
            try await cancel()
        }
        WebSocketLogger.log("enterBackground", level: .info)
    }
    
    func enterForeground(url: URL) {
        startStream(url: url)
        WebSocketLogger.log("enterForeground \(url.absoluteString)", level: .info)
    }
}

// MARK: - Private Methods

fileprivate extension SocketStreamService {
    func startStream(url: URL) {
        WebSocketLogger.url = url
        urlSession = URLSession(configuration: .default,
                                delegate: self,
                                delegateQueue: delegateQueue)
        task = urlSession?.webSocketTask(with: url)
        task?.resume()
    }

    func waitForNextValue() {
        guard task?.closeCode == .invalid else {
            continuation?.finish()
            return
        }
        
        task?.receive(completionHandler: { [weak self] result in
            guard let continuation = self?.continuation else {
                return
            }
            
            do {
                let message = try result.get()
                continuation.yield(message)
                WebSocketLogger.log(message)
                self?.waitForNextValue()
            } catch {
                continuation.finish(throwing: error)
            }
        })
    }
    
    func schedulePing() {
        let queue = DispatchQueue(label: Bundle.main.bundleIdentifier ?? "com.example" + ".socket.ping.timer")
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: .seconds(5))
        timer?.setEventHandler { [weak self] in
            self?.startPing()
        }
        timer?.resume()
    }
    
    func stopPing() {
        timer?.cancel()
        timer = nil
    }
    
    func startPing() {
        task?.sendPing { [weak self] (error) in
            if let error = error {
                WebSocketLogger.log("sendPing: \(error.localizedDescription)")
                self?.continuation?.finish(throwing: error)
            } else {
                WebSocketLogger.log("sendPing", level: .messageSended)
            }
        }
    }
    
    func checkDisconnectionReason(closeCode: URLSessionWebSocketTask.CloseCode) {
        switch closeCode {
        case .goingAway:
            WebSocketLogger.log("Disconnect Normal disconnection", level: .info)
        case .invalid:
            WebSocketLogger.log("Disconnect invalid")
        case .normalClosure:
            WebSocketLogger.log("Disconnect normalClosure")
        case .protocolError:
            WebSocketLogger.log("Disconnect protocolError")
        case .unsupportedData:
            WebSocketLogger.log("Disconnect unsupportedData")
        case .noStatusReceived:
            WebSocketLogger.log("Disconnect noStatusReceived")
        case .abnormalClosure:
            WebSocketLogger.log("Disconnect abnormalClosure")
        case .invalidFramePayloadData:
            WebSocketLogger.log("Disconnect invalidFramePayloadData")
        case .policyViolation:
            WebSocketLogger.log("Disconnect policyViolation")
        case .messageTooBig:
            WebSocketLogger.log("Disconnect mandatoryExtensionMissing")
        case .mandatoryExtensionMissing:
            WebSocketLogger.log("Disconnect mandatoryExtensionMissing")
        case .internalServerError:
            WebSocketLogger.log("Disconnect internalServerError")
        case .tlsHandshakeFailure:
            WebSocketLogger.log("Disconnect tlsHandshakeFailure")
        @unknown default:
            WebSocketLogger.log("Unknown socket disconnection")
        }
    }
}
