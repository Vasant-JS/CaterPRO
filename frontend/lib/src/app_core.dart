part of '../main.dart';

final appPreferences = AppPreferencesController();
final downloadHistory = DownloadHistoryController();
const downloadChannel = MethodChannel('caterpro/downloads');

class CaterProApp extends StatefulWidget {
  const CaterProApp({super.key});

  @override
  State<CaterProApp> createState() => _CaterProAppState();
}

class _CaterProAppState extends State<CaterProApp> {
  @override
  void initState() {
    super.initState();
    appPreferences.load();
    downloadHistory.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appPreferences,
      builder: (context, _) {
        final settings = appPreferences.value;
        final textTheme = settings.textTheme();
        final lightScheme = ColorScheme.fromSeed(
          seedColor: Cp.primary,
          brightness: Brightness.light,
          primary: Cp.primary,
          onPrimary: Colors.white,
          primaryContainer: Cp.primaryContainer,
          onPrimaryContainer: Colors.white,
          secondary: Cp.secondary,
          onSecondary: Colors.white,
          secondaryContainer: Cp.secondaryContainer,
          onSecondaryContainer: const Color(0xff4e6c4b),
          tertiary: Cp.tertiary,
          onTertiary: Colors.white,
          tertiaryContainer: Cp.tertiaryContainer,
          onTertiaryContainer: const Color(0xff44410d),
          surface: Cp.surface,
          onSurface: Cp.onSurface,
          surfaceContainerLowest: Cp.card,
          surfaceContainerLow: Cp.surfaceLow,
          surfaceContainerHigh: Cp.surfaceHigh,
          surfaceContainerHighest: Cp.surfaceHigh,
          onSurfaceVariant: Cp.onVariant,
          outline: Cp.outline,
          outlineVariant: Cp.outlineVariant,
          error: Cp.error,
          errorContainer: Cp.errorContainer,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: Cp.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xff8bd987),
          onPrimary: const Color(0xff002204),
          primaryContainer: const Color(0xff3c863f),
          onPrimaryContainer: const Color(0xffe9ffe4),
          secondary: const Color(0xffafcfa8),
          onSecondary: const Color(0xff062108),
          secondaryContainer: const Color(0xff496646),
          onSecondaryContainer: const Color(0xffe4f8dd),
          tertiary: const Color(0xffcfc987),
          onTertiary: const Color(0xff1f1c00),
          tertiaryContainer: const Color(0xff64602a),
          onTertiaryContainer: const Color(0xfff8f1aa),
          error: const Color(0xffffb4ab),
          onError: const Color(0xff690005),
          errorContainer: const Color(0xff6f1d1b),
          onErrorContainer: const Color(0xffffdad6),
          surface: const Color(0xff0b1220),
          onSurface: const Color(0xfff4f7fb),
          surfaceContainerLowest: const Color(0xff101827),
          surfaceContainerLow: const Color(0xff142033),
          surfaceContainer: const Color(0xff1b2940),
          surfaceContainerHigh: const Color(0xff263650),
          surfaceContainerHighest: const Color(0xff33455f),
          onSurfaceVariant: const Color(0xffd7deea),
          outline: const Color(0xff9aa7ba),
          outlineVariant: const Color(0xff43536a),
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: const Color(0xffeef2f7),
          onInverseSurface: const Color(0xff101826),
          inversePrimary: Cp.primary,
        );
        return MaterialApp(
          title: 'CaterPro',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          locale: Locale(settings.languageCode),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDark
                  ? SystemUiOverlayStyle.light.copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: const Color(0xff111827))
                  : SystemUiOverlayStyle.dark.copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Cp.background),
              child: MediaQuery(
                data: media.copyWith(
                    textScaler: TextScaler.linear(settings.textScale * .9)),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: Cp.background,
            colorScheme: lightScheme,
            appBarTheme: AppBarTheme(
                backgroundColor: lightScheme.surface,
                foregroundColor: lightScheme.primary,
                elevation: 0),
            bottomSheetTheme:
                BottomSheetThemeData(backgroundColor: lightScheme.surface),
            cardTheme: CardThemeData(
                color: lightScheme.surfaceContainerLowest,
                surfaceTintColor: Colors.transparent),
            dialogTheme: DialogThemeData(
                backgroundColor: lightScheme.surface,
                surfaceTintColor: Colors.transparent),
            dividerTheme: DividerThemeData(color: lightScheme.outlineVariant),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: lightScheme.secondaryContainer,
                foregroundColor: lightScheme.onSecondaryContainer),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: lightScheme.surfaceContainerLowest,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            snackBarTheme: SnackBarThemeData(
                backgroundColor: lightScheme.primaryContainer,
                contentTextStyle:
                    textTheme.bodyMedium?.copyWith(color: Colors.white)),
            textTheme: textTheme.apply(
                bodyColor: Cp.onSurface, displayColor: Cp.onSurface),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: darkScheme.surface,
            colorScheme: darkScheme,
            appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xff0b1220),
                foregroundColor: Color(0xff8bd987),
                elevation: 0),
            bottomSheetTheme: const BottomSheetThemeData(
                backgroundColor: Color(0xff101827),
                modalBackgroundColor: Color(0xff101827)),
            cardTheme: const CardThemeData(
                color: Color(0xff142033), surfaceTintColor: Colors.transparent),
            dialogTheme: const DialogThemeData(
                backgroundColor: Color(0xff142033),
                surfaceTintColor: Colors.transparent),
            dividerTheme: const DividerThemeData(color: Color(0xff43536a)),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xff64602a),
                foregroundColor: Color(0xfff8f1aa)),
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: Color(0xffd7deea)),
              floatingLabelStyle: const TextStyle(color: Color(0xff8bd987)),
              prefixIconColor: const Color(0xffd7deea),
              suffixIconColor: const Color(0xffd7deea),
              filled: true,
              fillColor: const Color(0xff1b2940),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            checkboxTheme: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? const Color(0xff8bd987)
                      : const Color(0xff1b2940)),
              checkColor: WidgetStateProperty.all(const Color(0xff002204)),
            ),
            textTheme: textTheme.apply(
                bodyColor: const Color(0xffeef2f7),
                displayColor: const Color(0xffeef2f7)),
            snackBarTheme: SnackBarThemeData(
                backgroundColor: darkScheme.primaryContainer,
                contentTextStyle: textTheme.bodyMedium
                    ?.copyWith(color: darkScheme.onPrimaryContainer)),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class DownloadEntry {
  const DownloadEntry(
      {required this.id,
      required this.title,
      required this.url,
      required this.kind,
      required this.createdAt});

  final String id;
  final String title;
  final String url;
  final String kind;
  final DateTime createdAt;

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Downloaded file',
      url: json['url']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'file',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'kind': kind,
        'createdAt': createdAt.toIso8601String(),
      };
}

class DownloadHistoryController extends ChangeNotifier {
  static const _storageKey = 'caterpro.downloadHistory.v1';
  final List<DownloadEntry> _items = [];
  bool _loaded = false;

  List<DownloadEntry> get items => List.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
              (item) => DownloadEntry.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.url.isNotEmpty)
          .toList();
      _items
        ..clear()
        ..addAll(decoded);
      notifyListeners();
    } catch (_) {
      // Ignore corrupt local history; future downloads will overwrite it.
    }
  }

  Future<void> add(
      {required String title, required Uri uri, String kind = 'file'}) async {
    await load();
    final url = uri.toString();
    _items.removeWhere((item) => item.url == url);
    _items.insert(
        0,
        DownloadEntry(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title.trim().isEmpty ? fileNameFromUri(uri) : title.trim(),
            url: url,
            kind: kind,
            createdAt: DateTime.now()));
    if (_items.length > 50) _items.removeRange(50, _items.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(_items.map((item) => item.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> removeWhere(Set<String> ids) async {
    if (ids.isEmpty) return;
    await load();
    _items.removeWhere((item) => ids.contains(item.id));
    final prefs = await SharedPreferences.getInstance();
    if (_items.isEmpty) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey,
          jsonEncode(_items.map((item) => item.toJson()).toList()));
    }
    notifyListeners();
  }
}

String fileNameFromUri(Uri uri) {
  final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  return segment.isEmpty ? 'Downloaded file' : Uri.decodeComponent(segment);
}

String sanitizeDownloadFileName(String title, String kind) {
  final extension = kind == 'backup' ? '.json' : '.pdf';
  final cleaned = title
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-')
      .replaceAll(RegExp(r'\s+'), ' ');
  final fallback = kind == 'backup' ? 'CaterPro backup' : 'CaterPro download';
  final name = cleaned.isEmpty ? fallback : cleaned;
  return name.toLowerCase().endsWith(extension) ? name : '$name$extension';
}

String mimeTypeForDownload(String kind, String fileName) {
  if (kind == 'backup' || fileName.toLowerCase().endsWith('.json')) {
    return 'application/json';
  }
  return 'application/pdf';
}

String cleanDisplayText(String value) {
  final mojibakeBullet = String.fromCharCodes([0x00e2, 0x20ac, 0x00a2]);
  final doubleMojibakeBullet = String.fromCharCodes(
      [0x00c3, 0x00a2, 0x00e2, 0x201a, 0x00ac, 0x00c2, 0x00a2]);
  final mojibakeMiddleDot = String.fromCharCodes([0x00c2, 0x00b7]);
  value = value
      .replaceAll(doubleMojibakeBullet, '|')
      .replaceAll(mojibakeBullet, '|')
      .replaceAll(mojibakeMiddleDot, '|');
  return value
      .replaceAll('â€¢', '|')
      .replaceAll('â€¢', '|')
      .replaceAll('€¢', '|')
      .replaceAll('Â·', '|')
      .replaceAll(RegExp(r'\s+\|\s+'), ' | ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

Future<Uri> saveDownloadToDevice(
    {required String title,
    required Uri uri,
    required String kind,
    Map<String, String>? headers}) async {
  if (kIsWeb) {
    throw Exception('In-app downloads are available on the mobile app.');
  }
  final response = await http.get(uri, headers: headers);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Download failed (${response.statusCode})');
  }
  final fileName = sanitizeDownloadFileName(title, kind);
  final mimeType = mimeTypeForDownload(kind, fileName);
  final result = await downloadChannel.invokeMapMethod<String, Object?>(
    'saveFile',
    {
      'fileName': fileName,
      'mimeType': mimeType,
      'bytes': Uint8List.fromList(response.bodyBytes),
    },
  );
  final savedUri = result?['uri']?.toString() ?? '';
  if (savedUri.isEmpty) throw Exception('Unable to save file');
  final localUri = Uri.parse(savedUri);
  await downloadHistory.add(title: fileName, uri: localUri, kind: kind);
  return localUri;
}

Future<bool> openDownloadedFile(Uri uri,
    {required String title, String kind = 'file'}) async {
  if (!kIsWeb && (uri.scheme == 'content' || uri.scheme == 'file')) {
    final opened = await downloadChannel.invokeMethod<bool>(
          'openFile',
          {
            'uri': uri.toString(),
            'mimeType': mimeTypeForDownload(kind, title),
          },
        ) ??
        false;
    return opened;
  }
  return launchUrl(uri,
      mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
}

Future<bool> shareDownloadedFile(Uri uri,
    {required String title, String kind = 'file', String? text}) async {
  if (!kIsWeb && (uri.scheme == 'content' || uri.scheme == 'file')) {
    final shared = await downloadChannel.invokeMethod<bool>(
          'shareFile',
          {
            'uri': uri.toString(),
            'mimeType': mimeTypeForDownload(kind, title),
            'title': title,
            if (text != null && text.trim().isNotEmpty) 'text': text,
          },
        ) ??
        false;
    return shared;
  }
  return launchUrl(uri,
      mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
}

Future<Uri> saveAndShareDownload(
    {required String title,
    required Uri uri,
    required String kind,
    String? text,
    Map<String, String>? headers}) async {
  final localUri = await saveDownloadToDevice(
      title: title, uri: uri, kind: kind, headers: headers);
  final fileName = sanitizeDownloadFileName(title, kind);
  final shared = await shareDownloadedFile(localUri,
      title: fileName, kind: kind, text: text);
  if (!shared) throw Exception('Unable to open share sheet');
  return localUri;
}

class AppPreferences {
  const AppPreferences(
      {this.textScale = 1,
      this.font = 'Quicksand',
      this.theme = 'system',
      this.languageCode = 'en',
      this.defaultMenuTimes = defaultEventMenuTimes,
      this.autoMenuTypes = defaultAutoMenuTypes,
      this.vegOnlyDefault = false});

  final double textScale;
  final String font;
  final String theme;
  final String languageCode;
  final Map<String, String> defaultMenuTimes;
  final Set<String> autoMenuTypes;
  final bool vegOnlyDefault;

  ThemeMode get themeMode => switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String normalizeTheme(String? value) => switch (value) {
        'light' || 'dark' || 'system' => value!,
        _ => 'system',
      };

  TextTheme textTheme() {
    if (languageCode == 'kn') return GoogleFonts.notoSansKannadaTextTheme();
    if (languageCode == 'hi') return GoogleFonts.notoSansDevanagariTextTheme();
    return switch (font) {
      'Noto Sans' => GoogleFonts.notoSansTextTheme(),
      'Noto Sans Kannada' => GoogleFonts.notoSansKannadaTextTheme(),
      'Poppins' => GoogleFonts.poppinsTextTheme(),
      _ => GoogleFonts.quicksandTextTheme(),
    };
  }

  String get languageLabel => switch (languageCode) {
        'kn' => 'Kannada',
        'hi' => 'Hindi',
        _ => 'English',
      };

  AppPreferences copyWith(
          {double? textScale,
          String? font,
          String? theme,
          String? languageCode,
          Map<String, String>? defaultMenuTimes,
          Set<String>? autoMenuTypes,
          bool? vegOnlyDefault}) =>
      AppPreferences(
          textScale: textScale ?? this.textScale,
          font: font ?? this.font,
          theme: theme ?? this.theme,
          languageCode: languageCode ?? this.languageCode,
          defaultMenuTimes: defaultMenuTimes ?? this.defaultMenuTimes,
          autoMenuTypes: autoMenuTypes ?? this.autoMenuTypes,
          vegOnlyDefault: vegOnlyDefault ?? this.vegOnlyDefault);

  static AppPreferences fromPrefs(SharedPreferences prefs) {
    final menuTimes = <String, String>{};
    for (final type in eventMenuTypes) {
      menuTimes[type] = prefs.getString('eventDefaults.time.$type') ??
          defaultEventMenuTimes[type] ??
          '10:00 AM';
    }
    return AppPreferences(
      textScale: prefs.getDouble('appearance.textScale') ?? 1,
      font: prefs.getString('appearance.font') ?? 'Quicksand',
      theme: normalizeTheme(prefs.getString('appearance.theme')),
      languageCode: prefs.getString('appearance.language') ?? 'en',
      defaultMenuTimes: menuTimes,
      autoMenuTypes: (prefs.getStringList('eventDefaults.autoMenuTypes') ??
              defaultAutoMenuTypes.toList())
          .where(eventMenuTypes.contains)
          .toSet(),
      vegOnlyDefault: prefs.getBool('eventDefaults.vegOnlyDefault') ?? false,
    );
  }
}

class AppPreferencesController extends ValueNotifier<AppPreferences> {
  AppPreferencesController() : super(const AppPreferences());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = AppPreferences.fromPrefs(prefs);
  }

  Future<void> save(AppPreferences next) async {
    final normalized =
        next.copyWith(theme: AppPreferences.normalizeTheme(next.theme));
    value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('appearance.textScale', normalized.textScale);
    await prefs.setString('appearance.font', normalized.font);
    await prefs.setString('appearance.theme', normalized.theme);
    await prefs.setString('appearance.language', normalized.languageCode);
    for (final entry in normalized.defaultMenuTimes.entries) {
      await prefs.setString('eventDefaults.time.${entry.key}', entry.value);
    }
    await prefs.setStringList('eventDefaults.autoMenuTypes',
        normalized.autoMenuTypes.toList()..sort());
    await prefs.setBool(
        'eventDefaults.vegOnlyDefault', normalized.vegOnlyDefault);
  }
}

const eventMenuTypes = [
  'Breakfast',
  'Juice',
  'Lunch',
  'Snack',
  'Dinner',
  'Others',
];

const defaultEventMenuTimes = {
  'Breakfast': '8:00 AM',
  'Juice': '5:00 PM',
  'Lunch': '1:30 PM',
  'Snack': '4:30 PM',
  'Dinner': '8:00 PM',
  'Others': '10:00 AM',
};

const defaultAutoMenuTypes = {'Breakfast', 'Lunch', 'Dinner'};

String tr(String english, {String? kn, String? hi}) {
  return switch (appPreferences.value.languageCode) {
    'kn' => kn ?? english,
    'hi' => hi ?? english,
    _ => english,
  };
}

String t(String key) {
  const kn = {
    'Manage your events':
        '\u0ca8\u0cbf\u0cae\u0ccd\u0cae \u0c95\u0cbe\u0cb0\u0ccd\u0caf\u0c95\u0ccd\u0cb0\u0cae\u0c97\u0cb3\u0ca8\u0ccd\u0ca8\u0cc1 \u0ca8\u0cbf\u0cb0\u0ccd\u0cb5\u0cb9\u0cbf\u0cb8\u0cbf',
    'Dashboard':
        '\u0ca1\u0ccd\u0caf\u0cbe\u0cb7\u0ccd\u0cac\u0ccb\u0cb0\u0ccd\u0ca1\u0ccd',
    'Events':
        '\u0c95\u0cbe\u0cb0\u0ccd\u0caf\u0c95\u0ccd\u0cb0\u0cae\u0c97\u0cb3\u0cc1',
    'Clients': '\u0c97\u0ccd\u0cb0\u0cbe\u0cb9\u0c95\u0cb0\u0cc1',
    'Billing': '\u0cac\u0cbf\u0cb2\u0ccd\u0cb2\u0cbf\u0c82\u0c97\u0ccd',
    'Settings':
        '\u0cb8\u0cc6\u0c9f\u0ccd\u0c9f\u0cbf\u0c82\u0c97\u0ccd\u0cb8\u0ccd',
    'Dates': '\u0ca6\u0cbf\u0ca8\u0cbe\u0c82\u0c95\u0c97\u0cb3\u0cc1',
    'Menus': '\u0cae\u0cc6\u0ca8\u0cc1\u0c97\u0cb3\u0cc1',
    'Payments': '\u0caa\u0cbe\u0cb5\u0ca4\u0cbf\u0c97\u0cb3\u0cc1',
    'Created': '\u0cb0\u0c9a\u0cbf\u0cb8\u0cb2\u0cbe\u0c97\u0cbf\u0ca6\u0cc6',
    'Loading...':
        '\u0cb2\u0ccb\u0ca1\u0ccd \u0c86\u0c97\u0cc1\u0ca4\u0ccd\u0ca4\u0cbf\u0ca6\u0cc6...',
    'Event dates':
        '\u0c95\u0cbe\u0cb0\u0ccd\u0caf\u0c95\u0ccd\u0cb0\u0cae \u0ca6\u0cbf\u0ca8\u0cbe\u0c82\u0c95',
    'Menu slots':
        '\u0cae\u0cc6\u0ca8\u0cc1 \u0cb8\u0ccd\u0cb2\u0cbe\u0c9f\u0ccd\u0c97\u0cb3\u0cc1',
    'Collected':
        '\u0cb8\u0c82\u0c97\u0ccd\u0cb0\u0cb9\u0cbf\u0cb8\u0cb2\u0cbe\u0c97\u0cbf\u0ca6\u0cc6',
    'Upcoming Events':
        '\u0cae\u0cc1\u0c82\u0cac\u0cb0\u0cc1\u0cb5 \u0c95\u0cbe\u0cb0\u0ccd\u0caf\u0c95\u0ccd\u0cb0\u0cae\u0c97\u0cb3\u0cc1',
    'Upcoming': '\u0cae\u0cc1\u0c82\u0cac\u0cb0\u0cc1\u0cb5',
    'No upcoming events':
        '\u0cae\u0cc1\u0c82\u0cac\u0cb0\u0cc1\u0cb5 \u0c95\u0cbe\u0cb0\u0ccd\u0caf\u0c95\u0ccd\u0cb0\u0cae\u0c97\u0cb3\u0cbf\u0cb2\u0ccd\u0cb2',
    'Events from tomorrow and the next 2 days will appear here.':
        '\u0ca8\u0cbe\u0cb3\u0cc6 \u0cae\u0ca4\u0ccd\u0ca4\u0cc1 \u0cae\u0cc1\u0c82\u0ca6\u0cbf\u0ca8 2 \u0ca6\u0cbf\u0ca8\u0c97\u0cb3 \u0c95\u0cbe\u0cb0\u0ccd\u0caf\u0c95\u0ccd\u0cb0\u0cae\u0c97\u0cb3\u0cc1 \u0c87\u0cb2\u0ccd\u0cb2\u0cbf \u0c95\u0cbe\u0ca3\u0cc1\u0ca4\u0ccd\u0ca4\u0cb5\u0cc6.',
    'Create Event':
        '\u0c95\u0cbe\u0cb0\u0ccd\u0caf\u0c95\u0ccd\u0cb0\u0cae \u0cb0\u0c9a\u0cbf\u0cb8\u0cbf',
    'Menu Master':
        '\u0cae\u0cc6\u0ca8\u0cc1 \u0cae\u0cbe\u0cb8\u0ccd\u0c9f\u0cb0\u0ccd',
    'Business': '\u0cb5\u0ccd\u0caf\u0cb5\u0cb9\u0cbe\u0cb0',
    'Business Profile':
        '\u0cb5\u0ccd\u0caf\u0cb5\u0cb9\u0cbe\u0cb0 \u0caa\u0ccd\u0cb0\u0ccb\u0cab\u0cc8\u0cb2\u0ccd',
    'Masters': '\u0cae\u0cbe\u0cb8\u0ccd\u0c9f\u0cb0\u0ccd\u0c97\u0cb3\u0cc1',
    'Team': '\u0ca4\u0c82\u0ca1',
    'Employees': '\u0ca8\u0ccc\u0c95\u0cb0\u0cb0\u0cc1',
    'User Management':
        '\u0cac\u0cb3\u0c95\u0cc6\u0ca6\u0cbe\u0cb0 \u0ca8\u0cbf\u0cb0\u0ccd\u0cb5\u0cb9\u0ca3\u0cc6',
    'Preferences': '\u0c86\u0ca6\u0ccd\u0caf\u0ca4\u0cc6\u0c97\u0cb3\u0cc1',
    'Invoice Settings':
        '\u0c87\u0ca8\u0ccd\u0cb5\u0cbe\u0caf\u0ccd\u0cb8\u0ccd \u0cb8\u0cc6\u0c9f\u0ccd\u0c9f\u0cbf\u0c82\u0c97\u0ccd\u0cb8\u0ccd',
    'Notifications': '\u0cb8\u0cc2\u0c9a\u0ca8\u0cc6\u0c97\u0cb3\u0cc1',
    'App Appearance': '\u0c85\u0ccd\u0caf\u0caa\u0ccd \u0cb0\u0cc2\u0caa',
    'Data': '\u0ca1\u0cc7\u0c9f\u0cbe',
    'Export Data':
        '\u0ca1\u0cc7\u0c9f\u0cbe \u0c8e\u0c95\u0ccd\u0cb8\u0ccd\u0caa\u0ccb\u0cb0\u0ccd\u0c9f\u0ccd',
    'Import Data':
        '\u0ca1\u0cc7\u0c9f\u0cbe \u0c87\u0c82\u0caa\u0ccb\u0cb0\u0ccd\u0c9f\u0ccd',
    'Backup to Google Drive':
        '\u0c97\u0cc2\u0c97\u0cb2\u0ccd \u0ca1\u0ccd\u0cb0\u0cc8\u0cb5\u0ccd\u200c\u0c97\u0cc6 \u0cac\u0ccd\u0caf\u0cbe\u0c95\u0caa\u0ccd',
    'Sync Now':
        '\u0c88\u0c97 \u0cb8\u0cbf\u0c82\u0c95\u0ccd \u0cae\u0cbe\u0ca1\u0cbf',
    'Audit Log': '\u0c86\u0ca1\u0cbf\u0c9f\u0ccd \u0cb2\u0cbe\u0c97\u0ccd',
    'Logout': '\u0cb2\u0cbe\u0c97\u0ccd \u0c94\u0c9f\u0ccd',
  };
  const hi = {
    'Manage your events':
        '\u0905\u092a\u0928\u0947 \u0907\u0935\u0947\u0902\u091f \u092e\u0948\u0928\u0947\u091c \u0915\u0930\u0947\u0902',
    'Dashboard': '\u0921\u0948\u0936\u092c\u094b\u0930\u094d\u0921',
    'Events': '\u0907\u0935\u0947\u0902\u091f',
    'Clients': '\u0917\u094d\u0930\u093e\u0939\u0915',
    'Billing': '\u092c\u093f\u0932\u093f\u0902\u0917',
    'Settings': '\u0938\u0947\u091f\u093f\u0902\u0917\u094d\u0938',
    'Dates': '\u0924\u093e\u0930\u0940\u0916\u0947\u0902',
    'Menus': '\u092e\u0947\u0928\u0942',
    'Payments': '\u092d\u0941\u0917\u0924\u093e\u0928',
    'Created': '\u092c\u0928\u093e\u092f\u093e',
    'Loading...':
        '\u0932\u094b\u0921 \u0939\u094b \u0930\u0939\u093e \u0939\u0948...',
    'Event dates':
        '\u0907\u0935\u0947\u0902\u091f \u0924\u093e\u0930\u0940\u0916\u0947\u0902',
    'Menu slots': '\u092e\u0947\u0928\u0942 \u0938\u094d\u0932\u0949\u091f',
    'Collected': '\u091c\u092e\u093e',
    'Upcoming Events':
        '\u0906\u0928\u0947 \u0935\u093e\u0932\u0947 \u0907\u0935\u0947\u0902\u091f',
    'Upcoming': '\u0906\u0928\u0947 \u0935\u093e\u0932\u0947',
    'No upcoming events':
        '\u0915\u094b\u0908 \u0906\u0928\u0947 \u0935\u093e\u0932\u093e \u0907\u0935\u0947\u0902\u091f \u0928\u0939\u0940\u0902',
    'Create Event':
        '\u0907\u0935\u0947\u0902\u091f \u092c\u0928\u093e\u090f\u0902',
    'Menu Master':
        '\u092e\u0947\u0928\u0942 \u092e\u093e\u0938\u094d\u091f\u0930',
    'Business': '\u0935\u094d\u092f\u0935\u0938\u093e\u092f',
    'Business Profile':
        '\u0935\u094d\u092f\u0935\u0938\u093e\u092f \u092a\u094d\u0930\u094b\u092b\u093e\u0907\u0932',
    'Masters': '\u092e\u093e\u0938\u094d\u091f\u0930',
    'Team': '\u091f\u0940\u092e',
    'Employees': '\u0915\u0930\u094d\u092e\u091a\u093e\u0930\u0940',
    'User Management':
        '\u092f\u0942\u091c\u0930 \u092e\u0948\u0928\u0947\u091c\u092e\u0947\u0902\u091f',
    'Preferences': '\u092a\u0938\u0902\u0926',
    'Invoice Settings':
        '\u0907\u0928\u0935\u0949\u092f\u0938 \u0938\u0947\u091f\u093f\u0902\u0917\u094d\u0938',
    'Notifications': '\u0938\u0942\u091a\u0928\u093e\u090f\u0902',
    'App Appearance': '\u090f\u092a \u0926\u093f\u0916\u093e\u0935\u091f',
    'Data': '\u0921\u0947\u091f\u093e',
    'Export Data':
        '\u0921\u0947\u091f\u093e \u090f\u0915\u094d\u0938\u092a\u094b\u0930\u094d\u091f',
    'Import Data':
        '\u0921\u0947\u091f\u093e \u0907\u092e\u094d\u092a\u094b\u0930\u094d\u091f',
    'Backup to Google Drive':
        '\u0917\u0942\u0917\u0932 \u0921\u094d\u0930\u093e\u0907\u0935 \u092c\u0948\u0915\u0905\u092a',
    'Sync Now': '\u0905\u092d\u0940 \u0938\u093f\u0902\u0915',
    'Audit Log': '\u0911\u0921\u093f\u091f \u0932\u0949\u0917',
    'Logout': '\u0932\u0949\u0917\u0906\u0909\u091f',
  };
  return switch (appPreferences.value.languageCode) {
    'kn' => kn[key] ?? key,
    'hi' => hi[key] ?? key,
    _ => key,
  };
}

class AppNotification {
  const AppNotification(
      {required this.id,
      required this.eventId,
      required this.title,
      required this.message,
      required this.kind,
      required this.icon,
      required this.color,
      required this.date});

  final String id;
  final String eventId;
  final String title;
  final String message;
  final String kind;
  final IconData icon;
  final Color color;
  final DateTime date;
}

List<AppNotification> buildEventNotifications(List<AppEvent> events) {
  final now = DateTime.now();
  final notifications = <AppNotification>[];
  for (final event in events) {
    final eventDates = event.dates
        .map((date) => parseIsoDate(date.date))
        .whereType<DateTime>()
        .toList()
      ..sort();
    final firstDate = eventDates.firstOrNull;
    final lastDate = eventDates.lastOrNull;
    notifications.add(AppNotification(
      id: '${event.id}-created',
      eventId: event.id,
      title: 'Event created',
      message:
          '${event.name} ${firstDate == null ? 'has been created.' : 'starts on ${readableDateLabel(firstDate.toIso8601String().substring(0, 10))}.'}',
      kind: 'event',
      icon: Icons.event_available,
      color: Cp.primary,
      date: firstDate ?? now,
    ));
    if (event.employeeAssignments.isEmpty) {
      notifications.add(AppNotification(
        id: '${event.id}-team',
        eventId: event.id,
        title: 'Team not assigned',
        message: 'Assign employees to ${event.name} before the event.',
        kind: 'team',
        icon: Icons.group_off,
        color: Cp.secondary,
        date: firstDate ?? now,
      ));
    }
    final balance = eventBalance(event);
    if (balance > 0 && lastDate != null && !lastDate.isAfter(now)) {
      notifications.add(AppNotification(
        id: '${event.id}-payment-reminder',
        eventId: event.id,
        title: 'Payment reminder',
        message: '${event.name} has ${money(balance)} pending after the event.',
        kind: 'payment',
        icon: Icons.currency_rupee,
        color: Cp.error,
        date: lastDate,
      ));
      final pendingSince = lastDate.add(const Duration(days: 15));
      if (!pendingSince.isAfter(now)) {
        notifications.add(AppNotification(
          id: '${event.id}-pending-15',
          eventId: event.id,
          title: 'Pending for 15 days',
          message: '${money(balance)} is still due for ${event.name}.',
          kind: 'overdue',
          icon: Icons.notification_important,
          color: Cp.error,
          date: pendingSince,
        ));
      }
    }
  }
  notifications.sort((a, b) => b.date.compareTo(a.date));
  return notifications;
}

class Cp {
  static const surface = Color(0xfff7fbf2);
  static const background = Color(0xfff7fbf2);
  static const card = Color(0xffffffff);
  static const surfaceLow = Color(0xfff2f5ec);
  static const surfaceHigh = Color(0xffe6e9e1);
  static const outline = Color(0xff707a6d);
  static const outlineVariant = Color(0xffc0c9ba);
  static const onSurface = Color(0xff191d18);
  static const onVariant = Color(0xff40493e);
  static const primary = Color(0xff206c29);
  static const primaryContainer = Color(0xff3c863f);
  static const primaryFixed = Color(0xffa6f5a1);
  static const toolbarIcon = Color(0xff8bd987);
  static const secondary = Color(0xff496646);
  static const secondaryContainer = Color(0xffcaecc3);
  static const secondaryFixed = Color(0xffcaecc3);
  static const tertiary = Color(0xff64602a);
  static const tertiaryContainer = Color(0xffb3ad6e);
  static const tertiaryFixed = Color(0xffece5a1);
  static const error = Color(0xffba1a1a);
  static const errorContainer = Color(0xffffdad6);
}

class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size.square(size), painter: _WhatsAppIconPainter()),
          Icon(Icons.call, color: Colors.white, size: size * .58),
        ]),
      );
}

class _WhatsAppIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff25d366);
    final radius = size.width * .44;
    final center = Offset(size.width * .5, size.height * .46);
    canvas.drawCircle(center, radius, paint);
    final tail = Path()
      ..moveTo(size.width * .28, size.height * .76)
      ..lineTo(size.width * .18, size.height * .95)
      ..lineTo(size.width * .42, size.height * .84)
      ..close();
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

bool cpDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color cpSurface(BuildContext context) => Theme.of(context).colorScheme.surface;

Color cpCard(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerLow;

Color cpSurfaceLow(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainer;

Color cpSurfaceHigh(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHigh;

Color cpInputFill(BuildContext context) =>
    Theme.of(context).inputDecorationTheme.fillColor ?? cpSurfaceLow(context);

Color cpPrimary(BuildContext context) => Theme.of(context).colorScheme.primary;

Color cpOnSurface(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color cpOnVariant(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

Color cpOutline(BuildContext context) => Theme.of(context).colorScheme.outline;

Color cpOutlineVariant(BuildContext context) =>
    Theme.of(context).colorScheme.outlineVariant;

Color cpAdaptSurfaceColor(BuildContext context, Color color) {
  if (!cpDark(context)) return color;
  if (color == Cp.card ||
      color == Cp.surface ||
      color == const Color(0xfffff7ff)) {
    return cpCard(context);
  }
  if (color == Cp.surfaceLow) return cpSurfaceLow(context);
  if (color == Cp.surfaceHigh) return cpSurfaceHigh(context);
  if (color == Cp.primaryFixed) return const Color(0xff173d1d);
  if (color == Cp.secondaryFixed) return const Color(0xff273723);
  if (color == Cp.tertiaryFixed) return const Color(0xff3d3a17);
  if (color == Cp.primaryContainer) {
    return Theme.of(context).colorScheme.primaryContainer;
  }
  if (color == Cp.secondaryContainer) {
    return Theme.of(context).colorScheme.secondaryContainer;
  }
  if (color == Cp.tertiaryContainer) {
    return Theme.of(context).colorScheme.tertiaryContainer;
  }
  if (color == Cp.errorContainer || color == const Color(0xffffebeb)) {
    return Theme.of(context).colorScheme.errorContainer;
  }
  return color;
}

Color cpAdaptTextColor(BuildContext context, Color color) {
  if (!cpDark(context)) return color;
  if (color == Cp.primary || color == Cp.primaryContainer) {
    return cpPrimary(context);
  }
  if (color == Cp.onSurface) return cpOnSurface(context);
  if (color == Cp.onVariant || color == Cp.outline) return cpOnVariant(context);
  if (color == Cp.secondary || color == Cp.secondaryContainer) {
    return Theme.of(context).colorScheme.secondary;
  }
  if (color == Cp.tertiary || color == Cp.tertiaryContainer) {
    return Theme.of(context).colorScheme.tertiary;
  }
  if (color == Cp.error) return Theme.of(context).colorScheme.error;
  return color;
}

class AdditionalServiceItem {
  const AdditionalServiceItem(
      {required this.id,
      required this.name,
      required this.unit,
      required this.quantity,
      required this.price});
  final String id;
  final String name;
  final String unit;
  final int quantity;
  final int price;

  AdditionalServiceItem copyWith(
      {String? id, String? name, String? unit, int? quantity, int? price}) {
    return AdditionalServiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }

  factory AdditionalServiceItem.fromJson(Map<String, dynamic> json) {
    return AdditionalServiceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'quantity': quantity,
        'price': price
      };
}

class CustomMenu {
  const CustomMenu(
      {required this.id,
      required this.name,
      required this.type,
      required this.itemIds});
  final String id;
  final String name;
  final String type;
  final Set<String> itemIds;

  factory CustomMenu.fromJson(Map<String, dynamic> json) {
    return CustomMenu(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      itemIds: ((json['itemIds'] as List?) ?? [])
          .map((item) => item.toString())
          .toSet(),
    );
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'type': type, 'itemIds': itemIds.toList()};
}

class BusinessProfile {
  const BusinessProfile({
    this.businessName = '',
    this.serviceType = '',
    this.gstin = '',
    this.gstType = 'cgst_sgst',
    this.gstRate = 5,
    this.pan = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.accountHolderName = '',
    this.bankName = '',
    this.branchName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.terms = '',
    this.logoBase64 = '',
    this.signatureBase64 = '',
    this.qrBase64 = '',
    this.documentTemplate = 'modern',
    this.invoiceTextScale = 1,
    this.pdfMenuFontSize = 12,
  });

  final String businessName;
  final String serviceType;
  final String gstin;
  final String gstType;
  final double gstRate;
  final String pan;
  final String address;
  final String phone;
  final String email;
  final String accountHolderName;
  final String bankName;
  final String branchName;
  final String accountNumber;
  final String ifsc;
  final String terms;
  final String logoBase64;
  final String signatureBase64;
  final String qrBase64;
  final String documentTemplate;
  final double invoiceTextScale;
  final double pdfMenuFontSize;

  factory BusinessProfile.fromJson(Map<String, dynamic>? json) {
    final data = json ?? {};
    return BusinessProfile(
      businessName: data['businessName']?.toString() ?? '',
      serviceType: data['serviceType']?.toString() ?? '',
      gstin: data['gstin']?.toString() ?? '',
      gstType: data['gstType']?.toString() == 'igst' ? 'igst' : 'cgst_sgst',
      gstRate: double.tryParse(
              (data['gstRate'] ?? data['gstPercent'])?.toString() ?? '') ??
          5,
      pan: data['pan']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      accountHolderName: data['accountHolderName']?.toString() ?? '',
      bankName: data['bankName']?.toString() ?? '',
      branchName: data['branchName']?.toString() ?? '',
      accountNumber: data['accountNumber']?.toString() ?? '',
      ifsc: data['ifsc']?.toString() ?? '',
      terms: data['terms']?.toString() ?? '',
      logoBase64: data['logoBase64']?.toString() ?? '',
      signatureBase64: data['signatureBase64']?.toString() ?? '',
      qrBase64: data['qrBase64']?.toString() ?? '',
      documentTemplate: data['documentTemplate']?.toString() ?? 'modern',
      invoiceTextScale:
          double.tryParse(data['invoiceTextScale']?.toString() ?? '') ?? 1,
      pdfMenuFontSize:
          double.tryParse(data['pdfMenuFontSize']?.toString() ?? '') ?? 12,
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'serviceType': serviceType,
        'gstin': gstin,
        'gstType': gstType,
        'gstRate': gstRate,
        'pan': pan,
        'address': address,
        'phone': phone,
        'email': email,
        'accountHolderName': accountHolderName,
        'bankName': bankName,
        'branchName': branchName,
        'accountNumber': accountNumber,
        'ifsc': ifsc,
        'terms': terms,
        'logoBase64': logoBase64,
        'signatureBase64': signatureBase64,
        'qrBase64': qrBase64,
        'documentTemplate': documentTemplate,
        'invoiceTextScale': invoiceTextScale,
        'pdfMenuFontSize': pdfMenuFontSize,
      };
}

class ApiConfig {
  static const _definedBaseUrl = String.fromEnvironment('CATERPRO_API_URL');
  static const liveBaseUrl = 'https://caterpro-api.onrender.com/api';

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }
    if (kReleaseMode) {
      return liveBaseUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8787/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8787/api';
    }
    return 'http://127.0.0.1:8787/api';
  }
}

class AuthSession {
  const AuthSession(
      {required this.token,
      required this.userId,
      required this.email,
      required this.name});
  final String token;
  final String userId;
  final String email;
  final String name;
}

class AuthService {
  Future<AuthSession?> savedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token');
    final userId = prefs.getString('auth.userId');
    final email = prefs.getString('auth.email');
    final name = prefs.getString('auth.name');
    if (token == null ||
        token.isEmpty ||
        userId == null ||
        email == null ||
        name == null) {
      return null;
    }
    return AuthSession(token: token, userId: userId, email: email, name: name);
  }

  Future<AuthSession> login(
      {required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Login failed');
    }
    final user = body['user'] as Map<String, dynamic>;
    final session = AuthSession(
        token: body['token'] as String,
        userId: user['id'] as String,
        email: user['email'] as String,
        name: user['name'] as String);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth.token', session.token);
    await prefs.setString('auth.userId', session.userId);
    await prefs.setString('auth.email', session.email);
    await prefs.setString('auth.name', session.name);
    return session;
  }

  Future<void> forgotPassword(String email) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/forgot-password'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  Future<void> changePassword(
      {required String oldPassword, required String newPassword}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    if (token.isEmpty) {
      throw Exception('Please login again before changing password');
    }
    final payload =
        jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword});
    Future<http.Response> submit(String path) => http.post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: payload,
        );
    var response = await submit('/auth/change-password');
    if (response.statusCode == 404) {
      response = await submit('/auth/reset-password');
    }
    if (response.statusCode != 200) {
      var message = response.statusCode == 401
          ? 'Session expired. Please login again.'
          : response.statusCode == 404
              ? 'Password reset API is not available yet. Update/restart the backend.'
              : 'Unable to reset password';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) message = response.body.trim();
      }
      throw Exception(message);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth.token');
    await prefs.remove('auth.userId');
    await prefs.remove('auth.email');
    await prefs.remove('auth.name');
    await prefs.remove('auth.biometric.enabled');
  }
}

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!deviceSupported && !canCheck) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return canCheck ||
          biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong) ||
          biometrics.contains(BiometricType.weak);
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auth.biometric.enabled') ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auth.biometric.enabled', enabled);
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final auth = AuthService();
  final biometric = BiometricAuthService();
  bool checking = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    final session = await auth.savedSession();
    final needsBiometric = session != null &&
        await biometric.isSupported() &&
        await biometric.isEnabled();
    if (!mounted) return;
    setState(() {
      loggedIn = session != null && !needsBiometric;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Cp.primary)));
    }
    return loggedIn ? const AppShell() : const LoginScreen();
  }
}

class AppEvent {
  const AppEvent(
      {required this.id,
      required this.name,
      required this.primaryClient,
      required this.mobile,
      required this.venue,
      required this.notes,
      required this.status,
      required this.addOns,
      required this.dates,
      required this.payments,
      required this.materialDocuments,
      required this.employeeAssignments});
  final String id;
  final String name;
  final String primaryClient;
  final String mobile;
  final String venue;
  final String notes;
  final String status;
  final List<Map<String, dynamic>> addOns;
  final List<AppEventDate> dates;
  final List<AppPayment> payments;
  final List<EventMaterialDocument> materialDocuments;
  final List<EventEmployeeAssignment> employeeAssignments;

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      primaryClient: json['primaryClient'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      addOns: ((json['addOns'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      dates: ((json['dates'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AppEventDate.fromJson)
          .toList(),
      payments: ((json['payments'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AppPayment.fromJson)
          .toList(),
      materialDocuments: ((json['materialDocuments'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EventMaterialDocument.fromJson)
          .toList(),
      employeeAssignments: ((json['employeeAssignments'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EventEmployeeAssignment.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primaryClient': primaryClient,
        'mobile': mobile,
        'venue': venue,
        'notes': notes,
        'status': status,
        'addOns': addOns,
        'dates': dates.map((date) => date.toJson()).toList(),
        'payments': payments.map((payment) => payment.toJson()).toList(),
        'materialDocuments':
            materialDocuments.map((document) => document.toJson()).toList(),
        'employeeAssignments': employeeAssignments
            .map((assignment) => assignment.toJson())
            .toList(),
      };
}

class EventEmployeeAssignment {
  const EventEmployeeAssignment(
      {required this.employeeId,
      required this.employeeName,
      required this.mobile,
      required this.designation,
      required this.payPerDay,
      required this.payPerHour});
  final String employeeId;
  final String employeeName;
  final String mobile;
  final String designation;
  final int payPerDay;
  final int payPerHour;

  factory EventEmployeeAssignment.fromJson(Map<String, dynamic> json) =>
      EventEmployeeAssignment(
        employeeId:
            json['employeeId']?.toString() ?? json['id']?.toString() ?? '',
        employeeName:
            json['employeeName']?.toString() ?? json['name']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        designation: json['designation']?.toString() ?? '',
        payPerDay: int.tryParse(json['payPerDay']?.toString() ?? '') ?? 0,
        payPerHour: int.tryParse(json['payPerHour']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'mobile': mobile,
        'designation': designation,
        'payPerDay': payPerDay,
        'payPerHour': payPerHour
      };
}

class AppClient {
  const AppClient(
      {required this.id,
      required this.name,
      required this.mobile,
      this.city = '',
      this.notes = '',
      this.address = '',
      this.gst = '',
      this.createdAt = '',
      this.updatedAt = ''});
  final String id;
  final String name;
  final String mobile;
  final String city;
  final String notes;
  final String address;
  final String gst;
  final String createdAt;
  final String updatedAt;

  factory AppClient.fromJson(Map<String, dynamic> json) => AppClient(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        gst: json['gst']?.toString() ?? json['gstin']?.toString() ?? '',
        createdAt: json['createdAt']?.toString() ?? '',
        updatedAt: json['updatedAt']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'city': city,
        'notes': notes,
        'address': address,
        'gst': gst,
        'createdAt': createdAt,
        'updatedAt': updatedAt
      };

  AppClient copyWith(
          {String? id,
          String? name,
          String? mobile,
          String? city,
          String? notes,
          String? address,
          String? gst,
          String? createdAt,
          String? updatedAt}) =>
      AppClient(
        id: id ?? this.id,
        name: name ?? this.name,
        mobile: mobile ?? this.mobile,
        city: city ?? this.city,
        notes: notes ?? this.notes,
        address: address ?? this.address,
        gst: gst ?? this.gst,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Employee {
  const Employee(
      {required this.id,
      required this.name,
      required this.age,
      required this.mobile,
      required this.designation,
      required this.payPerDay,
      required this.payPerHour});
  final String id;
  final String name;
  final int age;
  final String mobile;
  final String designation;
  final int payPerDay;
  final int payPerHour;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
        mobile: json['mobile']?.toString() ?? '',
        designation: json['designation']?.toString() ?? '',
        payPerDay: int.tryParse(json['payPerDay']?.toString() ?? '') ?? 0,
        payPerHour: int.tryParse(json['payPerHour']?.toString() ?? '') ?? 0,
      );

  factory Employee.fromAssignment(EventEmployeeAssignment assignment) =>
      Employee(
        id: assignment.employeeId,
        name: assignment.employeeName,
        age: 0,
        mobile: assignment.mobile,
        designation: assignment.designation,
        payPerDay: assignment.payPerDay,
        payPerHour: assignment.payPerHour,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'mobile': mobile,
        'designation': designation,
        'payPerDay': payPerDay,
        'payPerHour': payPerHour
      };

  Employee copyWith(
          {String? id,
          String? name,
          int? age,
          String? mobile,
          String? designation,
          int? payPerDay,
          int? payPerHour}) =>
      Employee(
        id: id ?? this.id,
        name: name ?? this.name,
        age: age ?? this.age,
        mobile: mobile ?? this.mobile,
        designation: designation ?? this.designation,
        payPerDay: payPerDay ?? this.payPerDay,
        payPerHour: payPerHour ?? this.payPerHour,
      );
}

class AttendanceRecord {
  const AttendanceRecord(
      {required this.id,
      required this.employeeId,
      required this.employeeName,
      required this.eventId,
      required this.eventName,
      required this.date,
      required this.status,
      required this.hours,
      required this.payPerDay,
      required this.payPerHour});
  final String id;
  final String employeeId;
  final String employeeName;
  final String eventId;
  final String eventName;
  final String date;
  final String status;
  final double hours;
  final int payPerDay;
  final int payPerHour;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id']?.toString() ?? '',
        employeeId: json['employeeId']?.toString() ?? '',
        employeeName: json['employeeName']?.toString() ?? '',
        eventId: json['eventId']?.toString() ?? '',
        eventName: json['eventName']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        status: json['status']?.toString() ?? 'absent',
        hours: double.tryParse(json['hours']?.toString() ?? '') ?? 0,
        payPerDay: int.tryParse(json['payPerDay']?.toString() ?? '') ?? 0,
        payPerHour: int.tryParse(json['payPerHour']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'eventId': eventId,
        'eventName': eventName,
        'date': date,
        'status': status,
        'hours': hours,
        'payPerDay': payPerDay,
        'payPerHour': payPerHour
      };
}

class EventMaterialLine {
  const EventMaterialLine(
      {required this.itemId,
      required this.name,
      required this.category,
      required this.quantity,
      required this.unit});
  final String itemId;
  final String name;
  final String category;
  final String quantity;
  final String unit;

  factory EventMaterialLine.fromJson(Map<String, dynamic> json) =>
      EventMaterialLine(
        itemId: json['itemId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        quantity: json['quantity']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit
      };
}

class EventMaterialDocument {
  const EventMaterialDocument(
      {required this.id,
      required this.type,
      required this.title,
      this.eventId = '',
      this.date = '',
      required this.items});
  final String id;
  final String type;
  final String title;
  final String eventId;
  final String date;
  final List<EventMaterialLine> items;

  String get typeLabel => type == 'menu'
      ? 'Menu Items'
      : type == 'produce'
          ? 'Vegetables & Fruits'
          : type == 'vessels'
              ? 'Vessels & Utensils'
              : 'Raw Materials';

  factory EventMaterialDocument.fromJson(Map<String, dynamic> json) =>
      EventMaterialDocument(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'raw',
        title: json['title']?.toString() ?? '',
        eventId: json['eventId']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        items: ((json['items'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(EventMaterialLine.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'eventId': eventId,
        'date': date,
        'items': items.map((item) => item.toJson()).toList()
      };
}

class AppPayment {
  const AppPayment(
      {required this.id,
      required this.amount,
      required this.date,
      required this.mode,
      required this.reference,
      required this.settled,
      required this.settledDiscount});
  final String id;
  final int amount;
  final String date;
  final String mode;
  final String reference;
  final bool settled;
  final int settledDiscount;

  factory AppPayment.fromJson(Map<String, dynamic> json) {
    return AppPayment(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      date: json['date'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      settled: json['settled'] == true,
      settledDiscount: (json['settledDiscount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date,
        'mode': mode,
        'reference': reference,
        'settled': settled,
        'settledDiscount': settledDiscount,
      };
}

typedef AuditLogger = void Function({
  required String action,
  required String entityType,
  required String entityId,
  required String entityLabel,
  required String summary,
  Map<String, dynamic>? metadata,
});

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    required this.summary,
    required this.createdAt,
    this.metadata = const {},
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String entityLabel;
  final String summary;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        entityType: json['entityType']?.toString() ?? '',
        entityId: json['entityId']?.toString() ?? '',
        entityLabel: json['entityLabel']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        metadata: Map<String, dynamic>.from(
            (json['metadata'] as Map?) ?? const {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'entityLabel': entityLabel,
        'summary': summary,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
      };
}

class ManualInvoiceItem {
  const ManualInvoiceItem(
      {required this.id,
      required this.title,
      required this.quantity,
      required this.rate,
      required this.amount});
  final String id;
  final String title;
  final int quantity;
  final int rate;
  final int amount;

  factory ManualInvoiceItem.fromJson(Map<String, dynamic> json) =>
      ManualInvoiceItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        rate: (json['rate'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'quantity': quantity,
        'rate': rate,
        'amount': amount
      };
}

class ManualInvoice {
  const ManualInvoice({
    required this.id,
    required this.clientName,
    required this.mobile,
    this.clientAddress = '',
    this.clientGst = '',
    required this.eventName,
    required this.venue,
    required this.eventDate,
    required this.invoiceDate,
    required this.invoiceNumber,
    required this.notes,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.advance,
    required this.settlement,
    required this.pending,
  });
  final String id;
  final String clientName;
  final String mobile;
  final String clientAddress;
  final String clientGst;
  final String eventName;
  final String venue;
  final String eventDate;
  final String invoiceDate;
  final String invoiceNumber;
  final String notes;
  final List<ManualInvoiceItem> items;
  final int subtotal;
  final int total;
  final int advance;
  final int settlement;
  final int pending;

  factory ManualInvoice.fromJson(Map<String, dynamic> json) => ManualInvoice(
        id: json['id']?.toString() ?? '',
        clientName: json['clientName']?.toString() ?? '',
        mobile: json['mobile']?.toString() ?? '',
        clientAddress: json['clientAddress']?.toString() ?? '',
        clientGst: json['clientGst']?.toString() ?? '',
        eventName: json['eventName']?.toString() ?? '',
        venue: json['venue']?.toString() ?? '',
        eventDate: json['eventDate']?.toString() ?? '',
        invoiceDate: json['invoiceDate']?.toString() ?? '',
        invoiceNumber: json['invoiceNumber']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
        items: ((json['items'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ManualInvoiceItem.fromJson)
            .toList(),
        subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        advance: (json['advance'] as num?)?.toInt() ?? 0,
        settlement: (json['settlement'] as num?)?.toInt() ?? 0,
        pending: (json['pending'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'mobile': mobile,
        'clientAddress': clientAddress,
        'clientGst': clientGst,
        'eventName': eventName,
        'venue': venue,
        'eventDate': eventDate,
        'invoiceDate': invoiceDate,
        'invoiceNumber': invoiceNumber,
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'total': total,
        'advance': advance,
        'settlement': settlement,
        'pending': pending,
      };
}

class AppEventDate {
  const AppEventDate(
      {required this.id,
      required this.date,
      required this.label,
      required this.menuSlots,
      required this.additionalServices});
  final String id;
  final String date;
  final String label;
  final List<AppMenuSlot> menuSlots;
  final List<Map<String, dynamic>> additionalServices;

  factory AppEventDate.fromJson(Map<String, dynamic> json) {
    return AppEventDate(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      label: json['label'] as String? ?? '',
      menuSlots: ((json['menuSlots'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(AppMenuSlot.fromJson)
          .toList(),
      additionalServices: ((json['additionalServices'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'label': label,
        'menuSlots': menuSlots.map((slot) => slot.toJson()).toList(),
        'additionalServices': additionalServices,
      };
}

class AppMenuSlot {
  const AppMenuSlot(
      {required this.id,
      required this.type,
      required this.time,
      required this.pax,
      required this.pricePerPax,
      required this.enabled,
      required this.menuItemIds,
      required this.additionalServices,
      required this.menuImages});
  final String id;
  final String type;
  final String time;
  final int pax;
  final int pricePerPax;
  final bool enabled;
  final List<String> menuItemIds;
  final List<Map<String, dynamic>> additionalServices;
  final List<Map<String, dynamic>> menuImages;

  factory AppMenuSlot.fromJson(Map<String, dynamic> json) {
    return AppMenuSlot(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      time: json['time'] as String? ?? '',
      pax: (json['pax'] as num?)?.toInt() ?? 0,
      pricePerPax: (json['pricePerPax'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] != false,
      menuItemIds: ((json['menuItemIds'] as List?) ?? [])
          .map((item) => item.toString())
          .toList(),
      additionalServices: ((json['additionalServices'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      menuImages: ((json['menuImages'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'time': time,
        'pax': pax,
        'pricePerPax': pricePerPax,
        'enabled': enabled,
        'menuItemIds': menuItemIds,
        'additionalServices': additionalServices,
        'menuImages': menuImages,
      };
}

class ApiService {
  Future<Map<String, String>> authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    };
  }

  Future<Uri> backupExportUri() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/backup')
        .replace(queryParameters: {'token': token});
  }

  Future<Map<String, dynamic>> importBackup(Map<String, dynamic> backup) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/backup/import'),
      headers: await authHeaders(),
      body: jsonEncode(backup),
    );
    if (response.statusCode != 200) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body is Map && body['message'] != null
            ? body['message']
            : 'Unable to import backup');
      } catch (_) {
        throw Exception('Unable to import backup');
      }
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> getWithRetry(Uri uri,
      {Map<String, String>? headers}) async {
    Object? lastError;
    const delays = [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
      Duration(seconds: 2),
    ];
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 18));
      } catch (error) {
        lastError = error;
        if (attempt < delays.length) {
          await Future<void>.delayed(delays[attempt]);
        }
      }
    }
    throw Exception(friendlyNetworkMessage(lastError ?? 'Network error'));
  }

  Future<Map<String, dynamic>> bootstrap() async {
    final response = await getWithRetry(
      Uri.parse('${ApiConfig.baseUrl}/bootstrap'),
      headers: await authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to load CaterPro data');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSyncSnapshot() async {
    final response = await getWithRetry(
      Uri.parse('${ApiConfig.baseUrl}/sync/snapshot'),
      headers: await authHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to load CaterPro data');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pushSyncSnapshot({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> universal,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/sync/snapshot'),
          headers: await authHeaders(),
          body: jsonEncode({'userData': userData, 'universal': universal}),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('Unable to push local CaterPro data');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<AppEvent>> getEvents() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/events'),
        headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load events');
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(AppEvent.fromJson)
        .toList();
  }

  Future<AppEvent> getEvent(String eventId) async {
    final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/events/$eventId'),
        headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load event');
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String eventId) async {
    final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/events/$eventId'),
        headers: await authHeaders());
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Unable to delete event');
    }
  }

  Future<AppEvent> deleteEventDate(String eventId, String dateId) async {
    final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/events/$eventId/dates/$dateId'),
        headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to delete date');
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AppEvent> deleteMenuSlot(
      String eventId, String dateId, String slotId) async {
    final response = await http.delete(
        Uri.parse(
            '${ApiConfig.baseUrl}/events/$eventId/dates/$dateId/menu-slots/$slotId'),
        headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to delete menu');
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<MenuMasterItem>> getMenuItems() async {
    final response = await getWithRetry(
        Uri.parse('${ApiConfig.baseUrl}/menu-items'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load menu items');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(MenuMasterItem.fromJson)
        .toList();
  }

  Future<Uri> menuCatalogPdfUri(String language,
      {String search = '', String meal = 'All', bool vegOnly = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    final query = <String, String>{'language': language, 'token': token};
    final normalizedSearch = search.trim();
    if (normalizedSearch.isNotEmpty) query['search'] = normalizedSearch;
    if (meal != 'All') query['meal'] = meal;
    if (vegOnly) query['vegOnly'] = 'true';
    return Uri.parse('${ApiConfig.baseUrl}/menu-items/export.pdf')
        .replace(queryParameters: query);
  }

  Future<MenuMasterItem> saveMenuItem(MenuMasterItem item,
      {bool? creating}) async {
    final shouldCreate = creating ?? item.id.isEmpty;
    final response = await (shouldCreate ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/menu-items${shouldCreate ? '' : '/${item.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(item.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save menu item');
    }
    return MenuMasterItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteMenuItem(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/menu-items/$id'),
      headers: await authHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Unable to delete menu item');
    }
  }

  Future<List<RawMaterialItem>> getRawMaterials() async {
    final response = await getWithRetry(
        Uri.parse('${ApiConfig.baseUrl}/raw-materials'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load raw materials');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(RawMaterialItem.fromJson)
        .toList();
  }

  Future<RawMaterialItem> saveRawMaterial(RawMaterialItem item) async {
    final creating = item.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/raw-materials${creating ? '' : '/${item.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(item.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save raw material');
    }
    return RawMaterialItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteRawMaterial(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/raw-materials/$id'),
      headers: await authHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Unable to delete raw material');
    }
  }

  Future<List<RawMaterialItem>> getProduceItems() async {
    final response = await getWithRetry(
        Uri.parse('${ApiConfig.baseUrl}/produce-items'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load vegetables and fruits');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(RawMaterialItem.fromJson)
        .toList();
  }

  Future<RawMaterialItem> saveProduceItem(RawMaterialItem item) async {
    final creating = item.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/produce-items${creating ? '' : '/${item.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(item.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save vegetable/fruit item');
    }
    return RawMaterialItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteProduceItem(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/produce-items/$id'),
      headers: await authHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Unable to delete vegetable/fruit item');
    }
  }

  Future<List<RawMaterialItem>> getVesselItems() async {
    final response = await getWithRetry(
        Uri.parse('${ApiConfig.baseUrl}/vessel-items'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load vessels and utensils');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(RawMaterialItem.fromJson)
        .toList();
  }

  Future<RawMaterialItem> saveVesselItem(RawMaterialItem item) async {
    final creating = item.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/vessel-items${creating ? '' : '/${item.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(item.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save vessel/utensil item');
    }
    return RawMaterialItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteVesselItem(String id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/vessel-items/$id'),
      headers: await authHeaders(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Unable to delete vessel/utensil item');
    }
  }

  Future<List<EventMaterialDocument>> getRequirementLists() async {
    final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/requirement-lists'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load lists');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(EventMaterialDocument.fromJson)
        .toList();
  }

  Future<EventMaterialDocument> saveRequirementList(
      EventMaterialDocument document) async {
    final creating = document.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/requirement-lists${creating ? '' : '/${document.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(document.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save list');
    }
    return EventMaterialDocument.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Uri> requirementListPdfUri(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/requirement-lists/$id/pdf')
        .replace(queryParameters: {'token': token});
  }

  Future<List<AdditionalServiceItem>> getAdditionalServices() async {
    final response = await getWithRetry(
        Uri.parse('${ApiConfig.baseUrl}/bootstrap'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load additional services');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final userData = (body['userData'] as Map?) ?? {};
    return ((userData['additionalServices'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AdditionalServiceItem.fromJson)
        .toList();
  }

  Future<AdditionalServiceItem> saveAdditionalService(
      AdditionalServiceItem service) async {
    final creating = service.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/additional-services${creating ? '' : '/${service.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(service.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save additional service');
    }
    return AdditionalServiceItem.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteAdditionalService(String id) async {
    final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/additional-services/$id'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to delete additional service');
    }
  }

  Future<BusinessProfile> getBusinessProfile() async {
    final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/business-profile'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load business profile');
    }
    return BusinessProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<BusinessProfile> saveBusinessProfile(BusinessProfile profile) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/business-profile'),
      headers: await authHeaders(),
      body: jsonEncode(profile.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save business profile');
    }
    return BusinessProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AppClient>> getClients() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/clients'),
        headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load clients');
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(AppClient.fromJson)
        .toList();
  }

  Future<AppClient> saveClient(AppClient client) async {
    final creating = client.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/clients${creating ? '' : '/${client.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(client.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save client');
    }
    return AppClient.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteClient(String id) async {
    final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/clients/$id'),
        headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to delete client');
  }

  Future<List<Employee>> getEmployees() async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/employees'),
        headers: await authHeaders());
    if (response.statusCode != 200) throw Exception('Unable to load employees');
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(Employee.fromJson)
        .toList();
  }

  Future<Employee> saveEmployee(Employee employee) async {
    final creating = employee.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/employees${creating ? '' : '/${employee.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(employee.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save employee');
    }
    return Employee.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteEmployee(String id) async {
    final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/employees/$id'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to delete employee');
    }
  }

  Future<AppEvent> saveEventEmployeeAssignments(
      String eventId, List<EventEmployeeAssignment> assignments) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/events/$eventId/employee-assignments'),
      headers: await authHeaders(),
      body: jsonEncode({
        'employeeAssignments': assignments.map((item) => item.toJson()).toList()
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save employee assignments');
    }
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<AttendanceRecord>> getAttendance(
      {String? month, String? eventId}) async {
    final query = <String, String>{};
    if (month != null && month.isNotEmpty) query['month'] = month;
    if (eventId != null && eventId.isNotEmpty) query['eventId'] = eventId;
    final uri = Uri.parse('${ApiConfig.baseUrl}/attendance')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load attendance');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRecord.fromJson)
        .toList();
  }

  Future<AttendanceRecord> saveAttendance(AttendanceRecord record) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/attendance'),
      headers: await authHeaders(),
      body: jsonEncode(record.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      var message = 'Unable to save attendance';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) message = response.body.trim();
      }
      throw Exception(message);
    }
    return AttendanceRecord.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Uri> attendancePdfUri(String month) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/attendance/monthly.pdf')
        .replace(queryParameters: {
      'token': token,
      'month': month,
      'ts': DateTime.now().millisecondsSinceEpoch.toString()
    });
  }

  Future<Uri> monthlyReportPdfUri(String month) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/reports/monthly.pdf')
        .replace(queryParameters: {
      'token': token,
      'month': month,
      'ts': DateTime.now().millisecondsSinceEpoch.toString()
    });
  }

  Future<List<CustomMenu>> getCustomMenus() async {
    final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/custom-menus'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load custom menus');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(CustomMenu.fromJson)
        .toList();
  }

  Future<CustomMenu> saveCustomMenu(CustomMenu menu) async {
    final creating = menu.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/custom-menus${creating ? '' : '/${menu.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(menu.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save custom menu');
    }
    return CustomMenu.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AppEvent> createEvent(EventDraft draft) async {
    final headers = await authHeaders();
    final eventResponse = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/events'),
      headers: headers,
      body: jsonEncode({
        'name': draft.name,
        'primaryClient': draft.client,
        'mobile': draft.mobile,
        'venue': draft.venue,
        'notes': draft.notes,
        'status': 'draft',
        'addOns': draft.addOns
      }),
    );
    if (eventResponse.statusCode != 201) {
      throw Exception('Unable to create event');
    }
    final event = jsonDecode(eventResponse.body) as Map<String, dynamic>;
    final eventId = event['id'] as String;

    for (final dateConfig in draft.dates) {
      final dateResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/events/$eventId/dates'),
        headers: headers,
        body: jsonEncode({'date': dateConfig.date, 'label': dateConfig.label}),
      );
      if (dateResponse.statusCode != 201) {
        throw Exception('Unable to add event date');
      }
      final date = jsonDecode(dateResponse.body) as Map<String, dynamic>;
      final dateId = date['id'] as String;
      for (final slot in dateConfig.slots) {
        if (!slot.enabled) continue;
        await http.post(
          Uri.parse(
              '${ApiConfig.baseUrl}/events/$eventId/dates/$dateId/menu-slots'),
          headers: headers,
          body: jsonEncode({
            'type': slot.type,
            'time': slot.time,
            'pax': int.tryParse(slot.pax) ?? 0,
            'pricePerPax': slot.pricePerPax,
            'enabled': slot.enabled,
            'menuItemIds': slot.selectedMenuIds,
            'additionalServices': slot.additionalServices,
            'menuImages': slot.menuImages,
          }),
        );
      }
      for (final service in dateConfig.additionalServices) {
        await http.post(
          Uri.parse(
              '${ApiConfig.baseUrl}/events/$eventId/dates/$dateId/additional-services'),
          headers: headers,
          body: jsonEncode(service),
        );
      }
    }
    final loaded = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/events/$eventId'),
        headers: headers);
    return AppEvent.fromJson(jsonDecode(loaded.body) as Map<String, dynamic>);
  }

  Future<AppEvent> saveEventDraft(EventDraft draft, {String? eventId}) async {
    final headers = await authHeaders();
    final body = jsonEncode(draft.toJson());
    final response = eventId == null || eventId.isEmpty
        ? await http.post(Uri.parse('${ApiConfig.baseUrl}/events'),
            headers: headers, body: body)
        : await http.put(Uri.parse('${ApiConfig.baseUrl}/events/$eventId'),
            headers: headers, body: body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save event draft');
    }
    return AppEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AppEvent> recordPayment(String eventId,
      {required int amount,
      required String date,
      required String mode,
      required String reference,
      required bool settled,
      required int settledDiscount}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/events/$eventId/payments'),
      headers: await authHeaders(),
      body: jsonEncode({
        'amount': amount,
        'date': date,
        'mode': mode,
        'reference': reference,
        'settled': settled,
        'settledDiscount': settledDiscount
      }),
    );
    if (response.statusCode != 201) throw Exception('Unable to save payment');
    return getEvent(eventId);
  }

  Future<List<ManualInvoice>> getManualInvoices() async {
    final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/manual-invoices'),
        headers: await authHeaders());
    if (response.statusCode != 200) {
      throw Exception('Unable to load manual invoices');
    }
    return (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>()
        .map(ManualInvoice.fromJson)
        .toList();
  }

  Future<ManualInvoice> saveManualInvoice(ManualInvoice invoice) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/manual-invoices'),
      headers: await authHeaders(),
      body: jsonEncode(invoice.toJson()),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body is Map && body['message'] != null
          ? body['message']
          : 'Unable to save invoice');
    }
    return ManualInvoice.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Uri> manualInvoicePdfUri(String invoiceId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/manual-invoices/$invoiceId/pdf')
        .replace(queryParameters: {'token': token});
  }

  Future<AppEvent> saveMaterialDocument(
      String eventId, EventMaterialDocument document) async {
    final creating = document.id.isEmpty;
    final response = await (creating ? http.post : http.put)(
      Uri.parse(
          '${ApiConfig.baseUrl}/events/$eventId/material-documents${creating ? '' : '/${document.id}'}'),
      headers: await authHeaders(),
      body: jsonEncode(document.toJson()),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Unable to save material document');
    }
    return getEvent(eventId);
  }

  Future<Uri> documentUri(String eventId, String type, {String? dateId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    final query = <String, String>{'token': token};
    if (dateId != null && dateId.isNotEmpty) query['dateId'] = dateId;
    return Uri.parse('${ApiConfig.baseUrl}/events/$eventId/documents/$type')
        .replace(queryParameters: query);
  }

  Future<Uri> upcomingMenusUri({int days = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse('${ApiConfig.baseUrl}/documents/upcoming-menus')
        .replace(queryParameters: {'token': token, 'days': '$days'});
  }

  Future<Uri> consolidatedMenusUri(
      {List<String> eventIds = const [],
      String? date,
      String? startDate,
      String? endDate,
      String title = 'Consolidated Menus'}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    final query = <String, String>{'token': token, 'title': title};
    if (eventIds.isNotEmpty) query['eventIds'] = eventIds.join(',');
    if (date != null && date.isNotEmpty) query['date'] = date;
    if (startDate != null && startDate.isNotEmpty) {
      query['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) query['endDate'] = endDate;
    return Uri.parse('${ApiConfig.baseUrl}/documents/consolidated-menus')
        .replace(queryParameters: query);
  }

  Future<String?> consolidatedMenusError(
      {List<String> eventIds = const [],
      String? date,
      String? startDate,
      String? endDate,
      String title = 'Consolidated Menus'}) async {
    final uri = await consolidatedMenusUri(
        eventIds: eventIds,
        date: date,
        startDate: startDate,
        endDate: endDate,
        title: title);
    final response = await http.get(uri, headers: await authHeaders());
    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'] ?? '';
      return contentType.toLowerCase().contains('application/pdf')
          ? null
          : 'Consolidated menu is not available yet.';
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // Fall through to the friendly default below.
    }
    return 'No menus found for the selected events';
  }

  Future<Uri> createConsolidatedMenusUri(
      {required List<AppEvent> events,
      String? date,
      String? startDate,
      String? endDate,
      String title = 'Consolidated Menus'}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/documents/consolidated-menus'),
      headers: await authHeaders(),
      body: jsonEncode({
        'events': events.map((event) => event.toJson()).toList(),
        if (date != null && date.isNotEmpty) 'date': date,
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        'title': title,
      }),
    );
    if (response.statusCode != 201) {
      var message = 'Unable to prepare consolidated menu';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {
        // Fall through to the friendly default below.
      }
      throw Exception(message);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final exportId = body['id']?.toString() ?? '';
    if (exportId.isEmpty) {
      throw Exception('Unable to prepare consolidated menu');
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse(
            '${ApiConfig.baseUrl}/documents/consolidated-menus/$exportId')
        .replace(queryParameters: {'token': token});
  }

  Future<String?> upcomingMenusError({int days = 3}) async {
    final uri = await upcomingMenusUri(days: days);
    final response = await http.get(uri, headers: await authHeaders());
    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'] ?? '';
      return contentType.toLowerCase().contains('application/pdf')
          ? null
          : 'Upcoming menu is not available yet.';
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // Fall through to the friendly default below.
    }
    return 'No upcoming menus found';
  }

  Future<Uri> materialDocumentPdfUri(String eventId, String documentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth.token') ?? '';
    return Uri.parse(
            '${ApiConfig.baseUrl}/events/$eventId/material-documents/$documentId/pdf')
        .replace(queryParameters: {'token': token});
  }
}

List<T> decodeJsonList<T>(
    Object? value, T Function(Map<String, dynamic> json) fromJson) {
  return ((value as List?) ?? [])
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

String money(int value) =>
    '₹${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}';
String normalizeMobileText(String value) => value
    .trim()
    .replaceFirst(RegExp(r'^\+91\s*'), '')
    .replaceAll(RegExp(r'\D'), '');
bool isValidEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
String? requiredTextValidator(String? value, String label) =>
    (value ?? '').trim().isEmpty ? '$label is required' : null;
String? mobileValidator(String? value,
    {String label = 'Mobile number', bool required = true}) {
  final clean = normalizeMobileText(value ?? '');
  if (clean.isEmpty && !required) return null;
  return clean.length == 10 ? null : '$label must be 10 digits';
}

String? emailValidator(String? value,
    {String label = 'Email', bool required = true}) {
  final text = (value ?? '').trim();
  if (text.isEmpty && !required) return null;
  return isValidEmail(text) ? null : 'Enter a valid $label';
}

String? isoDateValidator(String? value,
    {String label = 'Date', bool required = true, bool noPast = false}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return required ? '$label is required' : null;
  final parsed = parseIsoDate(text);
  if (parsed == null) return 'Enter $label as YYYY-MM-DD';
  if (noPast) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (parsed.isBefore(today)) return '$label cannot be in the past';
  }
  return null;
}

String? positiveMoneyValidator(String? value, String label,
    {bool required = true, bool allowZero = false}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return required ? '$label is required' : null;
  final amount = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  if (amount == null) return 'Enter a valid $label';
  if (allowZero ? amount < 0 : amount <= 0) {
    return allowZero
        ? '$label cannot be negative'
        : '$label must be more than zero';
  }
  return null;
}

class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

TextStyle kannadaMenuTextStyle(BuildContext context,
    {double fontSize = 14, FontWeight fontWeight = FontWeight.w800}) {
  return GoogleFonts.notoSansKannada(
    textStyle: DefaultTextStyle.of(context).style,
    fontSize: fontSize,
    fontWeight: fontWeight,
  );
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.text.split('\n').first;
    final textStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: displayText, style: textStyle),
        maxLines: 1,
        textDirection: direction,
      )..layout();
      final overflow = painter.width - constraints.maxWidth;
      if (overflow <= 0) {
        controller.stop();
        return Text(displayText,
            maxLines: 1, overflow: TextOverflow.clip, style: textStyle);
      }

      final travel = overflow + 28;
      final duration = Duration(
          milliseconds: (travel * 42).round().clamp(2200, 9000).toInt());
      if (controller.duration != duration) {
        controller.duration = duration;
      }
      if (!controller.isAnimating) {
        controller.repeat(reverse: true);
      }

      return ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => Transform.translate(
            offset: Offset(-travel * controller.value, 0),
            child: child,
          ),
          child: Text(displayText,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: textStyle),
        ),
      );
    });
  }
}

final mobileInputFormatters = <TextInputFormatter>[
  TextInputFormatter.withFunction((oldValue, newValue) {
    final clean = normalizeMobileNumber(newValue.text);
    final capped = clean.length > 10 ? clean.substring(0, 10) : clean;
    return TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length));
  }),
];

String serviceLine(String name, Object? quantity, Object? unit, Object? price) {
  final count = quantity is num
      ? quantity.toInt()
      : int.tryParse(quantity?.toString() ?? '') ?? 0;
  final amount =
      price is num ? price.toInt() : int.tryParse(price?.toString() ?? '') ?? 0;
  final parts = <String>[];
  if (count > 0) parts.add('$count ${unit?.toString() ?? ''}'.trim());
  if (amount > 0) parts.add(money(amount));
  return parts.isEmpty ? name : '$name\n${parts.join(' | ')}';
}

String additionalServiceLine(Map<String, dynamic> service) => serviceLine(
    service['name']?.toString() ?? '',
    service['quantity'],
    service['unit'],
    service['price']);
String addOnLine(Map<String, dynamic> addOn) =>
    '${addOn['title']?.toString() ?? 'Add-on'}\n${money((addOn['cost'] as num?)?.toInt() ?? 0)}';

int eventMenuTotal(AppEvent event) => event.dates.fold(
    0,
    (dateSum, date) =>
        dateSum +
        date.menuSlots
            .where((slot) => slot.enabled && slot.pax > 0)
            .fold(0, (slotSum, slot) => slotSum + slot.pax * slot.pricePerPax));
int eventServiceTotal(AppEvent event) => event.dates.fold(
    0,
    (dateSum, date) =>
        dateSum +
        date.additionalServices.fold<int>(
            0,
            (sum, service) =>
                sum + ((service['price'] as num?)?.toInt() ?? 0)) +
        date.menuSlots.fold<int>(
            0,
            (slotSum, slot) =>
                slotSum +
                slot.additionalServices.fold<int>(
                    0,
                    (sum, service) =>
                        sum + ((service['price'] as num?)?.toInt() ?? 0))));
int eventAddOnTotal(AppEvent event) => event.addOns
    .fold(0, (sum, addOn) => sum + ((addOn['cost'] as num?)?.toInt() ?? 0));
int eventTotal(AppEvent event) =>
    eventMenuTotal(event) + eventAddOnTotal(event);
int eventPaid(AppEvent event) =>
    event.payments.fold(0, (sum, payment) => sum + payment.amount);
int eventSettledDiscount(AppEvent event) =>
    event.payments.fold(0, (sum, payment) => sum + payment.settledDiscount);
int eventBalance(AppEvent event) =>
    (eventTotal(event) - eventPaid(event) - eventSettledDiscount(event))
        .clamp(0, eventTotal(event));
bool eventIsIncomplete(AppEvent event) {
  final hasDetails =
      event.mobile.trim().isNotEmpty && event.primaryClient.trim().isNotEmpty;
  final hasDates = event.dates.isNotEmpty;
  final hasMenu = event.dates.any((date) => date.menuSlots.isNotEmpty);
  return !hasDetails || !hasDates || !hasMenu;
}

class EventDraft {
  String? id;
  String name = '';
  String client = '';
  String mobile = '';
  String venue = '';
  String notes = '';
  final List<Map<String, dynamic>> addOns = [];
  final List<DraftDateConfig> dates = [];

  EventDraft();

  factory EventDraft.fromEvent(AppEvent event) {
    final draft = EventDraft()
      ..id = event.id
      ..name = event.name
      ..client = event.primaryClient
      ..mobile = event.mobile
      ..venue = event.venue
      ..notes = event.notes;
    draft.addOns
        .addAll(event.addOns.map((addOn) => Map<String, dynamic>.from(addOn)));
    draft.dates.addAll(event.dates.map(DraftDateConfig.fromEventDate));
    return draft;
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'name': name,
        'primaryClient': client,
        'mobile': mobile,
        'venue': venue,
        'notes': notes,
        'status': 'draft',
        'addOns': addOns,
        'dates': dates.map((date) => date.toJson()).toList(),
      };
}

String normalizeMobileNumber(String value) {
  final text = normalizeMobileText(value);
  if (text.startsWith('91') && text.length == 12) return text.substring(2);
  return text;
}

class CustomerSuggestion {
  const CustomerSuggestion({required this.name, required this.mobile});
  final String name;
  final String mobile;
}

const _monthShortNames = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC'
];

DateTime? parseIsoDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null || month < 1 || month > 12) {
    return null;
  }
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String shortMonthLabel(String isoDate) {
  final date = parseIsoDate(isoDate);
  return date == null ? '--' : _monthShortNames[date.month - 1];
}

String dayLabel(String isoDate) {
  final date = parseIsoDate(isoDate);
  return date == null ? '--' : date.day.toString().padLeft(2, '0');
}

String readableDateLabel(String isoDate) {
  final date = parseIsoDate(isoDate);
  return date == null
      ? isoDate
      : '${date.day.toString().padLeft(2, '0')} ${_monthShortNames[date.month - 1]} ${date.year}';
}

class DraftDateConfig {
  DraftDateConfig({this.id, required this.date, this.label = ''});
  String? id;
  String date;
  String label;
  final List<MealSlotConfig> slots = [];
  final List<Map<String, dynamic>> additionalServices = [];

  factory DraftDateConfig.fromEventDate(AppEventDate date) {
    final config =
        DraftDateConfig(id: date.id, date: date.date, label: date.label);
    config.slots.addAll(date.menuSlots.map(MealSlotConfig.fromEventSlot));
    config.additionalServices.addAll(date.additionalServices
        .map((service) => Map<String, dynamic>.from(service)));
    return config;
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'date': date,
        'label': label,
        'menuSlots': slots.map((slot) => slot.toJson()).toList(),
        'additionalServices': additionalServices,
      };
}
