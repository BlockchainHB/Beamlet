import Foundation

/// Retains a selected resource's sandbox extension for its owner's lifetime.
/// Store settings prevent replacing a selection while a child process is running.
final class SecurityScopedSelection {
    let url: URL
    private init(_ url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }
        self.url = url
    }

    deinit { url.stopAccessingSecurityScopedResource() }

    static func select(_ url: URL, key: String, defaults: UserDefaults, readOnly: Bool = false) throws -> SecurityScopedSelection {
        let selection = try SecurityScopedSelection(url)
        // Persist only after access and bookmark creation both succeed.
        let options: URL.BookmarkCreationOptions = readOnly ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess] : [.withSecurityScope]
        let data = try url.bookmarkData(options: options,
                                        includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: key)
        return selection
    }

    static func restore(key: String, defaults: UserDefaults, readOnly: Bool = false) throws -> SecurityScopedSelection? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        let selection = try SecurityScopedSelection(url)
        if stale {
            let options: URL.BookmarkCreationOptions = readOnly ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess] : [.withSecurityScope]
            let refreshed = try url.bookmarkData(options: options,
                                                  includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(refreshed, forKey: key)
        }
        return selection
    }
}
