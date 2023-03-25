import UIKit

protocol SocketStreamSystemEventsProtocol {
    func enterBackground()
    func enterForeground(url: URL)
}

final class SocketStreamSystemEvents: NSObject {
    var delegate: SocketStreamSystemEventsProtocol?
    private var url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
        listenEnterForeground()
        listenEnterBackground()
    }
    
    func listenEnterForeground() {
        if #available(iOS 15, *) {
            Task {
                for await _ in await NotificationCenter.default.notifications(named: UIScene.willEnterForegroundNotification) {
                    await willEnterForeground(Notification.init(name: UIScene.willEnterForegroundNotification, object: url))
                }
            }
        } else {
            NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.willEnterForeground(
                    Notification.init(
                        name: UIApplication.willEnterForegroundNotification,
                        object: self?.url
                    )
                )
            }
        }
    }

    func listenEnterBackground() {
        if #available(iOS 15, *) {
            Task {
                for await _ in await NotificationCenter.default.notifications(named: UIScene.didEnterBackgroundNotification) {
                    didEnterBackgroundNotification()
                }
            }
        } else {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterBackgroundNotification),
                name: UIScene.didEnterBackgroundNotification,
                object: nil
            )
        }
    }
    
    @objc
    func willEnterForeground(_ notification: Notification) {
        guard let url = notification.object as? URL else {
            return
        }
        delegate?.enterForeground(url: url)
    }
    
    @objc
    func didEnterBackgroundNotification() {
        delegate?.enterBackground()
    }
}
