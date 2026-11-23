import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';

class HomeScreen extends StatefulWidget {
  final AppStrings s;
  final VoidCallback onAddBook;
  final VoidCallback onImport;
  const HomeScreen(
      {super.key, required this.s, required this.onAddBook, required this.onImport});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Book>> _reading;
  late Future<List<Book>> _recent;

  @override
  void initState() {
    super.initState();
    _reading = AppDatabase.instance.books(status: 'reading');
    _recent = AppDatabase.instance.books();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final date = DateFormat.yMMMMEEEEd(s.isAr ? 'ar' : 'en').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(s.appName)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.greeting, style: Theme.of(context).textTheme.headlineSmall),
        Text(date, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(
          s.isAr
              ? '«خير جليس في الزمان كتاب» — صفحة اليوم تصنع مثقف الغد.'
              : '"A book is the best companion." — today\'s page builds tomorrow\'s mind.',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 20),
        Text(s.continueReading, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        FutureBuilder<List<Book>>(
          future: _reading,
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.isEmpty) {
              return Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.emptyHome)));
            }
            return Column(
              children: snap.data!
                  .map((b) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.menu_book),
                          title: Text(b.title),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.author),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(value: b.progress),
                              ]),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(s.quickActions, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: widget.onAddBook,
              icon: const Icon(Icons.add),
              label: Text(s.addBook)),
          OutlinedButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.file_upload),
              label: Text(s.importBook)),
        ]),
        const SizedBox(height: 20),
        Text(s.recentlyAdded, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        FutureBuilder<List<Book>>(
          future: _recent,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final items = snap.data!.take(5).toList();
            if (items.isEmpty) return Text(s.noResults);
            return Column(
              children: items
                  .map((b) => ListTile(
                        leading: const Icon(Icons.book),
                        title: Text(b.title),
                        subtitle: Text(b.author),
                      ))
                  .toList(),
            );
          },
        ),
      ]),
    );
  }
}
