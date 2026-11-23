import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';

/// Statistics computed from the user's real local data only.
class StatsScreen extends StatelessWidget {
  final AppStrings s;
  const StatsScreen({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.isAr ? 'إحصائياتي' : 'My statistics')),
      body: FutureBuilder<Map<String, Object?>>(
        future: AppDatabase.instance.stats(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final st = snap.data!;
          final minutes = ((st['sessionSec'] as int) / 60).round();
          Widget card(String label, String value, IconData icon) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(value,
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(label,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              );
          final authors =
              (st['topAuthors'] as List).cast<Map<String, Object?>>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.25,
                children: [
                  card(s.isAr ? 'كتب في المكتبة' : 'Books in library',
                      '${st['totalBooks']}', Icons.library_books),
                  card(s.isAr ? 'أنهيتها' : 'Finished', '${st['finished']}',
                      Icons.check_circle),
                  card(s.isAr ? 'أقرؤها الآن' : 'Reading now',
                      '${st['reading']}', Icons.menu_book),
                  card(s.isAr ? 'أريد قراءتها' : 'Want to read',
                      '${st['want']}', Icons.bookmark),
                  card(s.isAr ? 'أنهيت هذا الشهر' : 'Finished this month',
                      '${st['finishedThisMonth']}', Icons.calendar_month),
                  card(s.isAr ? 'ملفات محلية' : 'Local files', '${st['docs']}',
                      Icons.folder),
                  card(s.isAr ? 'مجموع الصفحات' : 'Total pages',
                      '${st['totalPages']}', Icons.pages),
                  card(
                      s.isAr ? 'متوسط التقييم' : 'Average rating',
                      (st['avgRating'] as double).toStringAsFixed(1),
                      Icons.star),
                  card(s.isAr ? 'دقائق قراءة مسجلة' : 'Recorded reading minutes',
                      '$minutes', Icons.timer),
                  card(s.isAr ? 'ملاحظات' : 'Notes', '${st['notes']}',
                      Icons.note),
                ],
              ),
              if (authors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(s.isAr ? 'أكثر المؤلفين' : 'Top authors',
                    style: Theme.of(context).textTheme.titleMedium),
                ...authors.map((a) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('${a['author']}'),
                      trailing: Text('${a['c']}'),
                    )),
              ],
              if ((st['totalBooks'] as int) == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    s.isAr
                        ? 'لا توجد بيانات بعد — أضف كتباً وستظهر إحصائياتك الحقيقية هنا.'
                        : 'No data yet — add books and your real statistics will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
