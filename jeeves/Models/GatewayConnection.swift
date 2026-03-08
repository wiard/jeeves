import Foundation
import SwiftData

@Model
final class GatewayConnection {
    var host: String
    var port: Int
    var channelId: String
    var lastConnected: Date?

    init(host: String = "localhost", port: Int = 19001, channelId: String = "ios-app") {
        self.host = host
        self.port = port
        self.channelId = channelId
    }

    var baseURL: String {
        "http://\(host):\(port)"
    }
}
