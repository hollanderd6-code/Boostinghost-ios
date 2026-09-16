import Foundation

// The backend returns numeric columns inconsistently: sometimes Int, sometimes
// String (e.g. "depositAmount":"0"). These helpers coerce either form silently.

extension KeyedDecodingContainer {

    // Int-or-String → Int?
    func flexInt(forKey key: Key) -> Int? {
        if let i = try? decodeIfPresent(Int.self,    forKey: key) { return i }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s) }
        return nil
    }

    // Double-or-Int-or-String → Double?
    func flexDouble(forKey key: Key) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? decodeIfPresent(Int.self,    forKey: key) { return Double(i) }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }

    // String-or-Int → String?  (covers MongoDB ObjectId strings and PG int IDs)
    func flexString(forKey key: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key), !s.isEmpty { return s }
        if let i = try? decodeIfPresent(Int.self,    forKey: key) { return String(i) }
        return nil
    }

    // [String: Double-or-String] → [String: Double]?  (JSONB nightly breakdown)
    func flexDoubleDict(forKey key: Key) -> [String: Double]? {
        if let d = try? decodeIfPresent([String: Double].self, forKey: key) { return d }
        if let s = try? decodeIfPresent([String: String].self, forKey: key) {
            let converted = s.compactMapValues { Double($0) }
            return converted.isEmpty ? nil : converted
        }
        return nil
    }

    // Object-or-JSON-string → T?
    // amenities/houseRules/practicalInfo arrive as inline object or a JSON-encoded string.
    // The nested decoder applies convertFromSnakeCase so snake_case keys inside the string work.
    func flexDecodeJSON<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        if let value = try? decodeIfPresent(T.self, forKey: key) { return value }
        if let str = try? decodeIfPresent(String.self, forKey: key),
           let data = str.data(using: .utf8) {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try? decoder.decode(T.self, from: data)
        }
        return nil
    }
}
