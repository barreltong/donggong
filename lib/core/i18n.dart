import 'package:flutter/material.dart';

class L {
  final Locale locale;
  L(this.locale);

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const _localizedValues = {
    'en': {
      // General
      'app_title': 'Donggong',
      'app_subtitle': 'Modern Hitomi Reader',
      'common_home': 'Home',
      'common_favorites': 'Favorites',
      'common_history': 'History',
      'common_settings': 'Settings',
      'common_cancel': 'Cancel',
      'common_delete': 'Delete',
      'common_na': 'N/A',
      'common_pages': 'Pages',
      'common_read': 'Read',

      // Search
      'search_hint': 'Search...',
      'search_found_results': 'Found {} results',
      'search_no_results': 'No results found',

      // Settings Sections
      'settings_appearance': 'Appearance',
      'settings_browsing': 'Browsing',
      'settings_reader': 'Reader',
      'settings_data_management': 'Data Management',
      'settings_backup_restore': 'Backup & Restore',
      'settings_about': 'About',

      // Appearance Settings
      'settings_app_language': 'App Language',
      'settings_theme': 'Theme',
      'settings_theme_system': 'System',
      'settings_theme_light': 'Light',
      'settings_theme_dark': 'Dark',
      'settings_theme_oled': 'OLED Dark',

      // Browsing Settings
      'settings_listing_mode': 'Listing Mode',
      'settings_listing_scroll': 'Infinite Scroll',
      'settings_listing_pagination': 'Pagination',
      'settings_card_style': 'Card Style',
      'settings_card_thumbnail': 'Thumbnail',
      'settings_card_detailed': 'Detailed',
      'settings_default_lang': 'Content Language',
      'settings_default_lang_desc': 'Preferred language for gallery lists',

      // Reader Settings
      'settings_reader_mode': 'Viewer Mode',
      'settings_reader_webtoon': 'Webtoon',
      'settings_reader_vertical': 'Vertical Page',
      'settings_reader_horizontal': 'Horizontal Page',

      // Data Management
      'settings_clear_cache': 'Clear Cache',
      'settings_clear_cache_desc': 'Remove temporary images',
      'settings_clear_cache_title': 'Clear Cache?',
      'settings_clear_cache_body': 'This will delete all cached image files.',
      'settings_cache_cleared': 'Cache cleared successfully',

      'settings_reset_app': 'Reset All Data',
      'settings_reset_app_desc': 'Wipe favorites, history, and settings',
      'settings_reset_app_title': 'Reset Everything?',
      'settings_reset_app_body':
          'This action is permanent. Your favorites and settings will be lost.',
      'settings_reset_success': 'All app data has been reset',

      // Backup & Restore
      'settings_export_favs': 'Export Favorites',
      'settings_import_favs': 'Import Favorites',
      'settings_export_success': 'Backup saved successfully',
      'settings_import_success': 'Favorites restored successfully',

      // Gallery / Reader
      'gallery_failed_load': 'Failed to load content',
      'gallery_artist': 'Artist',
      'gallery_group': 'Group',
      'gallery_added_fav': 'Added to favorites',
      'gallery_removed_fav': 'Removed from favorites',
      'gallery_info': 'Information',
      'gallery_copy_id': 'Copy ID',
      'gallery_id_copied': 'ID copied to clipboard',
      'gallery_type': 'Type',
      'gallery_language': 'Language',
      'gallery_series': 'Series',
      'gallery_characters': 'Characters',
      'gallery_tags': 'Tags',

      // Page Jump
      'page_jump_title': 'Jump to Page',
      'page_jump_hint': 'Page number (1-{})',
      'page_jump_invalid': 'Invalid page number',

      // Favorites Deletion
      'fav_delete_title': 'Remove Favorite',
      'fav_delete_body': 'Do you want to remove "{}" from favorites?',

      // History Deletion
      'history_clear_title': 'Clear History?',
      'history_clear_body': 'All viewing history will be deleted.',

      // Languages
      'lang_korean': 'Korean',
      'lang_english': 'English',
      'lang_japanese': 'Japanese',
      'lang_chinese': 'Chinese',
      'lang_all': 'All',
    },
    'ko': {
      // 일반
      'app_title': '동-공',
      'app_subtitle': '가벼운 hitomi.la 리더',
      'common_home': '홈',
      'common_favorites': '즐겨찾기',
      'common_history': '기록',
      'common_settings': '설정',
      'common_cancel': '취소',
      'common_delete': '삭제',
      'common_na': 'N/A',
      'common_pages': '페이지',
      'common_read': '읽기',

      // 검색
      'search_hint': '검색...',
      'search_found_results': '총 {}개 결과 로드됨.',
      'search_no_results': '검색 결과가 없습니다',

      // 설정 섹션
      'settings_appearance': '화면 설정',
      'settings_browsing': '탐색 설정',
      'settings_reader': '리더 설정',
      'settings_data_management': '데이터 관리',
      'settings_backup_restore': '백업 및 복구',
      'settings_about': '정보',

      // 화면 설정
      'settings_app_language': '앱 언어',
      'settings_theme': '테마',
      'settings_theme_system': '시스템 설정',
      'settings_theme_light': '라이트 모드',
      'settings_theme_dark': '다크 모드',
      'settings_theme_oled': 'OLED 다크',

      // 탐색 설정
      'settings_listing_mode': '목록 표시 방식',
      'settings_listing_scroll': '스크롤 보기',
      'settings_listing_pagination': '페이지 보기',
      'settings_card_style': '카드 스타일',
      'settings_card_thumbnail': '미리보기 위주',
      'settings_card_detailed': '정보 위주',
      'settings_default_lang': '콘텐츠 언어',
      'settings_default_lang_desc': '볼 작품의 언어 (리스트, 검색 시 사용)',

      // 리더 설정
      'settings_reader_mode': '보기 방식',
      'settings_reader_webtoon': '웹툰(연속) 보기',
      'settings_reader_vertical': '세로 넘기기',
      'settings_reader_horizontal': '가로 넘기기',

      // 데이터 관리
      'settings_clear_cache': '캐시 삭제',
      'settings_clear_cache_desc': '임시 저장된 이미지를 삭제합니다.',
      'settings_clear_cache_title': '캐시를 삭제하시겠습니까?',
      'settings_clear_cache_body': '모든 이미지 캐시 파일이 삭제됩니다.',
      'settings_cache_cleared': '캐시가 삭제되었습니다.',

      'settings_reset_app': '앱 데이터 초기화',
      'settings_reset_app_desc': '즐겨찾기, 기록, 설정을 모두 삭제합니다.',
      'settings_reset_app_title': '데이터를 초기화하시겠습니까?',
      'settings_reset_app_body': '이 작업은 되돌릴 수 없습니다. 모든 즐겨찾기와 설정이 삭제됩니다.',
      'settings_reset_success': '앱 데이터가 초기화되었습니다.',

      // 백업 및 복구
      'settings_export_favs': '즐겨찾기 내보내기',
      'settings_import_favs': '즐겨찾기 가져오기',
      'settings_export_success': '백업 파일이 저장되었습니다.',
      'settings_import_success': '즐겨찾기를 성공적으로 복구했습니다.',

      // 갤러리 / 리더
      'gallery_failed_load': '불러오기에 실패했습니다.',
      'gallery_artist': '작가',
      'gallery_group': '그룹',
      'gallery_added_fav': '즐겨찾기에 추가되었습니다.',
      'gallery_removed_fav': '즐겨찾기에서 제거되었습니다.',
      'gallery_info': '상세 정보',
      'gallery_copy_id': 'ID 복사',
      'gallery_id_copied': 'ID가 복사되었습니다',
      'gallery_type': '유형',
      'gallery_language': '언어',
      'gallery_series': '시리즈',
      'gallery_characters': '캐릭터',
      'gallery_tags': '태그',

      // 페이지 이동
      'page_jump_title': '페이지 이동',
      'page_jump_hint': '페이지 번호 (1-{})',
      'page_jump_invalid': '잘못된 페이지 번호입니다.',

      // 즐겨찾기 삭제
      'fav_delete_title': '즐겨찾기 삭제',
      'fav_delete_body': '"{}" 항목을 즐겨찾기에서 삭제하시겠습니까?',

      // 기록 삭제
      'history_clear_title': '기록 삭제',
      'history_clear_body': '모든 감상 기록이 삭제됩니다.',

      // 언어 이름
      'lang_korean': '한국어',
      'lang_english': '영어',
      'lang_japanese': '일본어',
      'lang_chinese': '중국어',
      'lang_all': '전체',
    },
  };

  String get(String key, [List<String>? args]) {
    String value =
        _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']![key] ??
        key;
    if (args != null && args.isNotEmpty) {
      for (var arg in args) {
        value = value.replaceFirst('{}', arg);
      }
    }
    return value;
  }

  // Common
  String get home => get('common_home');
  String get favorites => get('common_favorites');
  String get history => get('common_history');
  String get settings => get('common_settings');
  String get cancel => get('common_cancel');
  String get delete => get('common_delete');
  String get na => get('common_na');
  String get pages => get('common_pages');
  String get read => get('common_read');

  // App Meta
  String get appTitle => get('app_title');
  String get appSubtitle => get('app_subtitle');

  // Search
  String get searchHint => get('search_hint');
  String foundResults(int count) =>
      get('search_found_results', [count.toString()]);
  String get noResults => get('search_no_results');

  // Settings UI
  String get appearance => get('settings_appearance');
  String get browsing => get('settings_browsing');
  String get reader => get('settings_reader');
  String get dataManagement => get('settings_data_management');
  String get backupRestore => get('settings_backup_restore');
  String get about => get('settings_about');

  String get appLanguage => get('settings_app_language');
  String get theme => get('settings_theme');
  String get themeSystem => get('settings_theme_system');
  String get themeLight => get('settings_theme_light');
  String get themeDark => get('settings_theme_dark');
  String get themeOled => get('settings_theme_oled');

  String get listingMode => get('settings_listing_mode');
  String get infiniteScroll => get('settings_listing_scroll');
  String get pagination => get('settings_listing_pagination');
  String get cardStyle => get('settings_card_style');
  String get thumbnail => get('settings_card_thumbnail');
  String get detailed => get('settings_card_detailed');
  String get defaultLanguage => get('settings_default_lang');
  String get defaultLanguageDesc => get('settings_default_lang_desc');

  String get readerMode => get('settings_reader_mode');
  String get webtoon => get('settings_reader_webtoon');
  String get verticalPage => get('settings_reader_vertical');
  String get horizontalPage => get('settings_reader_horizontal');

  String get clearCache => get('settings_clear_cache');
  String get clearCacheDesc => get('settings_clear_cache_desc');
  String get clearCacheTitle => get('settings_clear_cache_title');
  String get clearCacheBody => get('settings_clear_cache_body');
  String get cacheCleared => get('settings_cache_cleared');

  String get resetApp => get('settings_reset_app');
  String get resetAppDesc => get('settings_reset_app_desc');
  String get resetAppTitle => get('settings_reset_app_title');
  String get resetAppBody => get('settings_reset_app_body');
  String get resetSuccess => get('settings_reset_success');

  String get exportFavorites => get('settings_export_favs');
  String get importFavorites => get('settings_import_favs');
  String get exportSuccess => get('settings_export_success');
  String get importSuccess => get('settings_import_success');

  // Gallery
  String get galleryFailedLoad => get('gallery_failed_load');
  String get artist => get('gallery_artist');
  String get group => get('gallery_group');
  String get addedToFav => get('gallery_added_fav');
  String get removedFromFav => get('gallery_removed_fav');
  String get galleryInfo => get('gallery_info');
  String get galleryCopyId => get('gallery_copy_id');
  String get galleryIdCopied => get('gallery_id_copied');
  String get galleryType => get('gallery_type');
  String get galleryLanguage => get('gallery_language');
  String get gallerySeries => get('gallery_series');
  String get galleryCharacters => get('gallery_characters');
  String get galleryTags => get('gallery_tags');

  String get pageJumpTitle => get('page_jump_title');
  String pageJumpHint(int max) => get('page_jump_hint', [max.toString()]);
  String get pageJumpInvalid => get('page_jump_invalid');

  String get favDeleteTitle => get('fav_delete_title');
  String favDeleteBody(String name) => get('fav_delete_body', [name]);

  String get historyClearTitle => get('history_clear_title');
  String get historyClearBody => get('history_clear_body');

  // Languages
  String get langKorean => get('lang_korean');
  String get langEnglish => get('lang_english');
  String get langJapanese => get('lang_japanese');
  String get langChinese => get('lang_chinese');
  String get langAll => get('lang_all');
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
