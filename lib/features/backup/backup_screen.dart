import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../core/services/backup_service.dart';

/// Backup & export: JSON full backup, CSV books export, restore from file.
class BackupScreen extends StatefulWidget {
  final AppStrings s;
  const BackupScreen({super.key, required this.s});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = BackupService();
  List<String> _files = [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final files = await _service.listBackups();
    if (mounted) setState(() => _files = files.map((f) => f.path).toList());
  }

  Future<void> _run(Future<String> Function() op) async {
    try {
      final path = await op();
      setState(() => _message = path);
      await _refresh();
    } catch (e) {
      setState(() => _message = '$e');
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final count = await _service.restoreJson(File(path));
      setState(() => _message = widget.s.isAr
          ? 'استُعيد $count سجل'
          : 'Restored $count records');
    } catch (e) {
      setState(() => _message = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(
          title: Text(s.isAr ? 'النسخ الاحتياطي' : 'Backup & export')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          s.isAr
              ? 'نسخك محلية بالكامل على جهازك. الاستعادة لا تحذف ملفات كتبك الأصلية أبداً.'
              : 'Your backups are fully local on your device. Restore never deletes your original book files.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.save),
          label: Text(s.isAr ? 'نسخة احتياطية JSON' : 'JSON backup'),
          onPressed: () => _run(_service.exportJson),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.table_view),
          label: Text(s.isAr ? 'تصدير الكتب CSV' : 'Export books CSV'),
          onPressed: () => _run(_service.exportBooksCsv),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.restore),
          label: Text(s.isAr ? 'استعادة من ملف' : 'Restore from file'),
          onPressed: _restore,
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          SelectableText(_message!),
        ],
        const SizedBox(height: 24),
        Text(s.isAr ? 'نسخ سابقة' : 'Previous backups',
            style: Theme.of(context).textTheme.titleMedium),
        ..._files.map((f) => ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(p.basename(f)),
              subtitle: Text(f),
            )),
      ]),
    );
  }
}
