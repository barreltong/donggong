# 동공 (Donggong)

`hitomi.la`용 Flutter 리더 앱입니다. 탐색, 검색, 즐겨찾기, 기록, 다양한 리더 모드, Android 사이드로드 OTA 업데이트를 지원합니다.

## 주요 기능

- 홈 목록에서 무한 스크롤과 페이지네이션을 모두 지원
- `artist:`, `female:`, `male:`, `group:`, `character:` 등 태그 기반 검색
- 검색 추천 오버레이, 최근 검색 즉시 실행, 즐겨찾기 태그 빠른 추가
- 작품 상세/리더 화면에서 바로 즐겨찾기 토글
- 리더 모드 지원
  - 웹툰 보기
  - 세로 페이지 보기
  - 가로 페이지 보기
  - 두 쪽 보기
- 두 쪽 보기 옵션 지원
  - 일본식 우→좌 순서
  - 국제식 좌→우 순서
  - 페이지 넘김 방향 좌/우 선택
- 즐겨찾기 JSON 내보내기/가져오기
- 기록 관리
- GitHub Release 기반 Android 사이드로드 OTA 업데이트

## 리더 동작

- 두 쪽 보기는 페이지 사이 갭 없이 렌더링되도록 조정되어 있습니다.
- 리더 상단에서 두 쪽 보기 순서와 페이지 넘김 방향을 바로 바꿀 수 있습니다.
- 검색/탭/오버레이 상호작용은 중복 입력과 비동기 경쟁 상태를 줄이도록 정리되어 있습니다.

## OTA 업데이트

현재 OTA는 Android 사이드로드 배포를 기준으로 동작합니다.

- 설정의 `App Update`에서 최신 GitHub Release를 확인합니다.
- 새 버전이 있으면 APK를 다운로드하고 설치 화면을 엽니다.
- 처음 설치 시 Android의 `이 앱에서 설치 허용` 권한이 필요할 수 있습니다.
- GitHub Release에는 `.apk` asset이 포함되어 있어야 합니다.

## 자동 릴리즈

`.github/workflows/release.yml`이 태그 푸시를 감지해 자동으로 릴리즈를 생성합니다.

- 트리거: `v*` 태그 푸시
- 작업:
  - Flutter release APK 빌드
  - `donggong-<tag>.apk` 생성
  - 같은 이름의 GitHub Release 생성
  - APK asset 첨부

예시:

```bash
git tag v2.2.0
git push origin v2.2.0
```

## 개발

```bash
flutter pub get
flutter analyze
flutter run
```

Android release APK 빌드:

```bash
flutter build apk --release
```
