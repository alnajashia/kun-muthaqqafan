import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';

/// PDF reader backed by Android's native PdfRenderer (platform channel
/// "kun/pdf" in MainActivity): paged rendering, pinch zoom via
/// InteractiveViewer, page jump, bookmarks, last-page persistence.
class PdfReaderScreen extends StatefulWidget {
  final AppStrings s;
  final LocalDoc doc;
  const PdfReaderScreen({super.key, required this.s, required this.doc});
  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  static const _channel = MethodChannel('kun/pdf');
  int _page = 0; // 0-based
  int _total = 0;
  Uint8List? _image;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _channel.invokeMethod('close');
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final count = await _channel.invokeMethod<int>(
          'open', {'path': widget.doc.filePath});
      if (!mounted) return;
      setState(() {
        _total = count ?? 0;
        _page = widget.doc.lastPage.clamp(0, _total == 0 ? 0 : _total - 1);
      });
      await _render();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? '$e');
    }
  }

  Future<void> _render() async {
    if (_total == 0) return;
    setState(() => _busy = true);
    try {
      final width = (MediaQuery.of(context).size.width *
              MediaQuery.of(context).devicePixelRatio)
          .round()
          .clamp(600, 2400);
      final bytes = await _channel.invokeMethod<Uint8List>(
          'render', {'page': _page, 'width': width});
      if (!mounted) return;
      setState(() => _image = bytes);
      if (widget.doc.id != null) {
        await AppDatabase.instance
            .updateDocPage(widget.doc.id!, _page, _total);
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _go(int page) async {
    if (page < 0 || page >= _total) return;
    setState(() => _page = page);
    await _render();
  }

  Future<void> _jump() async {
    final s = widget.s;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isAr ? 'اذهب إلى صفحة' : 'Go to page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: '1 – $_total'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.isAr ? 'اذهب' : 'Go')),
        ],
      ),
    );
    final target = int.tryParse(ctrl.text.trim());
    if (ok == true && target != null) await _go(target - 1);
  }

  Future<void> _addBookmark() async {
    await AppDatabase.instance.addBookmark(widget.doc.id!, _page + 1, null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.s.isAr
              ? 'حُفظت علامة عند الصفحة ${_page + 1}'
              : 'Bookmark saved at page ${_page + 1}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _addBookmark),
          IconButton(
              icon: const Icon(Icons.find_in_page_outlined), onPressed: _jump),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : Column(children: [
              Expanded(
                child: _image == null
                    ? const Center(child: CircularProgressIndicator())
                    : InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Center(child: Image.memory(_image!)),
                      ),
              ),
              if (_busy) const LinearProgressIndicator(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: Text(s.isAr ? 'السابق' : 'Previous'),
                    onPressed: _page > 0 ? () => _go(_page - 1) : null,
                  ),
                  Text('${_page + 1} / $_total'),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(s.isAr ? 'التالي' : 'Next'),
                    onPressed:
                        _page < _total - 1 ? () => _go(_page + 1) : null,
                  ),
                ],
              ),
            ]),
    );
  }
}
