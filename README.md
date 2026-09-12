# 동공 (Donggong)

`hitomi.la`용 Android 전용 Jetpack Compose 리더 앱입니다.
네트워크 및 코어 로직(DPI 우회, Nozomi 인덱스 파싱, 검색, 이미지 주소 계산 등)은 Go(gomobile)로 처리하고, UI 및 애플리케이션 계층은 Android Jetpack Compose로 구현되어 있습니다.

## 주요 기능

- 홈 목록에서 무한 스크롤과 페이지네이션 지원
- `artist:`, `female:`, `male:`, `group:`, `character:` 등 태그 기반 검색
- 검색 추천 완성 오버레이, 최근 검색 즉시 실행, 즐겨찾기 태그 빠른 추가
- 작품 상세/리더 화면에서 즐겨찾기 토글
- 리더 모드 지원
  - 웹툰 보기
  - 세로 페이지 보기
  - 가로 페이지 보기
  - 두 쪽 보기 (일본식 우->좌, 국제식 좌->우)
- 즐겨찾기 JSON 내보내기/가져오기 (Donggong 및 Pupil 포맷 지원)
- 최근 본 작품 기록 관리
- GitHub Release 기반 Android 사이드로드 OTA 업데이트
- Go 기반 DPI 우회 (TCP 소켓 단편화) 내장

## 아키텍처

- `core/`: Go 기반 코어 모듈
  - TCP 패킷 단편화를 이용한 DPI 차단 우회
  - Nozomi 바이너리 인덱스 다운로드 및 파싱
  - 다중 태그 교집합 검색 및 페이지네이션
  - `gg.js` 동적 라우팅 파싱 및 WebP 이미지 URL 계산
  - gomobile을 통해 Android AAR(`app/libs/core.aar`)로 컴파일
- `app/`: Native Android 앱 모듈
  - Jetpack Compose (Material 3) 기반 반응형 UI
  - Coil 이미지 로더 커스텀 페처를 통한 이미지 다운로드
  - SQLite(Android 내장) 기반 설정, 즐겨찾기, 캐시, 기록 관리

## 빌드 방법

### 1. Go 코어 빌드

```bash
cd core
gomobile bind -target=android -androidapi=26 -o ../app/libs/core.aar .
cd ..
```

### 2. Android APK 빌드

디버그 APK:

```bash
./gradlew assembleDebug
```

릴리즈 APK:

```bash
./gradlew assembleRelease
```

빌드된 APK는 `app/build/outputs/apk/release/app-release.apk`에 생성됩니다.
