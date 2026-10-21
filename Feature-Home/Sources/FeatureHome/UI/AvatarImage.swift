import CoreNetworking
import DesignSystem
import SwiftUI
import UIKit

/// Profile photo in the 40 pt header circle.
///
/// Nil, empty, and any URL whose scheme, host, and port do not match the API
/// base draw `DSImage.mockUserProfile` and do not call the network. A firebase
/// profile has a nil URL. An HTTP or decode failure draws the same placeholder.
/// Bytes come from `NetworkClient.data`, so the host-scoped session attaches
/// Bearer and `CF-Access-*` and `URLCache` stores the media response. There is
/// no separate avatar disk cache.
struct AvatarImage: View {
    let avatarURL: String?
    let apiBaseURL: String
    let client: any NetworkClient

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                DSImageView(
                    image: .mockUserProfile,
                    size: CGSize(width: HomeHeaderMetrics.iconSize, height: HomeHeaderMetrics.iconSize),
                    contentMode: .fill
                )
            }
        }
        .frame(width: HomeHeaderMetrics.iconSize, height: HomeHeaderMetrics.iconSize)
        .clipShape(Circle())
        .task(id: AvatarRequestURL.resolved(avatarURL: avatarURL, apiBaseURL: apiBaseURL)) {
            image = nil
            image = await AvatarImageLoader.load(
                avatarURL: avatarURL,
                apiBaseURL: apiBaseURL,
                client: client
            )
        }
    }
}

enum AvatarImageLoader {
    static func load(
        avatarURL: String?,
        apiBaseURL: String,
        client: any NetworkClient
    ) async -> UIImage? {
        guard let url = AvatarRequestURL.resolved(avatarURL: avatarURL, apiBaseURL: apiBaseURL) else {
            return nil
        }
        do {
            let data = try await client.data(url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

/// Absolute avatar URL on the API origin, or nil when it must not be fetched.
enum AvatarRequestURL {
    static func resolved(avatarURL: String?, apiBaseURL: String) -> URL? {
        let trimmed = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let avatar = Origin(url) else {
            return nil
        }
        guard let base = URL(string: apiBaseURL), let api = Origin(base), avatar == api else {
            return nil
        }
        return url
    }

    /// Scheme, host, and port. The base path is not part of the match, same as
    /// the host-scoped session. `http` is 80 and `https` is 443 when the URL
    /// omits the port.
    private struct Origin: Equatable {
        let scheme: String
        let host: String
        let port: Int

        init?(_ url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let scheme = components.scheme?.lowercased(),
                  let host = components.host?.lowercased(),
                  !host.isEmpty,
                  let port = components.port ?? Self.defaultPort(for: scheme) else {
                return nil
            }
            self.scheme = scheme
            self.host = host
            self.port = port
        }

        private static func defaultPort(for scheme: String) -> Int? {
            switch scheme {
            case "http": return 80
            case "https": return 443
            default: return nil
            }
        }
    }
}
