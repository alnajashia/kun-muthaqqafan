import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/offline_summarizer.dart';

/// AI summaries: honest provider configuration (user-supplied endpoint,
/// key, model), style picker, generation grounded in pasted/selected
/// text, saved summaries clearly labeled as AI-generated.
class AiScreen extends StatefulWidget {
  final AppStrings s;
  const AiScreen({super.key, required this.s});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _service = AiService();
  AiConfig? _config;
  String _style = 'quick';
  final _textCtrl = TextEditingController();
  bool _busy = false;
  String? _result;
  String? _error;
  List<Map<String, Object?>> _saved = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await _service.load();
    final saved = await AppDatabase.instance.summaries();
    if (!mounted) return;
    setState(() {
      _config = c;
      _saved = saved;
    });
  }

  Future<void> _configure() async {
    final s = widget.s;
    final baseCtrl = TextEditingController(text: _config?.baseUrl ?? '');
    final keyCtrl = TextEditingController(text: _config?.apiKey ?? '');
    final modelCtrl = TextEditingController(text: _config?.model ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isAr ? 'إعداد مزود الذكاء' : 'AI provider settings'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<AiPreset>(
              decoration: InputDecoration(
                  labelText: s.isAr ? 'اختر مزوداً جاهزاً' : 'Pick a ready provider'),
              items: aiPresets
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (p) {
                if (p == null) return;
                baseCtrl.text = p.baseUrl;
                modelCtrl.text = p.defaultModel;
              },
            ),
            TextField(
                controller: baseCtrl,
                decoration: const InputDecoration(
                    labelText: 'Base URL (OpenAI-compatible)')),
            TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API key')),
            TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: 'Model')),
            const SizedBox(height: 8),
            Text(
              s.isAr
                  ? 'المفتاح يُحفظ على جهازك فقط ولا يغادره إلا إلى مزودك.'
                  : 'Your key stays on your device and only goes to your provider.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ]),
        ),
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
    if (ok == true) {
      await _service.save(AiConfig(
        baseUrl: baseCtrl.text.trim(),
        apiKey: keyCtrl.text.trim(),
        model: modelCtrl.text.trim(),
      ));
      _load();
    }
  }

  Future<void> _generate() async {
    final s = widget.s;
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final out = await _service.summarize(
        text: _textCtrl.text.trim(),
        style: _style,
        lang: s.isAr ? 'ar' : 'en',
      );
      await AppDatabase.instance.saveSummary(_style, out);
      if (!mounted) return;
      setState(() => _result = out);
      _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _generateOffline() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    final out = _style == 'key_ideas'
        ? OfflineSummarizer.keySentences(text).map((e) => '• $e').join('\n')
        : OfflineSummarizer.summarize(text,
            maxSentences: _style == 'quick' ? 4 : 10);
    if (out.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = widget.s.isAr
              ? 'النص قصير جداً للتلخيص دون اتصال.'
              : 'Text is too short for offline summarization.';
        });
      }
      return;
    }
    await AppDatabase.instance.saveSummary('offline_$_style', out);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = out;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final configured = _config?.isConfigured ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'ملخصات الذكاء' : 'AI summaries'),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _configure),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!configured)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        s.isAr
                            ? 'لم تُعدّ مزود ذكاء بعد. التطبيق لا يحتوي مفاتيح مدمجة — أضف مزودك الخاص (أي خدمة متوافقة مع OpenAI) من زر الإعدادات بالأعلى.'
                            : 'No AI provider configured yet. The app ships no built-in keys — add your own provider (any OpenAI-compatible service) from the settings button above.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _configure,
                      child: Text(s.isAr ? 'إعداد المزود' : 'Configure provider'),
                    ),
                  ]),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: AiService.styles.keys
              .map((k) => ChoiceChip(
                    label: Text(AiService.styles[k]!),
                    selected: _style == k,
                    onSelected: (_) => setState(() => _style = k),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _textCtrl,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: s.isAr ? 'الصق النص هنا' : 'Paste text here',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(s.isAr ? 'أنشئ الملخص' : 'Generate summary'),
          onPressed: (_busy || !configured) ? null : _generate,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.offline_bolt_outlined),
          label: Text(s.isAr
              ? 'تلخيص فوري دون إنترنت (مدمج)'
              : 'Instant offline summary (built-in)'),
          onPressed: _busy ? null : _generateOffline,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            s.isAr
                ? 'التلخيص المدمج يعمل على جهازك دون مفتاح: يستخرج أهم جمل النص الأصلي كما هي دون اختراع محتوى.'
                : 'The built-in summarizer runs on your device with no key: it extracts the most important original sentences without inventing content.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 16),
          Chip(
              avatar: const Icon(Icons.auto_awesome, size: 16),
              label: Text(s.isAr ? 'محتوى مُنشأ بالذكاء' : 'AI-generated')),
          const SizedBox(height: 8),
          SelectableText(_result!),
        ],
        const SizedBox(height: 24),
        Text(s.isAr ? 'ملخصات محفوظة' : 'Saved summaries',
            style: Theme.of(context).textTheme.titleMedium),
        ..._saved.map((r) => Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(AiService.styles[(r['style'] as String).replaceFirst('offline_', '')] ?? '${r['style']}'),
                subtitle: Text(
                  r['content'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await AppDatabase.instance.deleteSummary(r['id'] as int);
                    _load();
                  },
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s.isAr ? 'محتوى مُنشأ بالذكاء' : 'AI-generated'),
                    content: SingleChildScrollView(
                        child: SelectableText(r['content'] as String)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(s.isAr ? 'إغلاق' : 'Close')),
                    ],
                  ),
                ),
              ),
            )),
      ]),
    );
  }
}
