import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.displayName = 'Гүндэгмаа'});
  final String displayName;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedDay = 0;
  static const lessons = [
    [('09:00', 'Database', '302'), ('13:00', 'Software Engineering', '405')],
    [('10:00', 'Математик', '301')],
    [('09:00', 'OOP', '402')],
    [('11:00', 'Web Programming', '403')],
    [('13:00', 'Software Engineering', '405')],
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(26, 18, 26, 36),
    children: [
      Text(
        'Сайн байна уу, ${widget.displayName} 👋',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 58),
      const SectionTitle('Шинэ зарлал'),
      const SizedBox(height: 14),
      Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF253858)
            : AppColors.paleBlue,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('📢 Шалгалтын хуваарь'),
              content: const Text(
                'Намрын улирлын шалгалтын хуваарь шинэчлэгдлээ.\n\n'
                'Дэлгэрэнгүй хуваарийг сургалтын албаны 201 тоотоос авна уу.\n\nСургалтын алба • Өнөөдөр',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Хаах'),
                ),
              ],
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📢 Шалгалтын хуваарь шинэчлэгдлээ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue,
                  ),
                ),
                SizedBox(height: 13),
                Text(
                  'Сургалтын алба',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
                SizedBox(height: 10),
                Text(
                  'Өнөөдөр',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 28),
      SectionTitle(
        selectedDay == 0
            ? 'Өнөөдрийн хичээл'
            : '${['Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан'][selectedDay]} гарагийн хичээл',
      ),
      const SizedBox(height: 16),
      for (final lesson in lessons[selectedDay]) ...[
        SurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 66,
                child: Text(
                  lesson.$1,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.$2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${lesson.$3} тоот',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      const SectionTitle('7 хоногийн хуваарь'),
      const SizedBox(height: 18),
      SurfaceCard(
        padding: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            5,
            (index) => Expanded(
              child: Column(
                children: [
                  Text(
                    ['Д', 'М', 'Л', 'П', 'Б'][index],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    label:
                        '${['Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан'][index]} гараг',
                    selected: selectedDay == index,
                    child: SizedBox(
                      width: 42,
                      height: 44,
                      child: TextButton(
                        onPressed: () => setState(() => selectedDay = index),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF253858)
                              : AppColors.paleBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          foregroundColor: AppColors.blue,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    ['Database', '', 'OOP', 'Web', 'SE'][index],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
