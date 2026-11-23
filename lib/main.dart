import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(KunApp(prefs: prefs));
}

class KunApp extends StatefulWidget {
  final SharedPreferences prefs;
  const KunApp({super.key, required this.prefs});
  @override
  State<KunApp> createState() => _KunAppState();
}

class _KunAppState extends State<KunApp> {
  late ThemeMode _themeMode;
  late String _lang;
  late int _goal;

  @override
  void initState() {
    super.initState();
    final t = widget.prefs.getString('theme') ?? 'system';
    _themeMode = t == 'light'
        ? ThemeMode.light
        : t == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;
    _lang = widget.prefs.getString('lang') ?? 'ar';
    _goal = widget.prefs.getInt('daily_goal') ?? 20;
  }

  Future<void> _setTheme(ThemeMode m) async {
    await widget.prefs.setString(
        'theme', m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system');
    setState(() => _themeMode = m);
  }

  Future<void> _setLang(String l) async {
    await widget.prefs.setString('lang', l);
    setState(() => _lang = l);
  }

  Future<void> _setGoal(int g) async {
    await widget.prefs.setInt('daily_goal', g);
    setState(() => _goal = g);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(_lang);
    return MaterialApp(
      title: s.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: Locale(_lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(
        s: s,
        themeMode: _themeMode,
        lang: _lang,
        dailyGoal: _goal,
        onTheme: _setTheme,
        onLang: _setLang,
        onGoal: _setGoal,
      ),
    );
  }
}
