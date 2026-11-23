class Book {
  final int? id;
  final String title;
  final String? subtitle;
  final String author;
  final String? description;
  final String status; // reading | want | finished | dnf | paused
  final bool favourite;
  final int? rating;
  final int? pages;
  final int currentPage;
  final String? publisher;
  final int? publicationYear;
  final String? isbn;
  final String? olid;
  final String? coverUrl;
  final String? tags;
  final String? myReview;
  final String? language;
  final String? genre;
  final DateTime dateAdded;
  final DateTime dateModified;
  final DateTime? startDate;
  final DateTime? finishDate;

  const Book({
    this.id,
    required this.title,
    this.subtitle,
    required this.author,
    this.description,
    required this.status,
    this.favourite = false,
    this.rating,
    this.pages,
    this.currentPage = 0,
    this.publisher,
    this.publicationYear,
    this.isbn,
    this.olid,
    this.coverUrl,
    this.tags,
    this.myReview,
    this.language,
    this.genre,
    required this.dateAdded,
    required this.dateModified,
    this.startDate,
    this.finishDate,
  });

  double get progress =>
      (pages == null || pages == 0) ? 0 : (currentPage / pages!).clamp(0, 1);

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'author': author,
        'description': description,
        'status': status,
        'favourite': favourite ? 1 : 0,
        'rating': rating,
        'pages': pages,
        'current_page': currentPage,
        'publisher': publisher,
        'publication_year': publicationYear,
        'isbn': isbn,
        'olid': olid,
        'cover_url': coverUrl,
        'tags': tags,
        'my_review': myReview,
        'language': language,
        'genre': genre,
        'date_added': dateAdded.toIso8601String(),
        'date_modified': dateModified.toIso8601String(),
        'start_date': startDate?.toIso8601String(),
        'finish_date': finishDate?.toIso8601String(),
      };

  factory Book.fromMap(Map<String, Object?> m) => Book(
        id: m['id'] as int?,
        title: m['title'] as String,
        subtitle: m['subtitle'] as String?,
        author: m['author'] as String,
        description: m['description'] as String?,
        status: m['status'] as String,
        favourite: (m['favourite'] as int? ?? 0) == 1,
        rating: m['rating'] as int?,
        pages: m['pages'] as int?,
        currentPage: m['current_page'] as int? ?? 0,
        publisher: m['publisher'] as String?,
        publicationYear: m['publication_year'] as int?,
        isbn: m['isbn'] as String?,
        olid: m['olid'] as String?,
        coverUrl: m['cover_url'] as String?,
        tags: m['tags'] as String?,
        myReview: m['my_review'] as String?,
        language: m['language'] as String?,
        genre: m['genre'] as String?,
        dateAdded: DateTime.parse(m['date_added'] as String),
        dateModified: DateTime.parse(m['date_modified'] as String),
        startDate: m['start_date'] == null
            ? null
            : DateTime.parse(m['start_date'] as String),
        finishDate: m['finish_date'] == null
            ? null
            : DateTime.parse(m['finish_date'] as String),
      );

  Book copyWith({
    int? id,
    String? title,
    String? subtitle,
    String? author,
    String? description,
    String? status,
    bool? favourite,
    int? rating,
    int? pages,
    int? currentPage,
    String? publisher,
    int? publicationYear,
    String? isbn,
    String? olid,
    String? coverUrl,
    String? tags,
    String? myReview,
    String? language,
    String? genre,
    DateTime? dateAdded,
    DateTime? dateModified,
    DateTime? startDate,
    DateTime? finishDate,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        author: author ?? this.author,
        description: description ?? this.description,
        status: status ?? this.status,
        favourite: favourite ?? this.favourite,
        rating: rating ?? this.rating,
        pages: pages ?? this.pages,
        currentPage: currentPage ?? this.currentPage,
        publisher: publisher ?? this.publisher,
        publicationYear: publicationYear ?? this.publicationYear,
        isbn: isbn ?? this.isbn,
        olid: olid ?? this.olid,
        coverUrl: coverUrl ?? this.coverUrl,
        tags: tags ?? this.tags,
        myReview: myReview ?? this.myReview,
        language: language ?? this.language,
        genre: genre ?? this.genre,
        dateAdded: dateAdded ?? this.dateAdded,
        dateModified: dateModified ?? this.dateModified,
        startDate: startDate ?? this.startDate,
        finishDate: finishDate ?? this.finishDate,
      );
}

class LocalDoc {
  final int? id;
  final String title;
  final String filePath;
  final String format; // pdf | epub | txt
  final int fileSize;
  final DateTime dateModified;
  final DateTime dateAdded;
  final DateTime? lastOpened;
  final int lastPage;
  final double progress;
  final bool favourite;

  const LocalDoc({
    this.id,
    required this.title,
    required this.filePath,
    required this.format,
    required this.fileSize,
    required this.dateModified,
    required this.dateAdded,
    this.lastOpened,
    this.lastPage = 0,
    this.progress = 0,
    this.favourite = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'file_path': filePath,
        'format': format,
        'file_size': fileSize,
        'date_modified': dateModified.toIso8601String(),
        'date_added': dateAdded.toIso8601String(),
        'last_opened': lastOpened?.toIso8601String(),
        'last_page': lastPage,
        'progress': progress,
        'favourite': favourite ? 1 : 0,
      };

  factory LocalDoc.fromMap(Map<String, Object?> m) => LocalDoc(
        id: m['id'] as int?,
        title: m['title'] as String,
        filePath: m['file_path'] as String,
        format: m['format'] as String,
        fileSize: m['file_size'] as int? ?? 0,
        dateModified: DateTime.parse(m['date_modified'] as String),
        dateAdded: DateTime.parse(m['date_added'] as String),
        lastOpened: m['last_opened'] == null
            ? null
            : DateTime.parse(m['last_opened'] as String),
        lastPage: m['last_page'] as int? ?? 0,
        progress: (m['progress'] as num? ?? 0).toDouble(),
        favourite: (m['favourite'] as int? ?? 0) == 1,
      );
}
