import Foundation

package struct Subdivision: Equatable, Sendable {
    package let name: String
    package let aliases: [String]
}

package enum Subdivisions {
    private struct Stored: Decodable {
        let name: String
        let aliases: [String]?
    }

    private static let byCountry: [String: [Subdivision]] = load()

    package static func list(countryCode: String) -> [Subdivision] {
        let code = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return byCountry[code] ?? []
    }

    package static func find(countryCode: String, value: String) -> Subdivision? {
        let needle = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        let lower = needle.lowercased()
        for entry in list(countryCode: countryCode) {
            if entry.name.lowercased() == lower { return entry }
            if entry.aliases.contains(where: { $0.lowercased() == lower }) { return entry }
        }
        return nil
    }

    package static func regionName(countryCode: String, administrativeArea: String) -> String? {
        find(countryCode: countryCode, value: administrativeArea)?.name
    }

    package static func isSelectionComplete(countryCode: String, regionValue: String) -> Bool {
        regionName(countryCode: countryCode, administrativeArea: regionValue) != nil
    }

    private static func load() -> [String: [Subdivision]] {
        guard let url = CoreAssets.bundle.url(forResource: "subdivisions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [Stored]].self, from: data) else {
            return [:]
        }
        var result: [String: [Subdivision]] = [:]
        for (code, entries) in decoded {
            result[code] = entries.map { Subdivision(name: $0.name, aliases: $0.aliases ?? []) }
        }
        return result
    }
}
