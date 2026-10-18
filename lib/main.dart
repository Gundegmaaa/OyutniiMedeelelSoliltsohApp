import 'package:flutter/material.dart';

import 'models/learning.dart';
import 'screens/community_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learning_screen.dart';
import 'theme.dart';

void main() => runApp(const StudentHubApp());

class StudentHubApp extends StatefulWidget {
  const StudentHubApp({super.key});
  @override
  State<StudentHubApp> createState() => _StudentHubAppState();
}

class _StudentHubAppState extends State<StudentHubApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'МТС • Оюутны мэдээллийн систем',
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: StudentHub(
      dark: dark,
      toggleTheme: () => setState(() => dark = !dark),
    ),
  );
}

class StudentHub extends StatefulWidget {
  const StudentHub({super.key, required this.dark, required this.toggleTheme});
  final bool dark;
  final VoidCallback toggleTheme;
  @override
  State<StudentHub> createState() => _StudentHubState();
}

class _StudentHubState extends State<StudentHub> {
  int tab = 0;
  final communityKey = GlobalKey<CommunityScreenState>();
  final progress = LearningProgress();

  void showProfile() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.paleBlue,
            child: Icon(Icons.person_outline, color: AppColors.blue, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Гүндэгмаа',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Мандах Их Сургууль\nМэдээлэл, технологийн сургууль\nSoftware Engineering • 2-р курс',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.7, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Text(
            '${progress.xp} XP • Байр #${progress.rank}',
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Туршилтын профайл',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 76,
      titleSpacing: 26,
      title: Row(
        children: [
          Text(
            'МТС',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: widget.dark ? Colors.white : AppColors.navy,
            ),
          ),
          Expanded(
            child: Text(
              ['', 'Community', 'Сургалт'][tab],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: widget.dark ? 'Гэгээтэй горим' : 'Харанхуй горим',
          onPressed: widget.toggleTheme,
          icon: const Icon(
            Icons.brightness_6_outlined,
            color: AppColors.muted,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: IndexedStack(
          index: tab,
          children: [
            const HomeScreen(),
            CommunityScreen(key: communityKey),
            LearningScreen(
              progress: progress,
              onProgress: () => setState(() {}),
            ),
          ],
        ),
      ),
    ),
    floatingActionButton: tab == 1
        ? FloatingActionButton(
            tooltip: 'Нийтлэл нэмэх',
            onPressed: () => communityKey.currentState?.createPost(),
            child: const Icon(Icons.add, size: 30),
          )
        : null,
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Row(
                children: List.generate(4, (index) {
                  final active = tab == index;
                  final color = active ? AppColors.blue : AppColors.muted;
                  return Expanded(
                    child: Semantics(
                      selected: active,
                      button: true,
                      child: InkWell(
                        onTap: () {
                          if (index == 3) {
                            showProfile();
                          } else {
                            setState(() => tab = index);
                          }
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              [
                                Icons.home_outlined,
                                Icons.forum_outlined,
                                Icons.auto_awesome,
                                Icons.account_circle_outlined,
                              ][index],
                              size: 23,
                              color: color,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              [
                                'Нүүр',
                                'Community',
                                'Сургалт',
                                'Профайл',
                              ][index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
