# Donggong

A reader for `hitomi.la` with an Android app built on Jetpack Compose and an iOS app built on SwiftUI. Both apps share one Go core that handles network requests, DPI bypass, Nozomi indexes, search, and image URLs through gomobile.

## Features

- Home gallery lists with infinite scrolling or pagination, plus detailed, compact, and grid layouts.
- Tag search (`artist:`, `female:`, `male:`, `group:`, `character:`), autocomplete, recent searches, favorite tag chips, and direct gallery ID lookup.
- Gallery details, favorites, and recently viewed history with a return path to the originating list.
- Webtoon, vertical, horizontal, and two-page reading modes. The reader supports page jumping, left or right page turns, pinch zoom, favorites, and gallery details.
- Korean and English UI, light, dark, OLED black, and system themes.
- JSON favorites backup and restore through the system document picker. Donggong and Pupil backups are supported, and the format is the same on both platforms.
- Separate cache clearing and app-data reset.
- GitHub Release based update checks. Android downloads and installs the APK; iOS opens the release page.

## Structure

- `core/`: Go DPI bypass, Nozomi parsing, tag search, image URL resolution, and the gomobile interface.
- `app/`: Android app. Compose UI, Coil image loading, and SQLite settings, favorites, cache, and history.
- `ios/`: iOS app. SwiftUI with Liquid Glass, SwiftData for favorites, cache, and history, and UserDefaults for settings.

## Android build

The project targets Java 17 for Gradle. Use a Java 17 JDK if the system default is newer.

```bash
cd core
gomobile bind -target=android -androidapi=26 -o ../app/libs/core.aar .
cd ..
./gradlew assembleDebug
```

Use `./gradlew assembleRelease` for a release APK. Outputs are under `app/build/outputs/apk/`.

## iOS build

The iOS app requires Xcode 26 and targets iOS 26. Build the Go core as an XCFramework first, then open the Xcode project.

```bash
cd core
gomobile bind -target=ios,iossimulator -iosversion=26.0 -o ../ios/Core.xcframework .
cd ..
open ios/Donggong.xcodeproj
```

Select a development team under Signing & Capabilities before running on a device. For a command-line simulator build:

```bash
xcodebuild -project ios/Donggong.xcodeproj -scheme Donggong \
  -destination 'generic/platform=iOS Simulator' build
```
