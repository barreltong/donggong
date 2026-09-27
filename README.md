# Donggong

An Android reader for `hitomi.la` built with Jetpack Compose. The Go core handles network requests, DPI bypass, Nozomi indexes, search, and image URLs through gomobile.

## Features

- Home gallery lists with infinite scrolling or pagination, plus detailed, compact, and grid layouts.
- Tag search (`artist:`, `female:`, `male:`, `group:`, `character:`), autocomplete, recent searches, favorite tag chips, and direct gallery ID lookup.
- Gallery details, favorites, and recently viewed history with a return path to the originating list.
- Webtoon, vertical, horizontal, and two-page reading modes. The reader supports page jumping, left or right page turns, pinch zoom, favorites, and gallery details.
- Korean and English UI, light, dark, OLED black, and system themes.
- JSON favorites backup and restore through Android's document picker. Donggong and Pupil backups are supported.
- Separate cache clearing and app-data reset.
- GitHub Release based Android sideload updates.

## Structure

- `core/`: Go DPI bypass, Nozomi parsing, tag search, image URL resolution, and the gomobile interface.
- `app/`: Compose UI, Coil image loading, and SQLite settings, favorites, cache, and history.

## Build

The project targets Java 17 for Gradle. Use a Java 17 JDK if the system default is newer.

```bash
cd core
gomobile bind -target=android -androidapi=26 -o ../app/libs/core.aar .
cd ..
./gradlew assembleDebug
```

Use `./gradlew assembleRelease` for a release APK. Outputs are under `app/build/outputs/apk/`.
