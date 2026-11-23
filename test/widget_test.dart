import 'package:flutter_test/flutter_test.dart';
import 'package:kunmuthaqqafan/core/l10n/app_strings.dart';
import 'package:kunmuthaqqafan/models/book.dart';

void main() {
  test('Arabic strings are RTL-first defaults', () {
    const s = AppStrings('ar');
    expect(s.isAr, isTrue);
    expect(s.appName, 'كن مثقفا');
    expect(s.statusLabel('reading'), 'أقرأ الآن');
  });

  test('Book progress clamps correctly', () {
    final b = Book(
      title: 'Test',
      author: 'Author',
      status: 'reading',
      pages: 100,
      currentPage: 25,
      dateAdded: DateTime(2026),
      dateModified: DateTime(2026),
    );
    expect(b.progress, 0.25);
  });

  test('Book map round-trip preserves fields', () {
    final b = Book(
      title: 'كتاب',
      author: 'مؤلف',
      status: 'want',
      pages: 200,
      dateAdded: DateTime(2026, 1, 1),
      dateModified: DateTime(2026, 1, 2),
    );
    final back = Book.fromMap(b.toMap());
    expect(back.title, 'كتاب');
    expect(back.status, 'want');
    expect(back.pages, 200);
  });
}
