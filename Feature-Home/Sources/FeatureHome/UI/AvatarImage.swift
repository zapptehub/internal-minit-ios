import CoreNetworking
import DesignSystem
import SwiftUI
import UIKit

/// Profile photo in the 40 pt header circle.
///
/// A blank URL, a scheme other than http or https, a `.` or `..` path
/// segment, and a foreign URL outside `/v1/media/` draw
/// `DSImage.mockUserProfile` and do not call the network. A path under
/// `/v1/media/` is rewritten onto the API base, including that base's path
/// prefix, and keeps its query. A same-origin URL outside `/v1/media/` is
/// fetched as-is. A firebase profile has a nil URL.
/// An HTTP or decode failure draws the same placeholder. Bytes come from
/// `NetworkClient.data`, so the host-scoped session attaches Bearer and
/// `CF-Access-*` and `URLCache` stores the media response. There is no
/// separate avatar disk cache.
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

/// Avatar URL to fetch, or nil when the header stays on the placeholder.
///
/// A path under `/v1/media/` is rebuilt as the API base plus that path, so a
/// loopback avatar still requests the app base. The query is kept. The
/// fragment is dropped. A path with a `.` or `..` segment, including
/// percent-encoded `%2e` and `%2E`, is nil before that prefix test. A blank
/// URL, a scheme other than http or https, and a foreign URL outside
/// `/v1/media/` are nil. A URL already on the API origin whose path does not
/// start with `/v1/media/` is fetched as-is, which keeps a `PUBLIC_BASE_URL`
/// that already includes the base path. Its fragment is dropped. A same-origin
/// URL with userinfo is nil.
enum AvatarRequestURL {
    private static let mediaPathPrefix = "/v1/media/"

    static func resolved(avatarURL: String?, apiBaseURL: String) -> URL? {
        let trimmed = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, let avatar = URLComponents(string: trimmed), isHTTP(avatar) else {
            return nil
        }
        guard !hasDotSegment(avatar.percentEncodedPath) else {
            return nil
        }
        if avatar.percentEncodedPath.hasPrefix(mediaPathPrefix) {
            return mediaURL(
                path: avatar.percentEncodedPath,
                query: avatar.percentEncodedQuery,
                apiBaseURL: apiBaseURL
            )
        }
        guard avatar.user == nil, avatar.password == nil else {
            return nil
        }
        var sameOrigin = avatar
        sameOrigin.fragment = nil
        guard let url = sameOrigin.url, let avatarOrigin = Origin(url) else {
            return nil
        }
        let baseTrimmed = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: baseTrimmed),
              let api = Origin(baseURL),
              avatarOrigin == api else {
            return nil
        }
        return url
    }

    /// API base plus the encoded media path. Trailing slashes on the base path
    /// are removed so the join does not produce an empty segment. Any query or
    /// fragment on the base is dropped; the avatar query is the one kept.
    private static func mediaURL(path: String, query: String?, apiBaseURL: String) -> URL? {
        let baseTrimmed = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var base = URLComponents(string: baseTrimmed), isHTTP(base) else {
            return nil
        }
        base.percentEncodedPath = basePathPrefix(base.percentEncodedPath) + path
        base.percentEncodedQuery = query
        base.fragment = nil
        guard let url = base.url,
              let rebuilt = URLComponents(url: url, resolvingAgainstBaseURL: false),
              isHTTP(rebuilt) else {
            return nil
        }
        return url
    }

    /// A path segment that is `.` or `..` after one percent-decode. `%2e` and
    /// `%2E` count. Checked before the `/v1/media/` prefix test so a traversal
    /// is never rewritten onto the API host.
    private static func hasDotSegment(_ percentEncodedPath: String) -> Bool {
        for segment in percentEncodedPath.split(separator: "/") {
            let decoded = String(segment).removingPercentEncoding ?? String(segment)
            if decoded == "." || decoded == ".." {
                return true
            }
        }
        return false
    }

    private static func basePathPrefix(_ path: String) -> String {
        var prefix = path
        while prefix.hasSuffix("/") {
            prefix.removeLast()
        }
        return prefix
    }

    private static func isHTTP(_ components: URLComponents) -> Bool {
        guard let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            return false
        }
        return true
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
