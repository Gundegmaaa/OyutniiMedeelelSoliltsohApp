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

class Post {
  Post({
    required this.author,
    required this.subtitle,
    required this.title,
    required this.body,
    required this.category,
    this.avatar = PostAvatar.books,
    this.price,
    this.imageBytes,
    this.imageName,
    this.likes = 0,
    List<String>? comments,
    this.time = 'Дөнгөж сая',
  }) : comments = comments ?? [];
  final String author;
  final String subtitle;
  final String title;
  final String body;
  final PostCategory category;
  final PostAvatar avatar;
  final String? price;
  final Uint8List? imageBytes;
  final String? imageName;
  final String time;
  int likes;
  bool liked = false;
  final List<String> comments;
}

List<Post> demoPosts() => [
  Post(
    author: 'Болд • 4-р курс',
    subtitle: 'Software Engineering',
    title: '📚 Ном зарна',
    body: '2-р курст ашиглаж байсан ном.\nЦэвэрхэн, зурагтай тайлбар.',
    category: PostCategory.sale,
    price: '25,000₮',
    likes: 8,
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
    time: '3 цагийн өмнө',
    comments: ['Болд: Жижиг жишээ код бичиж үзээрэй.'],
  ),
];
