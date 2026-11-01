import 'package:flutter/material.dart';

import 'auth/auth_api.dart';
import 'auth/auth_user.dart';
import 'models/learning.dart';
import 'screens/auth_screen.dart';
import 'screens/community_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learning_screen.dart';
import 'theme.dart';

void main() => runApp(const StudentHubApp());

class StudentHubApp extends StatefulWidget {
  const StudentHubApp({super.key, this.authApi});
  final AuthApi? authApi;
  @override
  State<StudentHubApp> createState() => _StudentHubAppState();
}

class _StudentHubAppState extends State<StudentHubApp> {
  bool dark = false;
  late final AuthApi _api;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  AuthUser? _user;
  bool _restoringSession = true;
  bool _loggingOut = false;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _api = widget.authApi ?? AuthApi();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _restoringSession = true;
      _sessionError = null;
    });
    try {
      final user = await _api.currentUser();
      if (mounted) setState(() => _user = user);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _sessionError = error.message);
    } finally {
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await _api.logout();
      if (mounted) setState(() => _user = null);
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        setState(() => _user = null);
      } else {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  void dispose() {
    if (widget.authApi == null) _api.close();
    super.dispose();
  }

  Widget _home() {
    if (_restoringSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_sessionError != null) {
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'Холболтыг шалгана уу',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(_sessionError!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _restoreSession,
                    child: const Text('Дахин оролдох'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _sessionError = null),
                    child: const Text('Нэвтрэх хуудас руу'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final user = _user;
    if (user == null) {
      return AuthScreen(
        api: _api,
        dark: dark,
        toggleTheme: () => setState(() => dark = !dark),
        onAuthenticated: (user) => setState(() => _user = user),
      );
    }
    return Stack(
      children: [
        StudentHub(
          key: ValueKey(user.id),
          user: user,
          onLogout: _logout,
          dark: dark,
          toggleTheme: () => setState(() => dark = !dark),
        ),
        if (_loggingOut)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: _messengerKey,
    title: 'МТС • Оюутны мэдээллийн систем',
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: _home(),
  );
}

class StudentHub extends StatefulWidget {
  const StudentHub({
    super.key,
    required this.dark,
    required this.toggleTheme,
    required this.user,
    required this.onLogout,
  });
  final AuthUser user;
  final Future<void> Function() onLogout;
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
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  widget.user.displayName,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  widget.user.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (widget.user.studentCode != null)
            Text('Оюутны код: ${widget.user.studentCode}'),
          if (widget.user.course != null) Text('${widget.user.course}-р курс'),
          Text(switch (widget.user.role) {
            'teacher' => 'Багш',
            'admin' => 'Админ',
            _ => 'Оюутан',
          }, style: const TextStyle(color: AppColors.blue)),
          const SizedBox(height: 22),
          const Text(
            'Мандах Их Сургууль',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Мэдээлэл, технологийн сургууль',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.orange),
                      Text(
                        '${progress.xp} XP',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Цуглуулсан оноо',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.orange,
                      ),
                      Text(
                        '#${progress.rank}',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Таны байр',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Туршилтын профайл',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('profile_logout'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Системээс гарах'),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 80,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: .22),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'МТС',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: widget.dark ? Colors.white : AppColors.navy,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'STUDENT SPACE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: widget.dark ? 'Гэгээтэй горим' : 'Харанхуй горим',
          onPressed: widget.toggleTheme,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          icon: Icon(
            widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: AppColors.muted,
            size: 21,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Миний профайл',
          onPressed: showProfile,
          style: IconButton.styleFrom(
            backgroundColor: widget.dark
                ? const Color(0xFF44305D)
                : const Color(0xFFE8DAFF),
          ),
          icon: Icon(
            Icons.person_rounded,
            color: widget.dark ? const Color(0xFFD2B8FF) : AppColors.purple,
            size: 23,
          ),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.dark
              ? const [Color(0xFF20152F), Color(0xFF171020)]
              : const [Color(0xFFF0E9FF), AppColors.background],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: IndexedStack(
            index: tab,
            children: [
              HomeScreen(
                displayName: widget.user.firstName.isEmpty
                    ? widget.user.displayName
                    : widget.user.firstName,
              ),
              CommunityScreen(key: communityKey),
              LearningScreen(
                progress: progress,
                onProgress: () => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: tab == 1
        ? FloatingActionButton(
            tooltip: 'Нийтлэл нэмэх',
            onPressed: () => communityKey.currentState?.createPost(),
            child: const Icon(Icons.add_photo_alternate_outlined, size: 28),
          )
        : null,
    bottomNavigationBar: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(
                  alpha: widget.dark ? .05 : .08,
                ),
                blurRadius: 28,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: List.generate(4, (index) {
              final active = tab == index;
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (index == 3) {
                        showProfile();
                      } else {
                        setState(() => tab = index);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: active ? AppColors.heroGradient : null,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              [
                                Icons.home_rounded,
                                Icons.forum_rounded,
                                Icons.auto_awesome_rounded,
                                Icons.person_outline_rounded,
                              ][index],
                              size: 22,
                              color: active ? Colors.white : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            ['Нүүр', 'Community', 'Сургалт', 'Профайл'][index],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: active
                                  ? Theme.of(context).colorScheme.primary
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
}
