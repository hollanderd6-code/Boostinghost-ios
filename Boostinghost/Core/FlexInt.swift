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
}
