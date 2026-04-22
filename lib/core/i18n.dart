import 'package:flutter/material.dart';

enum LKey {
  appTitle,
  appSubtitle,
  commonHome,
  commonFavorites,
  commonHistory,
  commonSettings,
  commonCancel,
  commonDelete,
  commonNa,
  commonPages,
  commonRead,
  searchHint,
  searchFoundResults,
  searchNoResults,
  settingsAppearance,
  settingsBrowsing,
  settingsReader,
  settingsDataManagement,
  settingsBackupRestore,
  settingsAbout,
  settingsAppLanguage,
  settingsTheme,
  settingsThemeSystem,
  settingsThemeLight,
  settingsThemeDark,
  settingsThemeOled,
  settingsListingMode,
  settingsListingScroll,
  settingsListingPagination,
  settingsCardStyle,
  settingsCardThumbnail,
  settingsCardDetailed,
  settingsDefaultLang,
  settingsDefaultLangDesc,
  settingsReaderMode,
  settingsReaderWebtoon,
  settingsReaderVertical,
  settingsReaderHorizontal,
  settingsReaderDoublePage,
  settingsDoublePageOrder,
  settingsDoublePageJapanese,
  settingsDoublePageInternational,
  settingsPageTurnDirection,
  settingsPageTurnLeft,
  settingsPageTurnRight,
  settingsClearCache,
  settingsClearCacheDesc,
  settingsClearCacheTitle,
  settingsClearCacheBody,
  settingsCacheCleared,
  settingsResetApp,
  settingsResetAppDesc,
  settingsResetAppTitle,
  settingsResetAppBody,
  settingsResetSuccess,
  settingsExportFavs,
  settingsImportFavs,
  settingsExportSuccess,
  settingsImportSuccess,
  galleryFailedLoad,
  galleryArtist,
  galleryGroup,
  galleryAddedFav,
  galleryRemovedFav,
  galleryInfo,
  galleryCopyId,
  galleryIdCopied,
  galleryType,
  galleryLanguage,
  gallerySeries,
  galleryCharacters,
  galleryTags,
  pageJumpTitle,
  pageJumpHint,
  pageJumpInvalid,
  favDeleteTitle,
  favDeleteBody,
  historyClearTitle,
  historyClearBody,
  langKorean,
  langEnglish,
  langJapanese,
  langChinese,
  langAll,
}

class L {
  final Locale locale;
  L(this.locale);

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const Map<String, Map<LKey, String>> _localizedValues = {
    'en': {
      LKey.appTitle: 'Donggong',
      LKey.appSubtitle: 'Modern Hitomi Reader',
      LKey.commonHome: 'Home',
      LKey.commonFavorites: 'Favorites',
      LKey.commonHistory: 'History',
      LKey.commonSettings: 'Settings',
      LKey.commonCancel: 'Cancel',
      LKey.commonDelete: 'Delete',
      LKey.commonNa: 'N/A',
      LKey.commonPages: 'Pages',
      LKey.commonRead: 'Read',
      LKey.searchHint: 'Search...',
      LKey.searchFoundResults: 'Found {} results',
      LKey.searchNoResults: 'No results found',
      LKey.settingsAppearance: 'Appearance',
      LKey.settingsBrowsing: 'Browsing',
      LKey.settingsReader: 'Reader',
      LKey.settingsDataManagement: 'Data Management',
      LKey.settingsBackupRestore: 'Backup & Restore',
      LKey.settingsAbout: 'About',
      LKey.settingsAppLanguage: 'App Language',
      LKey.settingsTheme: 'Theme',
      LKey.settingsThemeSystem: 'System',
      LKey.settingsThemeLight: 'Light',
      LKey.settingsThemeDark: 'Dark',
      LKey.settingsThemeOled: 'OLED Dark',
      LKey.settingsListingMode: 'Listing Mode',
      LKey.settingsListingScroll: 'Infinite Scroll',
      LKey.settingsListingPagination: 'Pagination',
      LKey.settingsCardStyle: 'Card Style',
      LKey.settingsCardThumbnail: 'Thumbnail',
      LKey.settingsCardDetailed: 'Detailed',
      LKey.settingsDefaultLang: 'Content Language',
      LKey.settingsDefaultLangDesc: 'Preferred language for gallery lists',
      LKey.settingsReaderMode: 'Viewer Mode',
      LKey.settingsReaderWebtoon: 'Webtoon',
      LKey.settingsReaderVertical: 'Vertical Page',
      LKey.settingsReaderHorizontal: 'Horizontal Page',
      LKey.settingsReaderDoublePage: 'Two-Page View',
      LKey.settingsDoublePageOrder: 'Two-Page Order',
      LKey.settingsDoublePageJapanese: 'Japanese (Right to Left)',
      LKey.settingsDoublePageInternational: 'International (Left to Right)',
      LKey.settingsPageTurnDirection: 'Page Turn Direction',
      LKey.settingsPageTurnLeft: 'Swipe Left',
      LKey.settingsPageTurnRight: 'Swipe Right',
      LKey.settingsClearCache: 'Clear Cache',
      LKey.settingsClearCacheDesc: 'Remove temporary images',
      LKey.settingsClearCacheTitle: 'Clear Cache?',
      LKey.settingsClearCacheBody: 'This will delete all cached image files.',
      LKey.settingsCacheCleared: 'Cache cleared successfully',
      LKey.settingsResetApp: 'Reset All Data',
      LKey.settingsResetAppDesc: 'Wipe favorites, history, and settings',
      LKey.settingsResetAppTitle: 'Reset Everything?',
      LKey.settingsResetAppBody:
          'This action is permanent. Your favorites and settings will be lost.',
      LKey.settingsResetSuccess: 'All app data has been reset',
      LKey.settingsExportFavs: 'Export Favorites',
      LKey.settingsImportFavs: 'Import Favorites',
      LKey.settingsExportSuccess: 'Backup saved successfully',
      LKey.settingsImportSuccess: 'Favorites restored successfully',
      LKey.galleryFailedLoad: 'Failed to load content',
      LKey.galleryArtist: 'Artist',
      LKey.galleryGroup: 'Group',
      LKey.galleryAddedFav: 'Added to favorites',
      LKey.galleryRemovedFav: 'Removed from favorites',
      LKey.galleryInfo: 'Information',
      LKey.galleryCopyId: 'Copy ID',
      LKey.galleryIdCopied: 'ID copied to clipboard',
      LKey.galleryType: 'Type',
      LKey.galleryLanguage: 'Language',
      LKey.gallerySeries: 'Series',
      LKey.galleryCharacters: 'Characters',
      LKey.galleryTags: 'Tags',
      LKey.pageJumpTitle: 'Jump to Page',
      LKey.pageJumpHint: 'Page number (1-{})',
      LKey.pageJumpInvalid: 'Invalid page number',
      LKey.favDeleteTitle: 'Remove Favorite',
      LKey.favDeleteBody: 'Do you want to remove "{}" from favorites?',
      LKey.historyClearTitle: 'Clear History?',
      LKey.historyClearBody: 'All viewing history will be deleted.',
      LKey.langKorean: 'Korean',
      LKey.langEnglish: 'English',
      LKey.langJapanese: 'Japanese',
      LKey.langChinese: 'Chinese',
      LKey.langAll: 'All',
    },
    'ko': {
      LKey.appTitle: '동공',
      LKey.appSubtitle: '가벼운 hitomi.la 리더',
      LKey.commonHome: '홈',
      LKey.commonFavorites: '즐겨찾기',
      LKey.commonHistory: '기록',
      LKey.commonSettings: '설정',
      LKey.commonCancel: '취소',
      LKey.commonDelete: '삭제',
      LKey.commonNa: 'N/A',
      LKey.commonPages: '페이지',
      LKey.commonRead: '읽기',
      LKey.searchHint: '검색...',
      LKey.searchFoundResults: '총 {}개 결과',
      LKey.searchNoResults: '검색 결과가 없습니다',
      LKey.settingsAppearance: '화면 설정',
      LKey.settingsBrowsing: '탐색 설정',
      LKey.settingsReader: '리더 설정',
      LKey.settingsDataManagement: '데이터 관리',
      LKey.settingsBackupRestore: '백업 및 복구',
      LKey.settingsAbout: '정보',
      LKey.settingsAppLanguage: '앱 언어',
      LKey.settingsTheme: '테마',
      LKey.settingsThemeSystem: '시스템 설정',
      LKey.settingsThemeLight: '라이트 모드',
      LKey.settingsThemeDark: '다크 모드',
      LKey.settingsThemeOled: 'OLED 다크',
      LKey.settingsListingMode: '목록 표시 방식',
      LKey.settingsListingScroll: '스크롤 보기',
      LKey.settingsListingPagination: '페이지 보기',
      LKey.settingsCardStyle: '카드 스타일',
      LKey.settingsCardThumbnail: '썸네일 위주',
      LKey.settingsCardDetailed: '정보 위주',
      LKey.settingsDefaultLang: '콘텐츠 언어',
      LKey.settingsDefaultLangDesc: '볼 작품의 언어 (리스트, 검색 시 사용)',
      LKey.settingsReaderMode: '보기 방식',
      LKey.settingsReaderWebtoon: '웹툰(연속) 보기',
      LKey.settingsReaderVertical: '세로 넘기기',
      LKey.settingsReaderHorizontal: '가로 넘기기',
      LKey.settingsReaderDoublePage: '두쪽 보기',
      LKey.settingsDoublePageOrder: '두 쪽 순서',
      LKey.settingsDoublePageJapanese: '일본식 (우 -> 좌)',
      LKey.settingsDoublePageInternational: '국제식 (좌 -> 우)',
      LKey.settingsPageTurnDirection: '넘김 방향',
      LKey.settingsPageTurnLeft: '왼쪽 넘김',
      LKey.settingsPageTurnRight: '오른쪽 넘김',
      LKey.settingsClearCache: '캐시 삭제',
      LKey.settingsClearCacheDesc: '임시 저장한 이미지를 삭제합니다.',
      LKey.settingsClearCacheTitle: '캐시를 삭제하시겠습니까?',
      LKey.settingsClearCacheBody: '모든 이미지 캐시 파일이 삭제됩니다.',
      LKey.settingsCacheCleared: '캐시가 삭제되었습니다.',
      LKey.settingsResetApp: '앱 데이터 초기화',
      LKey.settingsResetAppDesc: '즐겨찾기, 기록, 설정을 모두 삭제합니다.',
      LKey.settingsResetAppTitle: '데이터를 초기화하시겠습니까?',
      LKey.settingsResetAppBody: '이 작업은 되돌릴 수 없습니다. 모든 즐겨찾기와 설정이 삭제됩니다.',
      LKey.settingsResetSuccess: '앱 데이터가 초기화되었습니다.',
      LKey.settingsExportFavs: '즐겨찾기 내보내기',
      LKey.settingsImportFavs: '즐겨찾기 가져오기',
      LKey.settingsExportSuccess: '백업 파일이 저장되었습니다.',
      LKey.settingsImportSuccess: '즐겨찾기를 성공적으로 복구했습니다.',
      LKey.galleryFailedLoad: '불러오기에 실패했습니다.',
      LKey.galleryArtist: '작가',
      LKey.galleryGroup: '그룹',
      LKey.galleryAddedFav: '즐겨찾기에 추가되었습니다.',
      LKey.galleryRemovedFav: '즐겨찾기에서 제거되었습니다.',
      LKey.galleryInfo: '상세 정보',
      LKey.galleryCopyId: 'ID 복사',
      LKey.galleryIdCopied: 'ID가 복사되었습니다.',
      LKey.galleryType: '유형',
      LKey.galleryLanguage: '언어',
      LKey.gallerySeries: '시리즈',
      LKey.galleryCharacters: '캐릭터',
      LKey.galleryTags: '태그',
      LKey.pageJumpTitle: '페이지 이동',
      LKey.pageJumpHint: '페이지 번호 (1-{})',
      LKey.pageJumpInvalid: '잘못된 페이지 번호입니다.',
      LKey.favDeleteTitle: '즐겨찾기 삭제',
      LKey.favDeleteBody: '"{}" 항목을 즐겨찾기에서 삭제하시겠습니까?',
      LKey.historyClearTitle: '기록 삭제',
      LKey.historyClearBody: '모든 감상 기록이 삭제됩니다.',
      LKey.langKorean: '한국어',
      LKey.langEnglish: '영어',
      LKey.langJapanese: '일본어',
      LKey.langChinese: '중국어',
      LKey.langAll: '전체',
    },
  };

  String get(LKey key, [List<String>? args]) {
    String value =
        _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key] ??
        key.name;
    if (args != null && args.isNotEmpty) {
      for (final arg in args) {
        value = value.replaceFirst('{}', arg);
      }
    }
    return value;
  }

  String get home => get(LKey.commonHome);
  String get favorites => get(LKey.commonFavorites);
  String get history => get(LKey.commonHistory);
  String get settings => get(LKey.commonSettings);
  String get cancel => get(LKey.commonCancel);
  String get delete => get(LKey.commonDelete);
  String get na => get(LKey.commonNa);
  String get pages => get(LKey.commonPages);
  String get read => get(LKey.commonRead);

  String get appTitle => get(LKey.appTitle);
  String get appSubtitle => get(LKey.appSubtitle);

  String get searchHint => get(LKey.searchHint);
  String foundResults(int count) =>
      get(LKey.searchFoundResults, [count.toString()]);
  String get noResults => get(LKey.searchNoResults);

  String get appearance => get(LKey.settingsAppearance);
  String get browsing => get(LKey.settingsBrowsing);
  String get reader => get(LKey.settingsReader);
  String get dataManagement => get(LKey.settingsDataManagement);
  String get backupRestore => get(LKey.settingsBackupRestore);
  String get about => get(LKey.settingsAbout);

  String get appLanguage => get(LKey.settingsAppLanguage);
  String get theme => get(LKey.settingsTheme);
  String get themeSystem => get(LKey.settingsThemeSystem);
  String get themeLight => get(LKey.settingsThemeLight);
  String get themeDark => get(LKey.settingsThemeDark);
  String get themeOled => get(LKey.settingsThemeOled);

  String get listingMode => get(LKey.settingsListingMode);
  String get infiniteScroll => get(LKey.settingsListingScroll);
  String get pagination => get(LKey.settingsListingPagination);
  String get cardStyle => get(LKey.settingsCardStyle);
  String get thumbnail => get(LKey.settingsCardThumbnail);
  String get detailed => get(LKey.settingsCardDetailed);
  String get defaultLanguage => get(LKey.settingsDefaultLang);
  String get defaultLanguageDesc => get(LKey.settingsDefaultLangDesc);

  String get readerMode => get(LKey.settingsReaderMode);
  String get webtoon => get(LKey.settingsReaderWebtoon);
  String get verticalPage => get(LKey.settingsReaderVertical);
  String get horizontalPage => get(LKey.settingsReaderHorizontal);
  String get doublePage => get(LKey.settingsReaderDoublePage);
  String get doublePageOrder => get(LKey.settingsDoublePageOrder);
  String get doublePageJapanese => get(LKey.settingsDoublePageJapanese);
  String get doublePageInternational =>
      get(LKey.settingsDoublePageInternational);
  String get pageTurnDirection => get(LKey.settingsPageTurnDirection);
  String get pageTurnLeft => get(LKey.settingsPageTurnLeft);
  String get pageTurnRight => get(LKey.settingsPageTurnRight);

  String get clearCache => get(LKey.settingsClearCache);
  String get clearCacheDesc => get(LKey.settingsClearCacheDesc);
  String get clearCacheTitle => get(LKey.settingsClearCacheTitle);
  String get clearCacheBody => get(LKey.settingsClearCacheBody);
  String get cacheCleared => get(LKey.settingsCacheCleared);

  String get resetApp => get(LKey.settingsResetApp);
  String get resetAppDesc => get(LKey.settingsResetAppDesc);
  String get resetAppTitle => get(LKey.settingsResetAppTitle);
  String get resetAppBody => get(LKey.settingsResetAppBody);
  String get resetSuccess => get(LKey.settingsResetSuccess);

  String get exportFavorites => get(LKey.settingsExportFavs);
  String get importFavorites => get(LKey.settingsImportFavs);
  String get exportSuccess => get(LKey.settingsExportSuccess);
  String get importSuccess => get(LKey.settingsImportSuccess);

  String get galleryFailedLoad => get(LKey.galleryFailedLoad);
  String get artist => get(LKey.galleryArtist);
  String get group => get(LKey.galleryGroup);
  String get addedToFav => get(LKey.galleryAddedFav);
  String get removedFromFav => get(LKey.galleryRemovedFav);
  String get galleryInfo => get(LKey.galleryInfo);
  String get galleryCopyId => get(LKey.galleryCopyId);
  String get galleryIdCopied => get(LKey.galleryIdCopied);
  String get galleryType => get(LKey.galleryType);
  String get galleryLanguage => get(LKey.galleryLanguage);
  String get gallerySeries => get(LKey.gallerySeries);
  String get galleryCharacters => get(LKey.galleryCharacters);
  String get galleryTags => get(LKey.galleryTags);

  String get pageJumpTitle => get(LKey.pageJumpTitle);
  String pageJumpHint(int max) => get(LKey.pageJumpHint, [max.toString()]);
  String get pageJumpInvalid => get(LKey.pageJumpInvalid);

  String get favDeleteTitle => get(LKey.favDeleteTitle);
  String favDeleteBody(String name) => get(LKey.favDeleteBody, [name]);

  String get historyClearTitle => get(LKey.historyClearTitle);
  String get historyClearBody => get(LKey.historyClearBody);

  String get langKorean => get(LKey.langKorean);
  String get langEnglish => get(LKey.langEnglish);
  String get langJapanese => get(LKey.langJapanese);
  String get langChinese => get(LKey.langChinese);
  String get langAll => get(LKey.langAll);
}

class LDelegate extends LocalizationsDelegate<L> {
  const LDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ko'].contains(locale.languageCode);

  @override
  Future<L> load(Locale locale) async => L(locale);

  @override
  bool shouldReload(LDelegate old) => false;
}
