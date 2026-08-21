import Foundation
import UIKit

extension UIFont {
    static func ritmoBold(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .bold)
    }

    static func ritmoMedium(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .medium)
    }

    static func ritmoRegular(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .regular)
    }
}

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }

    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: compactMap {
            guard let newKey = transform($0.key) else { return nil }
            return (newKey, $0.value)
        })
    }
}
