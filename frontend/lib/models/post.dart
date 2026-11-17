import 'dart:typed_data';

enum PostCategory {
  sale('Худалдах зар'),
  exchange('Солилцох зар'),
  rental('Түрээслүүлэх зар'),
  question('Асуулт'),
  teacher('Багш');

  const PostCategory(this.label);
  final String label;
}

enum PostAvatar {
  books('Ном', '📚', assetPath: 'assets/icons/books.png'),
  laptop('Компьютер', '💻'),
  bag('Цүнх', '🎒'),
  home('Байр', '🏠'),
  bicycle('Унаа', '🚲'),
  person('Аватар', '🧑‍🎓'),
  chat('Асуулт', '💬'),
  gift('Бусад', '🎁');

  const PostAvatar(this.label, this.symbol, {this.assetPath});
  final String label;
  final String symbol;
  final String? assetPath;
}

/// Courses a post can be limited to.
const postAudienceCourses = [1, 2, 3, 4, 5, 6];

/// 86000 → "86,000₮".
String formatMoney(num amount) => '${groupThousands('${amount.round()}')}₮';

/// Inserts thousands separators into a string of digits: "25000" → "25,000".
String groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// "Дөнгөж сая", "5 минутын өмнө", … then the date after a week.
String relativeTime(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(time);
  if (elapsed.inMinutes < 1) return 'Дөнгөж сая';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} минутын өмнө';
  if (elapsed.inHours < 24) return '${elapsed.inHours} цагийн өмнө';
  if (elapsed.inDays < 7) return '${elapsed.inDays} өдрийн өмнө';
  final local = time.toLocal();
  return '${local.year}.${local.month.toString().padLeft(2, '0')}.'
      '${local.day.toString().padLeft(2, '0')}';
}

/// "Бүх курс" or "1, 3-р курс".
String audienceLabel(List<int> courses) =>
    courses.isEmpty ? 'Бүх курс' : '${courses.join(', ')}-р курс';

class Post {
  Post({
    required this.author,
    required this.subtitle,
    required this.title,
    required this.body,
    required this.category,
    this.id,
    this.avatar = PostAvatar.books,
    this.price,
    this.imageBytes,
    this.imageName,
    this.imageUrl,
    this.likes = 0,
    this.liked = false,
    this.isMine = false,
    this.createdAt,
    List<int>? audienceCourses,
    List<String>? likers,
    List<String>? comments,
    this.time = 'Дөнгөж сая',
  }) : comments = comments ?? [],
       likers = likers ?? [],
       audienceCourses = audienceCourses ?? const [];

  /// Server id; null for demo posts and posts not saved to the backend.
  int? id;
  final String author;
  final String subtitle;
  final String title;
  final String body;
  final PostCategory category;
  final PostAvatar avatar;
  final String? price;
  final Uint8List? imageBytes;
  final String? imageName;
  final String? imageUrl;
  final String time;
  final DateTime? createdAt;
  final bool isMine;

  /// Courses that may see the post; empty means everyone.
  final List<int> audienceCourses;
  int likes;
  bool liked;

  /// Names of people who reacted, for posts that are not on the backend.
  final List<String> likers;
  final List<String> comments;

  bool get hasImage => imageBytes != null || imageUrl != null;

  String get timeLabel => createdAt == null ? time : relativeTime(createdAt!);

  bool visibleTo(int? course) =>
      isMine ||
      audienceCourses.isEmpty ||
      (course != null && audienceCourses.contains(course));
}

const _demoLikers = [
  'Ану • 2-р курс',
  'Тэмүүлэн • 3-р курс',
  'Номин • 1-р курс',
  'Бат-Эрдэнэ • 4-р курс',
  'Сараа • 2-р курс',
  'Мөнх • 3-р курс',
  'Анужин • 4-р курс',
  'Болд • 4-р курс',
  'Золбоо • 1-р курс',
  'Уянга • 2-р курс',
  'Тэргэл • 3-р курс',
  'Энхжин • 1-р курс',
  'Хулан • 4-р курс',
  'Төгөлдөр • 2-р курс',
  'Маралгоо • 3-р курс',
];

List<Post> demoPosts() => [
  Post(
    author: 'Болд • 4-р курс',
    subtitle: 'Software Engineering',
    title: '📚 Ном зарна',
    body: '2-р курст ашиглаж байсан ном.\nЦэвэрхэн, зурагтай тайлбар.',
    category: PostCategory.sale,
    price: formatMoney(25000),
    likes: 8,
    likers: _demoLikers.take(8).toList(),
    time: '1 цагийн өмнө',
    comments: [
      'Ану: Ямар хичээлийн ном бэ?',
      'Болд: Database, OOP хоёрын ном.',
      'Тэмүүлэн: Авъя, хаана уулзах вэ?',
      'Болд: Сургуулийн номын санд.',
    ],
  ),
  Post(
    author: '📢 Сургалтын алба',
    subtitle: '',
    title: 'Намрын улирлын шалгалтын\nхуваарь шинэчлэгдлээ.',
    body: 'Шалгалтын дэлгэрэнгүй хуваарийг сургалтын албанаас авна уу.',
    category: PostCategory.teacher,
    avatar: PostAvatar.person,
    likes: 15,
    likers: _demoLikers.toList(),
    time: '2 цагийн өмнө',
    comments: [
      'Ану: Баярлалаа.',
      'Болд: Хуваарийг хаанаас авах вэ?',
      'Сургалтын алба: 201 тоотод хандана уу.',
    ],
  ),
  Post(
    author: 'Ану • 2-р курс',
    subtitle: 'Information System',
    title: '💬 OOP хичээлийн зөвлөгөө хэрэгтэй',
    body:
        'Дээд курсын оюутнуудаас inheritance, polymorphism-ийн талаар асуух гэсэн юм. Яаж давтвал үр дүнтэй вэ?',
    category: PostCategory.question,
    avatar: PostAvatar.chat,
    likes: 3,
    likers: _demoLikers.skip(3).take(3).toList(),
    time: '3 цагийн өмнө',
    comments: ['Болд: Жижиг жишээ код бичиж үзээрэй.'],
  ),
];
