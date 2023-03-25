import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // DEMO: https://socketsbay.com/test-websockets
       
        // CONNECT
        let url = URL(string: "wss://socketsbay.com/wss/v2/1/demo/")!
        let stream = SocketStreamService(url: url)
        stream.onConnected = {
            debugPrint("Socket connection")
        }
        
        stream.onDisconnect = {
            debugPrint("Socket disconnection")
        }
        
        // DISCONNECT
        Task {
            try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            try await stream.cancel()
        }
        
        // SEND MESSAGE
        Task {
            do {
                try await stream.send(text: "Test from iOS app")
            } catch {
                print("Error: \(error)")
            }
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
        
        return true
    }
    
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
}
