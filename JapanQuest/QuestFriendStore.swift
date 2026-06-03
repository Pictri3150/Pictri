import SwiftUI
import Combine

final class QuestFriendStore: ObservableObject {
    @Published var friends: [QuestFriend] = mockQuestFriends
    @Published var incomingRequests: [QuestFriendRequest] = mockQuestFriendRequests

    func addFriend(username: String) {
        let cleanedUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")

        guard !cleanedUsername.isEmpty else {
            return
        }

        let alreadyExists = friends.contains {
            $0.username.lowercased() == cleanedUsername.lowercased()
        }

        guard !alreadyExists else {
            return
        }

        let newFriend = QuestFriend(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            username: cleanedUsername,
            displayName: cleanedUsername,
            recentPlace: "まだシェアなし",
            lastSharedText: "未投稿"
        )

        friends.insert(newFriend, at: 0)
    }

    func accept(_ request: QuestFriendRequest) {
        let newFriend = QuestFriend(
            id: UUID().uuidString,
            userId: request.userId,
            username: request.username,
            displayName: request.displayName,
            recentPlace: "まだシェアなし",
            lastSharedText: "未投稿"
        )

        friends.insert(newFriend, at: 0)
        incomingRequests.removeAll { $0.id == request.id }
    }

    func decline(_ request: QuestFriendRequest) {
        incomingRequests.removeAll { $0.id == request.id }
    }
}
