import Foundation
import SwiftData

@Model
final class GatewayConnection {
    var host: String
    var port: Int
    var channelId: String
    var lastConnected: Date?

    init(host: String = "192.168.1.42", port: Int = 19001, channelId: String = "ios-app") {
        self.host = host
        self.port = port
        self.channelId = channelId
    }

    var baseURL: String {
        "ws://\(host):\(port)"
    }
}
