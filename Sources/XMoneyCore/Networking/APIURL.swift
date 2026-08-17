import Foundation

enum APIURL {
    static func encodePathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?&#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func make(base: String, path: String, query: [URLQueryItem] = []) -> URL {
        let encodedPath = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { encodePathSegment(String($0)) }
            .joined(separator: "/")
        guard var components = URLComponents(string: base) else {
            preconditionFailure("Invalid API base URL: \(base)")
        }
        components.path = "/" + encodedPath
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            preconditionFailure("Invalid API URL for path \(path)")
        }
        return url
    }
}
