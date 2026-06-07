import SwiftUI

// MARK: - Home

struct HomeView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var memoryStore: QuestMemoryStore
    @EnvironmentObject var friendStore: QuestFriendStore

    @State private var showAccountMenu = false
    @State private var likedPostIds: Set<String> = []
    @State private var profilePost: QuestFeedPost?

    private var visiblePosts: [QuestFeedPost] {
        memoryStore.visibleFeedPosts()
    }

    private var completedSpotCount: Int {
        Set(memoryStore.memoryPhotos.map { $0.spotId }).count
    }

    private var kanagawaTotalSpotCount: Int {
        mockQuestPrefectures.first { $0.id == "kanagawa" }?.totalSpotCount ?? 24
    }

    private var unvisitedKanagawaSpots: [QuestSpot] {
        let completedIds = Set(memoryStore.memoryPhotos.map { $0.spotId })
        return mockQuestSpots
            .filter { $0.prefectureId == "kanagawa" && !completedIds.contains($0.id) }
            .sorted { $0.gridIndex < $1.gridIndex }
            .prefix(2)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        topBar
                        questHeroCard
                        if !unvisitedKanagawaSpots.isEmpty {
                            nextSpotSection
                        }
                        recentShareSection

                        Spacer(minLength: 90)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                }
            }
            .sheet(isPresented: $showAccountMenu) {
                JQAccountSheetView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $profilePost) { post in
                FriendProfileSheet(post: post)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func toggleLike(postId: String) {
        if likedPostIds.contains(postId) {
            likedPostIds.remove(postId)
        } else {
            likedPostIds.insert(postId)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ピクトリ")
                    .font(.system(size: 30, weight: .bold))

                Text("場所で見つけて、現地で残す")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            Button {
                showAccountMenu = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(.white.opacity(0.10))
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        }

                    if !friendStore.incomingRequests.isEmpty {
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Text("\(friendStore.incomingRequests.count)")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(.black)
                            }
                            .offset(x: 1, y: 1)
                    }
                }
            }
        }
    }

    private var questHeroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.12),
                            .white.opacity(0.045),
                            .white.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 250)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("次のスポットを地図で探す")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)

                        Text(completedSpotCount == 0
                            ? "まず1箇所、現地で写真を残してみよう。"
                            : "神奈川 \(completedSpotCount) / \(kanagawaTotalSpotCount) スポット")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.52))
                            .lineSpacing(3)
                    }

                    Spacer()

                    Image(systemName: "map.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(.white)
                        .clipShape(Circle())
                }

                Button {
                    selectedTab = .map
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("地図でスポットを探す")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var nextSpotSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("気になるスポット")
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                Button {
                    selectedTab = .map
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("地図で見る")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.10))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }

            ForEach(unvisitedKanagawaSpots) { spot in
                Button {
                    selectedTab = .map
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(spot.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            Text(spot.areaName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(14)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentShareSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("フレンドの旅の記録")
                    .font(.system(size: 20, weight: .bold))

                Spacer()

                Text("7日間")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.10))
                    .foregroundStyle(.white.opacity(0.72))
                    .clipShape(Capsule())
            }

            if visiblePosts.isEmpty {
                EmptyFeedCard()
            } else {
                ForEach(visiblePosts.prefix(4)) { post in
                    HomeLargePostCard(
                        post: post,
                        isLiked: likedPostIds.contains(post.id),
                        onLike: { toggleLike(postId: post.id) },
                        onProfileTap: { profilePost = post }
                    )
                }
            }
        }
    }
}

// MARK: - Feed Cards

struct EmptyFeedCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))

            Text("まだフレンドの記録がありません")
                .font(.system(size: 17, weight: .bold))

            Text("地図でスポットを見つけて、現地で写真を残すとここに表示されます。")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct HomeLargePostCard: View {
    let post: QuestFeedPost
    var isLiked: Bool
    var onLike: () -> Void
    var onProfileTap: () -> Void

    @EnvironmentObject var memoryStore: QuestMemoryStore

    @State private var isCommentVisible = false
    @State private var commentDraft = ""
    @State private var comments: [String] = []

    private var spot: QuestSpot? {
        mockQuestSpots.first { $0.id == post.spotId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            postHeader

            ZStack(alignment: .bottomLeading) {
                postVisual

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.displayDate)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))

                    Text(post.displayPlace)
                        .font(.system(size: 25, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(16)

                if post.isMine {
                    Text("you")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                        .padding(14)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topTrailing
                        )
                }
            }

            postFooter
        }
        .padding(12)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 26))
    }

    private var postHeader: some View {
        HStack(spacing: 10) {
            Button {
                onProfileTap()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Text(String(post.username.prefix(1)).uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.username)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text("\(post.displayPlace) ・ \(daysLeftText)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                onLike()
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isLiked ? .white : .white.opacity(0.42))
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isLiked)
            }
        }
    }

    private var postFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !comments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(comments, id: \.self) { comment in
                        Text(comment)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isCommentVisible.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text(comments.isEmpty ? "コメントする" : "\(comments.count)件のコメント")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.48))
            }

            if isCommentVisible {
                HStack(spacing: 8) {
                    TextField("コメントを入力…", text: $commentDraft)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        let trimmed = commentDraft.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            comments.append(trimmed)
                            commentDraft = ""
                            isCommentVisible = false
                        }
                    } label: {
                        Text("送信")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var postVisual: some View {
        if let image = memoryStore.image(for: post) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 255)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            RoundedRectangle(cornerRadius: 22)
                .fill(placeholderGradient)
                .frame(height: 255)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.black.opacity(0.12))
                }
        }
    }

    private var placeholderGradient: LinearGradient {
        if let spot {
            return MemoryVisualStyle.gradient(for: spot)
        }

        return LinearGradient(
            colors: [.gray.opacity(0.4), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var daysLeftText: String {
        let seconds = post.expiresAt.timeIntervalSince(Date())
        let days = max(Int(ceil(seconds / 86400)), 0)

        if days <= 0 {
            return "まもなく消えます"
        } else {
            return "あと\(days)日"
        }
    }
}

// MARK: - Friend Profile Sheet

struct FriendProfileSheet: View {
    let post: QuestFeedPost

    @Environment(\.dismiss) private var dismiss

    private var recordCount: Int {
        abs(post.username.hashValue % 18) + 5
    }

    private var spotCount: Int {
        max(recordCount / 3, 1)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 22) {
                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }

                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 76, height: 76)
                    .overlay {
                        Text(String(post.username.prefix(1)).uppercased())
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(spacing: 6) {
                    Text(post.username)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text("現地で撮る、場所で残す")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                }

                HStack(spacing: 10) {
                    profileStat(title: "記録", value: "\(recordCount)")
                    profileStat(title: "旅先", value: "\(spotCount)")
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private func profileStat(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Account

struct JQAccountSheetView: View {
    @EnvironmentObject var friendStore: QuestFriendStore
    @EnvironmentObject var memoryStore: QuestMemoryStore

    @State private var selectedSection: JQAccountSection = .profile
    @State private var addFriendText = ""

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    stats
                    sectionTabs
                    sectionContent

                    Spacer(minLength: 40)
                }
                .padding(18)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 82, height: 82)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

            VStack(spacing: 5) {
                Text("keita_travel")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("場所で残す、旅の記録")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            JQAccountStat(title: "フォロー中", value: "\(friendStore.friends.count)")
            JQAccountStat(title: "フォロワー", value: "12")
            JQAccountStat(title: "スポット", value: "\(memoryStore.memoryPhotos.count)")
        }
    }

    private var sectionTabs: some View {
        HStack(spacing: 8) {
            JQAccountSectionButton(title: "概要", section: .profile, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "フォロー", section: .following, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "追加", section: .add, selectedSection: $selectedSection)
            JQAccountSectionButton(title: "申請", section: .requests, selectedSection: $selectedSection)
        }
        .padding(5)
        .background(.white.opacity(0.06))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .profile:
            VStack(spacing: 12) {
                JQAccountMenuRow(icon: "person.crop.circle", title: "プロフィール編集")
                JQAccountMenuRow(icon: "lock.fill", title: "公開範囲")
                JQAccountMenuRow(icon: "bell.fill", title: "通知")
                JQAccountMenuRow(icon: "gearshape.fill", title: "設定")
            }

        case .following:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(friendStore.friends) { friend in
                    JQFriendMiniRow(friend: friend)
                }
            }

        case .add:
            VStack(alignment: .leading, spacing: 14) {
                Text("ユーザー名で追加")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                TextField("@username", text: $addFriendText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .semibold))
                    .padding(15)
                    .background(.white.opacity(0.08))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    friendStore.addFriend(username: addFriendText)
                    addFriendText = ""
                    selectedSection = .following
                } label: {
                    Text("フォローする")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(15)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 22))

        case .requests:
            VStack(alignment: .leading, spacing: 12) {
                if friendStore.incomingRequests.isEmpty {
                    Text("新しい申請はありません")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(.white.opacity(0.055))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    ForEach(friendStore.incomingRequests) { request in
                        JQRequestMiniRow(request: request)
                    }
                }
            }
        }
    }
}

enum JQAccountSection {
    case profile
    case following
    case add
    case requests
}

struct JQAccountSectionButton: View {
    let title: String
    let section: JQAccountSection
    @Binding var selectedSection: JQAccountSection

    var body: some View {
        Button {
            selectedSection = section
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selectedSection == section ? .white : .clear)
                .foregroundStyle(selectedSection == section ? .black : .white.opacity(0.68))
                .clipShape(Capsule())
        }
    }
}

struct JQAccountStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct JQAccountMenuRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct JQFriendMiniRow: View {
    let friend: QuestFriend

    var body: some View {
        HStack(spacing: 13) {
            Circle()
                .fill(.white.opacity(0.13))
                .frame(width: 46, height: 46)
                .overlay {
                    Text(String(friend.displayName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                Text("@\(friend.username)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Text("フォロー中")
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08))
                .foregroundStyle(.white.opacity(0.75))
                .clipShape(Capsule())
        }
        .padding(13)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct JQRequestMiniRow: View {
    @EnvironmentObject var friendStore: QuestFriendStore
    let request: QuestFriendRequest

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 13) {
                Circle()
                    .fill(.white.opacity(0.13))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(String(request.displayName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text("@\(request.username)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    friendStore.decline(request)
                } label: {
                    Text("削除")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.08))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    friendStore.accept(request)
                } label: {
                    Text("承認")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(13)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
