import Foundation
import UIKit

final class NameService {
    static let shared = NameService()

    private enum Keys {
        // Reserved for onboarding/profile capture.
        static let storedFirstName = "profile.firstName"
    }

    private let defaults: UserDefaults
    private let deviceNameProvider: () -> String

    init(
        defaults: UserDefaults = .standard,
        deviceNameProvider: @escaping () -> String = { UIDevice.current.name }
    ) {
        self.defaults = defaults
        self.deviceNameProvider = deviceNameProvider
    }

    func resolvedFirstName() -> String? {
        if let storedFirstName = normalizedFirstName(from: defaults.string(forKey: Keys.storedFirstName)) {
            return storedFirstName
        }

        if let deviceFirstName = resolvedFromDeviceName() {
            return deviceFirstName
        }

        return nil
    }

    private func resolvedFromDeviceName() -> String? {
        let deviceName = deviceNameProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawToken = deviceName.split(whereSeparator: \.isWhitespace).first else {
            return nil
        }

        var token = String(rawToken)
        let lowercase = token.lowercased()
        if lowercase.hasSuffix("'s") || lowercase.hasSuffix("’s") {
            token.removeLast(2)
        }

        return normalizedFirstName(from: token)
    }

    private func normalizedFirstName(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let firstToken = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? trimmed
        let filtered = firstToken
            .unicodeScalars
            .filter { scalar in
                CharacterSet.letters.contains(scalar)
                    || scalar == "-"
                    || scalar == "'"
                    || scalar == "’"
            }

        var candidate = String(String.UnicodeScalarView(filtered))
        candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "-'’"))
        guard !candidate.isEmpty else { return nil }

        let lowercase = candidate.lowercased(with: .autoupdatingCurrent)
        return lowercase.capitalized(with: .autoupdatingCurrent)
    }
}
