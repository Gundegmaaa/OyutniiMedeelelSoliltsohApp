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
  final bool dark;
  final VoidCallback toggleTheme;
  final AuthUser user;
  final Future<void> Function() onLogout;
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
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.paleBlue,
              child: Icon(
                Icons.person_outline,
                color: AppColors.blue,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.user.displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.user.email,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.7, color: AppColors.muted),
            ),
            if (widget.user.studentCode != null) ...[
              const SizedBox(height: 12),
              Text('Оюутны код: ${widget.user.studentCode}'),
            ],
            if (widget.user.course != null)
              Text('${widget.user.course}-р курс'),
            Text(switch (widget.user.role) {
              'teacher' => 'Багш',
              'admin' => 'Админ',
              _ => 'Оюутан',
            }, style: const TextStyle(color: AppColors.blue)),
            const SizedBox(height: 24),
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
