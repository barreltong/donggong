import SwiftUI

/// Picks the Korean or English string for the in-app language setting.
struct Tr: Sendable {
    let language: AppLanguage

    func callAsFunction(_ korean: String, _ english: String) -> String {
        language == .english ? english : korean
    }
}

/// The monochrome zinc palette shared with the Android app.
struct Palette: Sendable {
    var background: Color
    var card: Color
    var chip: Color
    var chipSelected: Color
    var outline: Color
    var secondaryText: Color
    var accent: Color
    var onAccent: Color

    static let favorite = Color(hex: 0xE53935)

    static func resolve(theme: ThemeMode, scheme: ColorScheme) -> Palette {
        switch (theme, scheme) {
        case (.light, _), (.system, .light):
            light
        case (.oled, _):
            oled
        default:
            dark
        }
    }

    static let dark = Palette(
        background: Color(hex: 0x09090B),
        card: Color(hex: 0x161619),
        chip: Color(hex: 0x1E1E22),
        chipSelected: Color(hex: 0x2E2E34),
        outline: Color(hex: 0x3F3F46),
        secondaryText: Color(hex: 0xA1A1AA),
        accent: Color(hex: 0xF4F4F5),
        onAccent: Color(hex: 0x09090B)
    )

    static let oled = Palette(
        background: .black,
        card: Color(hex: 0x111114),
        chip: Color(hex: 0x1E1E22),
        chipSelected: Color(hex: 0x2E2E34),
        outline: Color(hex: 0x3F3F46),
        secondaryText: Color(hex: 0xA1A1AA),
        accent: Color(hex: 0xF4F4F5),
        onAccent: Color(hex: 0x09090B)
    )

    static let light = Palette(
        background: .white,
        card: Color(hex: 0xF4F4F5),
        chip: Color(hex: 0xE4E4E7),
        chipSelected: Color(hex: 0xD4D4D8),
        outline: Color(hex: 0xA1A1AA),
        secondaryText: Color(hex: 0x52525B),
        accent: Color(hex: 0x18181B),
        onAccent: .white
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension EnvironmentValues {
    @Entry var tr: Tr = Tr(language: .korean)
    @Entry var palette: Palette = Palette.dark
}

/// Applies the theme's palette and tint to a presentation root. Every sheet and
/// cover applies it again because presentations resolve their own color scheme.
struct AppThemeModifier: ViewModifier {
    let theme: ThemeMode
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette = Palette.resolve(theme: theme, scheme: colorScheme)
        content
            .environment(\.palette, palette)
            .tint(palette.accent)
    }
}

extension View {
    func appTheme(_ theme: ThemeMode) -> some View {
        modifier(AppThemeModifier(theme: theme))
            .preferredColorScheme(theme.colorScheme)
    }
}
