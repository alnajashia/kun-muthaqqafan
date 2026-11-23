import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

class ProfileScreen extends StatelessWidget {
  final AppStrings s;
  final ThemeMode themeMode;
  final String lang;
  final int dailyGoal;
  final ValueChanged<ThemeMode> onTheme;
  final ValueChanged<String> onLang;
  final ValueChanged<int> onGoal;

  const ProfileScreen({
    super.key,
    required this.s,
    required this.themeMode,
    required this.lang,
    required this.dailyGoal,
    required this.onTheme,
    required this.onLang,
    required this.onGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/logo.png', width: 64, height: 64),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.appName,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(s.isAr
                          ? 'مكتبتك الشخصية ورفيق قراءتك اليومي'
                          : 'Your personal library and daily reading companion'),
                    ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Text(s.theme, style: Theme.of(context).textTheme.titleMedium),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
                value: ThemeMode.system,
                label: Text(s.isAr ? 'النظام' : 'System')),
            ButtonSegment(
                value: ThemeMode.light,
                label: Text(s.isAr ? 'فاتح' : 'Light')),
            ButtonSegment(
                value: ThemeMode.dark,
                label: Text(s.isAr ? 'داكن' : 'Dark')),
          ],
          selected: {themeMode},
          onSelectionChanged: (v) => onTheme(v.first),
        ),
        const SizedBox(height: 16),
        Text(s.language, style: Theme.of(context).textTheme.titleMedium),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ar', label: Text('العربية')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {lang},
          onSelectionChanged: (v) => onLang(v.first),
        ),
        const SizedBox(height: 16),
        Text(s.readingGoal, style: Theme.of(context).textTheme.titleMedium),
        Slider(
          value: dailyGoal.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          label: '$dailyGoal',
          onChanged: (v) => onGoal(v.round()),
        ),
        Text('$dailyGoal ${s.isAr ? 'دقيقة يومياً' : 'minutes daily'}'),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(s.about),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: s.appName,
            applicationVersion: '1.0.0',
            children: [
              Text(s.isAr
                  ? '«كن مثقفا» تطبيق أصلي مستوحى من تجربة Openreads مفتوح المصدر (mateusz-bak/openreads) المرخّص تحت GPL-2.0. لم يُنسخ أي كود أو شعار من المشروع الأصلي؛ أُعيد بناء التجربة من الصفر مع توسعات للقراءة والملاحظات والمراجعة. بيانات الكتب من Open Library.'
                  : 'Kun Muthaqqafan is an original app inspired by the open-source Openreads (mateusz-bak/openreads), licensed under GPL-2.0. No code or branding was copied; the experience was rebuilt from scratch with reading, notes and review extensions. Book data from Open Library.'),
            ],
          ),
        ),
      ]),
    );
  }
}
