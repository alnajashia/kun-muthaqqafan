/// Minimal AR/EN strings. Arabic is the default (RTL first).
class AppStrings {
  final String lang;
  const AppStrings(this.lang);
  bool get isAr => lang == 'ar';

  String get appName => isAr ? 'كن مثقفا' : 'Kun Muthaqqafan';
  String get home => isAr ? 'الرئيسية' : 'Home';
  String get library => isAr ? 'مكتبتي' : 'My Library';
  String get read => isAr ? 'اقرأ' : 'Read';
  String get discover => isAr ? 'اكتشف' : 'Discover';
  String get profile => isAr ? 'حسابي' : 'Profile';
  String get greeting => isAr ? 'أهلاً بك، قارئنا المثقف' : 'Welcome, cultured reader';
  String get continueReading => isAr ? 'تابع القراءة' : 'Continue reading';
  String get recentlyAdded => isAr ? 'أُضيف مؤخراً' : 'Recently added';
  String get quickActions => isAr ? 'إجراءات سريعة' : 'Quick actions';
  String get addBook => isAr ? 'أضف كتاباً' : 'Add a book';
  String get importBook => isAr ? 'استورد كتاباً' : 'Import a book';
  String get searchLibrary => isAr ? 'ابحث في مكتبتك…' : 'Search your library…';
  String get searchDiscover => isAr ? 'ابحث بالعنوان أو المؤلف أو ISBN…' : 'Search title, author or ISBN…';
  String get emptyLibrary => isAr ? 'مكتبتك فارغة بعد.\nأضف أول كتاب وابدأ رحلة الثقافة.' : 'Your library is empty.\nAdd your first book to begin.';
  String get emptyRead => isAr ? 'لا توجد كتب على الجهاز بعد.\nاستورد PDF أو EPUB أو TXT لتبدأ القراءة.' : 'No books on device yet.\nImport a PDF, EPUB or TXT to start reading.';
  String get emptyHome => isAr ? 'لا يوجد ما تتابعه الآن.\nأضف كتاباً أو استورد ملفاً من جهازك.' : 'Nothing in progress yet.\nAdd a book or import a file from your device.';
  String get title => isAr ? 'العنوان' : 'Title';
  String get author => isAr ? 'المؤلف' : 'Author';
  String get status => isAr ? 'الحالة' : 'Status';
  String get pages => isAr ? 'الصفحات' : 'Pages';
  String get save => isAr ? 'حفظ' : 'Save';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get delete => isAr ? 'حذف' : 'Delete';
  String get edit => isAr ? 'تعديل' : 'Edit';
  String get theme => isAr ? 'المظهر' : 'Theme';
  String get language => isAr ? 'اللغة' : 'Language';
  String get about => isAr ? 'حول التطبيق والاعتمادات' : 'About & credits';
  String get readingGoal => isAr ? 'هدف القراءة اليومي (دقائق)' : 'Daily reading goal (minutes)';
  String get localBooks => isAr ? 'كتب الجهاز' : 'Books on device';
  String get allBooks => isAr ? 'كل الكتب' : 'All books';
  String get addToLibrary => isAr ? 'أضف إلى المكتبة' : 'Add to library';
  String get noResults => isAr ? 'لا توجد نتائج.' : 'No results.';
  String get loading => isAr ? 'جارٍ التحميل…' : 'Loading…';
  String get offlineError => isAr ? 'تعذر الاتصال. تحقق من الإنترنت وحاول مجدداً.' : 'Could not connect. Check your internet and retry.';

  String statusLabel(String s) {
    const ar = {
      'reading': 'أقرأ الآن',
      'want': 'أريد قراءته',
      'finished': 'أنهيته',
      'dnf': 'لم أكمله',
      'paused': 'متوقف مؤقتاً',
    };
    const en = {
      'reading': 'Currently reading',
      'want': 'Want to read',
      'finished': 'Finished',
      'dnf': 'DNF',
      'paused': 'Paused',
    };
    return (isAr ? ar : en)[s] ?? s;
  }
}
