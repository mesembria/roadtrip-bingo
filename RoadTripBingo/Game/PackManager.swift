import Foundation

enum PackManager {
    /// Loads all `pack-*.json` files from the main bundle, sorted by pack name.
    /// Returns an empty array if none are found or all fail to decode.
    static func loadAll() -> [TilePack] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json",
                                          subdirectory: nil) else { return [] }
        return urls
            .filter { $0.lastPathComponent.hasPrefix("pack-") }
            .compactMap { url -> TilePack? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(TilePack.self, from: data)
            }
            .sorted { $0.name < $1.name }
    }

    /// Returns the pack with the given ID, or nil if not found.
    static func pack(id: String) -> TilePack? {
        loadAll().first { $0.id == id }
    }

    /// Returns all packs whose IDs are in the given list, preserving sort order.
    static func packs(forIDs ids: [String]) -> [TilePack] {
        let all = loadAll()
        return ids.compactMap { id in all.first { $0.id == id } }
    }
}
