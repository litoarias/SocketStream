# SocketStreamService

## Iterating over web socket messages with async / await in Swift


🚀 Usage of `SocketStreamService` instance, this wrapper uses a native way with `URLSessionWebSocketTask` and works as an asynchronous (async) functions into Swift, allowing us to run complex asynchronous code almost is if it were synchronous. You don't need to make logs, `SocketStreamService` will emit all necessary logs.
 
 - Note: `SocketStreamService` manage **ping-pong** issues automatically, the problem described below in the **warning** section.
 
 - Warning: 

   🏓 Ping Pongs:
   *The server may drop your connection due to inactivity if your app is not sending
   messages over WebSocket with "acceptable" frequency. The system uses particular
   ping-pong messages to solve this problem. You will need to send them periodically
   (approximately every 10 seconds). This ensures that the server won't kill the
   connection (using the webSocketTask.sendPing).*
 
 - Copyright: 
 
      https://www.avanderlee.com/swift/asyncthrowingstream-asyncstream/
      https://appspector.com/blog/websockets-in-ios-using-urlsessionwebsockettask
      https://www.donnywals.com/iterating-over-web-socket-messages-with-async-await-in-swift/

      -------


 ✏️ Example of usage:
 
```swift
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