import Foundation

struct ReleaseInfo: Sendable, Equatable {
    let version: String
    let pageURL: URL
}

/// Checks GitHub Releases for a newer build. iOS cannot install a sideloaded build
/// in place, so an update opens the release page instead of downloading an APK.
enum AppUpdater {
    private static let repository = "barreltong/donggong"

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: String

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static func latestRelease() async throws -> ReleaseInfo {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Donggong-App", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let pageURL = URL(string: release.htmlURL),
              pageURL.scheme == "https",
              pageURL.host() == "github.com"
        else { throw URLError(.badServerResponse) }
        return ReleaseInfo(version: normalizeVersion(release.tagName), pageURL: pageURL)
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = versionParts(candidate)
        let rhs = versionParts(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func normalizeVersion(_ raw: String) -> String {
        let trimmed = raw.hasPrefix("v") ? String(raw.dropFirst()) : raw
        return String(trimmed.split(separator: "+", omittingEmptySubsequences: false).first ?? "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func versionParts(_ version: String) -> [Int] {
        normalizeVersion(version)
            .split(whereSeparator: { $0 == "." || $0 == "-" })
            .map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}
