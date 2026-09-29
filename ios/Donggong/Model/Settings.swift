import SwiftUI

/// A user setting persisted in UserDefaults under the same raw values the Android app uses.
protocol StoredSetting: RawRepresentable<String>, CaseIterable, Hashable, Sendable {
    static var key: String { get }
    static var fallback: Self { get }
}

extension StoredSetting {
    static var stored: Self {
        UserDefaults.standard.string(forKey: key).flatMap(Self.init(rawValue:)) ?? fallback
    }
}

enum SettingsStore {
    static func resetAll() {
        let keys = [
            ThemeMode.key, AppLanguage.key, ReaderMode.key, DoublePageOrder.key,
            PageTurnDirection.key, ListingMode.key, CardViewMode.key, GalleryLanguage.key,
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

enum ThemeMode: String, StoredSetting {
    case system, dark, oled, light

    static let key = "themeMode"
    static let fallback = ThemeMode.dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark, .oled: .dark
        case .light: .light
        }
    }

    func label(_ tr: Tr) -> String {
        switch self {
        case .system: tr("시스템 설정", "System")
        case .dark: tr("다크 모드", "Dark")
        case .oled: tr("OLED 다크", "OLED black")
        case .light: tr("라이트 모드", "Light")
        }
    }
}

enum AppLanguage: String, StoredSetting {
    case korean = "ko"
    case english = "en"

    static let key = "appLanguage"
    static let fallback = AppLanguage.korean

    var label: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

enum ReaderMode: String, StoredSetting {
    case webtoon, verticalPage, horizontalPage, doublePage

    static let key = "readerMode"
    static let fallback = ReaderMode.verticalPage

    func label(_ tr: Tr) -> String {
        switch self {
        case .webtoon: tr("웹툰 모드 (세로 연속)", "Webtoon (continuous scroll)")
        case .verticalPage: tr("세로 페이지 (스와이프)", "Vertical pages")
        case .horizontalPage: tr("가로 페이지 (스와이프)", "Horizontal pages")
        case .doublePage: tr("두 쪽 보기 (태블릿/가로)", "Two-page spreads")
        }
    }

    func shortLabel(_ tr: Tr) -> String {
        switch self {
        case .webtoon: tr("웹툰", "Webtoon")
        case .verticalPage: tr("세로", "Vertical")
        case .horizontalPage: tr("가로", "Horizontal")
        case .doublePage: tr("양면", "Double")
        }
    }
}

enum DoublePageOrder: String, StoredSetting {
    case japanese, international

    static let key = "doublePageOrder"
    static let fallback = DoublePageOrder.japanese

    func label(_ tr: Tr) -> String {
        switch self {
        case .japanese: tr("우 → 좌 (일본식 만화)", "Right to left")
        case .international: tr("좌 → 우 (한국/서양식)", "Left to right")
        }
    }
}

enum PageTurnDirection: String, StoredSetting {
    case left, right

    static let key = "pageTurnDirection"
    static let fallback = PageTurnDirection.left

    func label(_ tr: Tr) -> String {
        switch self {
        case .left: tr("왼쪽으로 넘김", "Turn left")
        case .right: tr("오른쪽으로 넘김", "Turn right")
        }
    }
}

enum ListingMode: String, StoredSetting {
    case scroll, pagination

    static let key = "listingMode"
    static let fallback = ListingMode.scroll

    func label(_ tr: Tr) -> String {
        switch self {
        case .scroll: tr("무한 스크롤", "Infinite scroll")
        case .pagination: tr("페이지네이션 (하단 바)", "Pagination")
        }
    }
}

enum CardViewMode: String, StoredSetting {
    case detailed, compact, grid

    static let key = "cardViewMode"
    static let fallback = CardViewMode.detailed

    var next: CardViewMode {
        switch self {
        case .detailed: .compact
        case .compact: .grid
        case .grid: .detailed
        }
    }

    var symbolName: String {
        switch self {
        case .detailed: "rectangle.grid.1x2"
        case .compact: "list.bullet"
        case .grid: "square.grid.2x2"
        }
    }

    func label(_ tr: Tr) -> String {
        switch self {
        case .detailed: tr("상세 보기 (태그/작가)", "Detailed (tags and artists)")
        case .compact: tr("간단히 보기", "Compact")
        case .grid: tr("그리드 보기 (격자)", "Grid")
        }
    }
}

enum GalleryLanguage: String, StoredSetting {
    case korean, all, japanese, english

    static let key = "defaultLanguage"
    static let fallback = GalleryLanguage.korean

    func label(_ tr: Tr) -> String {
        switch self {
        case .korean: tr("한국어 (korean)", "Korean")
        case .all: tr("모든 언어 (all)", "All languages")
        case .japanese: tr("일본어 (japanese)", "Japanese")
        case .english: tr("영어 (english)", "English")
        }
    }
}
