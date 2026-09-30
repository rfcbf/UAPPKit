import Combine
import SwiftUI
import UIKit

struct UAPPOnChangeModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value) -> Void

    @State private var previousValue: Value?

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            content.onReceive(Just(value)) { newValue in
                guard let previousValue else {
                    self.previousValue = newValue
                    return
                }
                guard previousValue != newValue else {
                    return
                }
                self.previousValue = newValue
                action(newValue)
            }
        }
    }
}

extension View {
    func uappOnChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        modifier(UAPPOnChangeModifier(value: value, action: action))
    }
}

enum DemoLocalized {
    static func string(_ key: String, languageIdentifier: String) -> String {
        let bundle = Bundle.main
        let path = bundle.path(forResource: languageIdentifier, ofType: "lproj")
            ?? bundle.path(forResource: "pt-BR", ofType: "lproj")
        return (path.flatMap(Bundle.init(path:)) ?? bundle)
            .localizedString(forKey: key, value: key, table: nil)
    }
}

enum DemoHexColor {
    static func color(from value: String) -> Color? {
        let hex = value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingPrefix("#")
        guard hex.count == 6, let number = UInt32(hex, radix: 16) else { return nil }
        let red = Double((number >> 16) & 0xFF) / 255
        let green = Double((number >> 8) & 0xFF) / 255
        let blue = Double(number & 0xFF) / 255
        return Color(red: red, green: green, blue: blue)
    }

    static func hex(from color: Color) -> String {
        let components = UIColor(color).cgColor.components ?? [0, 0, 0, 1]
        let red = Int((components[safe: 0] ?? 0) * 255)
        let green = Int((components[safe: 1] ?? 0) * 255)
        let blue = Int((components[safe: 2] ?? 0) * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
