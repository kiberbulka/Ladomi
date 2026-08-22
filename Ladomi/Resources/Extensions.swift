import Foundation
import UIKit

extension UIFont {
    static func ladomiBold(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .bold)
    }

    static func ladomiMedium(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .medium)
    }

    static func ladomiRegular(_ size: CGFloat) -> UIFont {
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

extension Locale {
    static var appPreferred: Locale {
        guard let languageCode = Bundle.main.preferredLocalizations.first else {
            return .current
        }
        return Locale(identifier: languageCode)
    }
}
