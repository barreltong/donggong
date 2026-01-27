import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import 'home.dart';
import 'reader.dart';
import 'settings.dart';
import 'favorites.dart';
import 'history.dart';

class DonggongApp extends StatelessWidget {
  const DonggongApp({super.key});

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [AppState.instance.themeModeKey, AppState.instance.appLanguage]),
      builder: (context, _) {
        final themeModeKey = AppState.instance.themeModeKey.value;

        ThemeMode themeMode;
        if (themeModeKey == 'light') {
          themeMode = ThemeMode.light;
        } else if (themeModeKey == 'dark' || themeModeKey == 'oled') {
          themeMode = ThemeMode.dark;
        } else {
          themeMode = ThemeMode.system;
        }

        final isOled = themeModeKey == 'oled' ||
            (themeModeKey == 'system' &&
                MediaQuery.platformBrightnessOf(context) == Brightness.dark);

        // Strictly Neutral / Zinc scale (No Blue/Navy cast)
        const gray50 = Color(0xFFFAFAFA);
        const gray100 = Color(0xFFF5F5F5);
        const gray200 = Color(0xFFE5E5E5);
        const gray300 = Color(0xFFD4D4D4);
        const gray400 = Color(0xFFA3A3A3);
        const gray600 = Color(0xFF525252);
        const gray700 = Color(0xFF404040);
        const gray800 = Color(0xFF262626);
        const gray900 = Color(0xFF171717);
        const gray950 = Color(0xFF0A0A0A);
        const gray1000 = Color(0xFF000000); // OLED Black

        return MaterialApp(
          title: 'Donggong',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: messengerKey,
          themeMode: themeMode,
          locale: Locale(AppState.instance.appLanguage.value),
          localizationsDelegates: const [
            LDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ko'),
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.light(
              surface: gray100, // Light gray scaffold for contrast against white cards
              onSurface: gray950,
              surfaceContainer: Colors.white, // Pure white cards for elevation pop
              surfaceContainerHigh: gray100,
              surfaceContainerHighest: gray200,
              primary: gray900,
              onPrimary: gray50,
              secondary: gray600,
              onSecondary: gray50,
              secondaryContainer: gray200.withValues(alpha: 0.5),
              onSecondaryContainer: gray800,
              outline: gray300,
              outlineVariant: gray200,
            ),
            scaffoldBackgroundColor: gray100,
            appBarTheme: AppBarTheme(
              centerTitle: false,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: gray900),
              titleTextStyle: TextStyle(
                  color: gray950, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            cardTheme: CardThemeData(
              elevation: 2, 
              shadowColor: Colors.black.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: gray950, fontWeight: FontWeight.w500),
              bodyMedium: TextStyle(color: gray900),
              bodySmall: TextStyle(color: gray700),
              titleLarge: TextStyle(color: gray950, fontWeight: FontWeight.bold),
              titleMedium: TextStyle(color: gray950, fontWeight: FontWeight.w600),
              titleSmall: TextStyle(color: gray900, fontWeight: FontWeight.bold),
              labelLarge: TextStyle(color: gray900),
              labelMedium: TextStyle(color: gray800, fontWeight: FontWeight.w500),
              labelSmall: TextStyle(color: gray700, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              surface: isOled ? gray1000 : gray950,
              onSurface: gray50,
              onSurfaceVariant: gray200, // Significantly brighter for visibility
              surfaceContainer: isOled ? gray950 : gray900,
              surfaceContainerHigh: isOled ? gray900 : gray800,
              surfaceContainerHighest: isOled ? gray800 : gray700,
              primary: gray300,
              onPrimary: gray1000,
              secondary: gray400,
              onSecondary: gray1000,
              secondaryContainer:
                  isOled ? gray950 : gray900, // Even more subtle
              onSecondaryContainer: gray400, // Muted icon color for buttons
              outline: gray700,
              outlineVariant: gray800,
              error: const Color(0xFFEF4444),
            ),
            scaffoldBackgroundColor: isOled ? gray1000 : gray950,
            appBarTheme: AppBarTheme(
              centerTitle: false,
              scrolledUnderElevation: 0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: gray200),
              titleTextStyle: TextStyle(
                  color: gray50, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: gray50),
              bodyMedium: TextStyle(color: gray100),
              bodySmall: TextStyle(color: gray200),
              titleLarge: TextStyle(color: gray50),
              titleMedium: TextStyle(color: gray50),
              titleSmall: TextStyle(color: gray100),
              labelLarge: TextStyle(color: gray100),
              labelMedium: TextStyle(color: gray200),
              labelSmall: TextStyle(color: gray300),
            ),
          ),
          home: const HomeScreen(),
          routes: {
            '/settings': (context) => const SettingsScreen(),
            '/favorites': (context) => const FavoritesScreen(),
            '/history': (context) => const HistoryScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/reader') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => ReaderScreen(galleryId: args['id'] as int),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
