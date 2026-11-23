import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';

/// Daily review session with simplified SM-2 scheduling.
class ReviewScreen extends StatefulWidget {
  final AppStrings s;
  const ReviewScreen({super.key, required this.s});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Map<String, Object?>> _queue = [];
  int _idx = 0;
  bool _revealed = false;
  bool _loading = true;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final due = await AppDatabase.instance.dueCards();
    final total = await AppDatabase.instance.cardCount();
    if (!mounted) return;
    setState(() {
      _queue = due;
      _total = total;
      _idx = 0;
      _revealed = false;
      _loading = false;
    });
  }

  Future<void> _grade(int quality) async {
    await AppDatabase.instance.gradeCard(_queue[_idx], quality);
    setState(() {
      _idx++;
      _revealed = false;
    });
  }

  Future<void> _add() async {
    final s = widget.s;
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isAr ? 'بطاقة جديدة' : 'New card'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: frontCtrl,
              decoration: InputDecoration(
                  labelText: s.isAr ? 'السؤال / الفكرة' : 'Question / idea')),
          TextField(
              controller: backCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                  labelText: s.isAr ? 'الإجابة / الشرح' : 'Answer / explanation')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.isAr ? 'حفظ' : 'Save')),
        ],
      ),
    );
    if (ok == true &&
        frontCtrl.text.trim().isNotEmpty &&
        backCtrl.text.trim().isNotEmpty) {
      await AppDatabase.instance
          .addCard(frontCtrl.text.trim(), backCtrl.text.trim());
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.isAr ? 'مراجعة اليوم' : 'Daily review')),
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _total == 0
              ? Center(
                  child: Text(s.isAr
                      ? 'لا بطاقات بعد — أنشئ بطاقة من فكرة أو اقتباس أعجبك.'
                      : 'No cards yet — create one from an idea or quote you liked.'))
              : _idx >= _queue.length
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.celebration, size: 56),
                          const SizedBox(height: 12),
                          Text(s.isAr
                              ? 'أنهيت مراجعة اليوم. أحسنت!'
                              : 'Today\'s review is done. Well done!'),
                          Text(s.isAr
                              ? 'مجموع البطاقات: $_total'
                              : 'Total cards: $_total'),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        LinearProgressIndicator(
                            value: _queue.isEmpty
                                ? 1
                                : _idx / _queue.length),
                        const SizedBox(height: 8),
                        Text('${_idx + 1} / ${_queue.length}'),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Card(
                            child: InkWell(
                              onTap: () => setState(() => _revealed = true),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    _revealed
                                        ? _queue[_idx]['back'] as String
                                        : _queue[_idx]['front'] as String,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_revealed)
                          FilledButton(
                            onPressed: () => setState(() => _revealed = true),
                            child: Text(s.isAr ? 'أظهر الإجابة' : 'Show answer'),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              FilledButton.tonal(
                                  onPressed: () => _grade(0),
                                  child: Text(s.isAr ? 'نسيت' : 'Again')),
                              FilledButton.tonal(
                                  onPressed: () => _grade(3),
                                  child: Text(s.isAr ? 'صعب' : 'Hard')),
                              FilledButton(
                                  onPressed: () => _grade(4),
                                  child: Text(s.isAr ? 'تذكّرت' : 'Good')),
                              FilledButton(
                                  onPressed: () => _grade(5),
                                  child: Text(s.isAr ? 'سهل' : 'Easy')),
                            ],
                          ),
                      ]),
                    ),
    );
  }
}
