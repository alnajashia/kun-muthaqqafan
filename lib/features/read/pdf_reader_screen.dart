import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/db/app_database.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/book.dart';

/// PDF reader backed by the native Android PdfRenderer channel ("kun/pdf").
/// Xodo-style reading: continuous vertical scroll or horizontal paging,
/// pinch zoom per page, highlight annotations drawn over pages and saved.
/// Note: PdfRenderer renders pages as images and exposes no text layer,
/// so text selection/copy is not available for PDFs (EPUB/TXT support it).
class PdfReaderScreen extends StatefulWidget {
  final AppStrings s;
  final LocalDoc doc;
  const PdfReaderScreen({super.key, required this.s, required this.doc});
  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  static const _channel = MethodChannel('kun/pdf');

  int? _pageCount;
  int _currentPage = 0;
  String? _error;
  bool _vertical = true; // continuous vertical scroll (default)
  bool _annotate = false;
  String _color = 'yellow';
  Color _bg = const Color(0xFFECEFF1);
  final Map<int, Uint8List> _cache = {};
  final Map<int, Future<Uint8List>> _pending = {};
  List<Map<String, Object?>> _highlights = [];
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  static const _colors = {
    'yellow': Color(0x66FFEB3B),
    'green': Color(0x664CAF50),
    'blue': Color(0x6642A5F5),
    'pink': Color(0x66EC407A),
    'orange': Color(0x66FF9800),
  };

  @override
  void initState() {
    super.initState();
    _currentPage = widget.doc.lastPage;
    _open();
    _loadHighlights();
  }

  Future<void> _open() async {
    try {
      final count = await _channel.invokeMethod<int>('open', {'path': widget.doc.filePath});
      if (!mounted) return;
      setState(() => _pageCount = count ?? 0);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'PDF error');
    }
  }

  Future<void> _loadHighlights() async {
    if (widget.doc.id == null) return;
    final rows = await AppDatabase.instance.highlightsForDoc(widget.doc.id!);
    if (mounted) setState(() => _highlights = rows);
  }

  Future<Uint8List> _render(int page) {
    if (_cache.containsKey(page)) return Future.value(_cache[page]);
    return _pending.putIfAbsent(page, () async {
      final bytes = await _channel.invokeMethod<Uint8List>('render', {
        'page': page,
        'width': 1400,
      });
      _pending.remove(page);
      final result = bytes ?? Uint8List(0);
      if (_cache.length > 12) _cache.remove(_cache.keys.first);
      _cache[page] = result;
      return result;
    });
  }

  Future<void> _saveProgress(int page) async {
    _currentPage = page;
    if (widget.doc.id != null && _pageCount != null && _pageCount! > 0) {
      await AppDatabase.instance.updateDocPage(widget.doc.id!, page, _pageCount!);
    }
  }

  Future<void> _jumpToPage() async {
    final s = widget.s;
    final controller = TextEditingController(text: '${_currentPage + 1}');
    final target = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.isAr ? 'الانتقال إلى صفحة' : 'Go to page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - $_pageCount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(controller.text)),
            child: Text(s.isAr ? 'اذهب' : 'Go'),
          ),
        ],
      ),
    );
    if (target == null || _pageCount == null) return;
    final page = (target - 1).clamp(0, _pageCount! - 1);
    if (_vertical) {
      // Estimate offset: pages are full-width images; scroll roughly.
      final width = MediaQuery.of(context).size.width - 16;
      await _scrollController.animateTo(page * width * 1.42,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } else {
      await _pageController.animateToPage(page,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
    await _saveProgress(page);
    if (mounted) setState(() {});
  }

  Widget _pageView(int page) {
    return FutureBuilder<Uint8List>(
      future: _render(page),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 420, child: Center(child: CircularProgressIndicator()));
        }
        if (snap.data!.isEmpty) {
          return const SizedBox(
              height: 200, child: Center(child: Icon(Icons.broken_image_outlined)));
        }
        return _AnnotatablePage(
          imageBytes: snap.data!,
          highlights: _highlights.where((h) => h['page'] == page).toList(),
          colors: _colors,
          annotate: _annotate,
          onRectDrawn: (rect) async {
            if (widget.doc.id == null) return;
            await AppDatabase.instance.addHighlightRect(
              docId: widget.doc.id!,
              page: page,
              color: _color,
              rectJson: jsonEncode({
                'l': rect.left, 't': rect.top, 'r': rect.right, 'b': rect.bottom,
              }),
            );
            await _loadHighlights();
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _channel.invokeMethod('close');
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(widget.doc.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_vertical ? Icons.view_agenda : Icons.view_carousel),
            tooltip: s.isAr ? 'اتجاه التمرير' : 'Scroll direction',
            onPressed: () => setState(() => _vertical = !_vertical),
          ),
          IconButton(
            icon: Icon(_annotate ? Icons.highlight : Icons.highlight_outlined),
            tooltip: s.isAr ? 'تظليل' : 'Highlight',
            onPressed: () => setState(() => _annotate = !_annotate),
          ),
          PopupMenuButton<Color>(
            icon: const Icon(Icons.format_color_fill),
            tooltip: s.isAr ? 'لون الخلفية' : 'Background',
            onSelected: (c) => setState(() => _bg = c),
            itemBuilder: (_) => [
              PopupMenuItem(value: const Color(0xFFECEFF1), child: Text(s.isAr ? 'رمادي فاتح' : 'Light grey')),
              PopupMenuItem(value: const Color(0xFFF5EFE0), child: Text(s.isAr ? 'بيج' : 'Sepia')),
              PopupMenuItem(value: const Color(0xFF212121), child: Text(s.isAr ? 'داكن' : 'Dark')),
              PopupMenuItem(value: Colors.white, child: Text(s.isAr ? 'أبيض' : 'White')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: s.isAr ? 'إشارة مرجعية' : 'Bookmark',
            onPressed: () async {
              if (widget.doc.id == null) return;
              await AppDatabase.instance.addBookmark(widget.doc.id!, _currentPage + 1, null);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(s.isAr
                        ? 'أُضيفت إشارة للصفحة ${_currentPage + 1}'
                        : 'Bookmarked page ${_currentPage + 1}')));
              }
            },
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : _pageCount == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  if (_annotate)
                    Container(
                      color: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Text(s.isAr ? 'لون التظليل:' : 'Highlight color:'),
                        const SizedBox(width: 8),
                        for (final entry in _colors.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () => setState(() => _color = entry.key),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: entry.value.withValues(alpha: 1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _color == entry.key
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                                    width: _color == entry.key ? 3 : 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(s.isAr ? 'اسحب فوق النص للتظليل' : 'Drag over text to highlight',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  Expanded(
                    child: _vertical
                        ? ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: _pageCount,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InteractiveViewer(
                                minScale: 1, maxScale: 5,
                                child: _pageView(i),
                              ),
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: _pageCount,
                            onPageChanged: (i) {
                              _saveProgress(i);
                              setState(() {});
                            },
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: InteractiveViewer(
                                minScale: 1, maxScale: 5,
                                child: _pageView(i),
                              ),
                            ),
                          ),
                  ),
                  Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage > 0
                            ? () {
                                final p = _currentPage - 1;
                                if (!_vertical) _pageController.jumpToPage(p);
                                _saveProgress(p);
                                setState(() {});
                              }
                            : null,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _jumpToPage,
                          child: Text(
                            s.isAr
                                ? 'صفحة ${_currentPage + 1} من $_pageCount'
                                : 'Page ${_currentPage + 1} of $_pageCount',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _pageCount != null && _currentPage < _pageCount! - 1
                            ? () {
                                final p = _currentPage + 1;
                                if (!_vertical) _pageController.jumpToPage(p);
                                _saveProgress(p);
                                setState(() {});
                              }
                            : null,
                      ),
                    ]),
                  ),
                ]),
    );
  }
}

/// One rendered page image with saved highlight rectangles overlaid.
/// In annotate mode, dragging draws a new rectangle (normalized 0..1).
class _AnnotatablePage extends StatefulWidget {
  final Uint8List imageBytes;
  final List<Map<String, Object?>> highlights;
  final Map<String, Color> colors;
  final bool annotate;
  final void Function(Rect normalized) onRectDrawn;
  const _AnnotatablePage({
    required this.imageBytes,
    required this.highlights,
    required this.colors,
    required this.annotate,
    required this.onRectDrawn,
  });
  @override
  State<_AnnotatablePage> createState() => _AnnotatablePageState();
}

class _AnnotatablePageState extends State<_AnnotatablePage> {
  Offset? _start;
  Offset? _end;

  Rect? _normalizedRect(Size size) {
    if (_start == null || _end == null) return null;
    final r = Rect.fromPoints(_start!, _end!);
    if (r.width < 8 || r.height < 8) return null;
    return Rect.fromLTRB(
      (r.left / size.width).clamp(0, 1),
      (r.top / size.height).clamp(0, 1),
      (r.right / size.width).clamp(0, 1),
      (r.bottom / size.height).clamp(0, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onPanStart: widget.annotate
            ? (d) => setState(() { _start = d.localPosition; _end = d.localPosition; })
            : null,
        onPanUpdate: widget.annotate
            ? (d) => setState(() => _end = d.localPosition)
            : null,
        onPanEnd: widget.annotate
            ? (_) {
                final size = Size(constraints.maxWidth,
                    constraints.maxWidth * 1.42);
                final rect = _normalizedRect(size);
                if (rect != null) widget.onRectDrawn(rect);
                setState(() { _start = null; _end = null; });
              }
            : null,
        child: Stack(children: [
          Image.memory(widget.imageBytes, width: double.infinity, fit: BoxFit.fitWidth),
          Positioned.fill(
            child: CustomPaint(
              painter: _HighlightPainter(
                highlights: widget.highlights,
                colors: widget.colors,
                draft: (_start != null && _end != null)
                    ? Rect.fromPoints(_start!, _end!)
                    : null,
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _HighlightPainter extends CustomPainter {
  final List<Map<String, Object?>> highlights;
  final Map<String, Color> colors;
  final Rect? draft;
  _HighlightPainter({required this.highlights, required this.colors, this.draft});

  @override
  void paint(Canvas canvas, Size size) {
    for (final h in highlights) {
      final raw = h['rect'] as String?;
      if (raw == null || raw.isEmpty) continue;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final rect = Rect.fromLTRB(
          (m['l'] as num).toDouble() * size.width,
          (m['t'] as num).toDouble() * size.height,
          (m['r'] as num).toDouble() * size.width,
          (m['b'] as num).toDouble() * size.height,
        );
        final paint = Paint()..color = colors[h['color']] ?? const Color(0x66FFEB3B);
        canvas.drawRect(rect, paint);
      } catch (_) {}
    }
    if (draft != null) {
      final paint = Paint()
        ..color = const Color(0x66FFEB3B)
        ..style = PaintingStyle.fill;
      canvas.drawRect(draft!, paint);
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.highlights != highlights || old.draft != draft;
}
