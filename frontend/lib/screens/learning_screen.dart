import 'package:flutter/material.dart';

import '../models/learning.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({
    super.key,
    required this.progress,
    required this.onProgress,
  });
  final LearningProgress progress;
  final VoidCallback onProgress;

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

const _levelNames = ['Хялбар', 'Дунд', 'Хүнд'];
const _programNames = ['Software Engineering', 'Information System'];

/// Per-program accent so switching programs visibly re-themes the screen.
class _ProgramStyle {
  const _ProgramStyle({
    required this.accent,
    required this.accentOnDark,
    required this.heroColors,
    required this.heroStops,
    required this.heroLabel,
    required this.heroSubtitle,
    required this.chipFill,
    required this.trophyShadow,
    required this.cardLight,
    required this.cardDark,
    required this.tintLight,
    required this.tintDark,
    required this.resultColors,
  });

  /// Solid accent; white text on it meets WCAG AA.
  final Color accent;

  /// Lighter accent for text and icons on dark surfaces.
  final Color accentOnDark;
  final List<Color> heroColors;
  final List<double> heroStops;
  final Color heroLabel;
  final Color heroSubtitle;
  final Color chipFill;
  final Color trophyShadow;
  final List<Color> cardLight;
  final List<Color> cardDark;
  final Color tintLight;
  final Color tintDark;
  final List<Color> resultColors;

  Color foreground(bool dark) => dark ? accentOnDark : accent;
  Color tint(bool dark) => dark ? tintDark : tintLight;

  static const software = _ProgramStyle(
    accent: AppColors.purple,
    accentOnDark: AppColors.lavender,
    heroColors: [Color(0xFF6B30DC), Color(0xFF985BF1), Color(0xFFB393F8)],
    heroStops: [0, .5, 1],
    heroLabel: Color(0xFFEDE0FF),
    heroSubtitle: Color(0xFFE9DFFF),
    chipFill: Color(0x26FFFFFF),
    trophyShadow: Color(0xFF6D33BB),
    cardLight: [Color(0xFFE8DAFF), Color(0xFFF6F0FF)],
    cardDark: [Color(0xFF3D295D), Color(0xFF292039)],
    tintLight: Color(0xFFF2EAFF),
    tintDark: Color(0xFF332748),
    resultColors: [Color(0xFF8145E8), Color(0xFFBDA0F8)],
  );

  // The teal stays dark across the text area (white on #0F7E86 is 4.8:1)
  // and only lightens toward the bottom-right corner behind the white button.
  static const information = _ProgramStyle(
    accent: Color(0xFF0F7E86),
    accentOnDark: Color(0xFF7FD6CC),
    heroColors: [
      Color(0xFF0B6A72),
      Color(0xFF0F7E86),
      Color(0xFF2FA7A0),
      Color(0xFF8FD8CF),
    ],
    heroStops: [0, .5, .82, 1],
    heroLabel: Color(0xFFD9F5F1),
    heroSubtitle: Color(0xFFE3F7F4),
    chipFill: Color(0x2E003A40),
    trophyShadow: Color(0xFF09555B),
    cardLight: [Color(0xFFD3F1EE), Color(0xFFEEFAF8)],
    cardDark: [Color(0xFF1C4A4F), Color(0xFF1E2C34)],
    tintLight: Color(0xFFE2F5F3),
    tintDark: Color(0xFF1F3A3F),
    resultColors: [Color(0xFF0F7E86), Color(0xFF5CC2B8)],
  );

  static _ProgramStyle of(int program) => program == 0 ? software : information;
}

class _LearningScreenState extends State<LearningScreen> {
  int program = 0;

  _ProgramStyle get style => _ProgramStyle.of(program);

  Future<void> startQuiz() async {
    final points = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _QuizDialog(
        questions: program == 0 ? softwareQuiz : informationQuiz,
        style: style,
      ),
    );
    if (points == null || !mounted) return;
    final earned = widget.progress.award('quiz-$program', points);
    widget.onProgress();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          earned > 0
              ? 'Баяр хүргэе! +$earned XP'
              : 'Энэ quiz-ийн XP-г өмнө нь авсан байна.',
        ),
      ),
    );
  }

  Future<void> startProblem(int difficulty) async {
    final problem = (program == 0
        ? softwareProblems
        : informationProblems)[difficulty];
    final solved = await showDialog<bool>(
      context: context,
      // Only "Гарах" closes the dialog, so a stray tap cannot lose the work.
      barrierDismissible: false,
      builder: (context) => _ProblemDialog(
        problem: problem,
        level: _levelNames[difficulty],
        style: style,
      ),
    );
    if (solved != true || !mounted) return;
    final earned = widget.progress.award(
      'problem-$program-$difficulty',
      problem.xp,
    );
    widget.onProgress();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          earned > 0
              ? 'Бодлого зөв бодлоо! +$earned XP'
              : 'Энэ бодлогын XP-г өмнө нь авсан байна.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final subjects = program == 0
        ? ['OOP', 'Database', 'Web']
        : ['Системийн шинжилгээ', 'Database', 'Мэдээллийн систем'];
    final problems = program == 0 ? softwareProblems : informationProblems;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Суралцах',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Бага багаар, өдөр бүр ахицтай.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF392B27) : const Color(0xFFFFEBD9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFFF58A35),
                    size: 19,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${widget.progress.xp} XP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: dark ? AppColors.orange : const Color(0xFFBD5B17),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ProgramTabs(
          selected: program,
          onSelected: (value) => setState(() => program = value),
        ),
        const SizedBox(height: 18),
        _QuizHero(
          key: const ValueKey('quiz-hero'),
          program: program,
          style: style,
          subjects: subjects,
          completed: widget.progress.completed.contains('quiz-$program'),
          onStart: startQuiz,
        ),
        const SizedBox(height: 23),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Бодлогоо сонгоорой',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '3 түвшин',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            3,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 9),
                child: _DifficultyCard(
                  level: index,
                  xp: problems[index].xp,
                  completed: widget.progress.completed.contains(
                    'problem-$program-$index',
                  ),
                  onStart: () => startProblem(index),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 23),
        _Leaderboard(progress: widget.progress),
      ],
    );
  }
}

/// Local stand-in for [SegmentTabs] so the selected tab can take the
/// program accent (SegmentTabs is shared and always purple).
class _ProgramTabs extends StatelessWidget {
  const _ProgramTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      _programNames.length,
      (index) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            right: index == _programNames.length - 1 ? 0 : 6,
          ),
          child: Semantics(
            selected: selected == index,
            child: FilledButton(
              onPressed: () => onSelected(index),
              style: FilledButton.styleFrom(
                backgroundColor: selected == index
                    ? _ProgramStyle.of(index).accent
                    : Theme.of(context).colorScheme.surface,
                foregroundColor: selected == index
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
                animationDuration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 17,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              child: Text(_programNames[index], textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ),
  );
}

class _QuizHero extends StatelessWidget {
  const _QuizHero({
    super.key,
    required this.program,
    required this.style,
    required this.subjects,
    required this.completed,
    required this.onStart,
  });
  final int program;
  final _ProgramStyle style;
  final List<String> subjects;
  final bool completed;
  final VoidCallback onStart;

  static const _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _duration,
    curve: Curves.easeOut,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: style.heroColors,
        stops: style.heroStops,
      ),
      borderRadius: BorderRadius.circular(27),
      boxShadow: [
        BoxShadow(
          color: style.accent.withValues(alpha: .19),
          blurRadius: 23,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: Stack(
      children: [
        const Positioned(
          top: -55,
          right: -55,
          child: _DecorCircle(size: 210, alpha: .08),
        ),
        const Positioned(
          bottom: -83,
          left: -37,
          child: _DecorCircle(size: 160, alpha: .07),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFFFDB8F),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ӨДРИЙН QUIZ',
                                style: TextStyle(
                                  color: style.heroLabel,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Мэдлэгээ\nтоглоом болго!',
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.16,
                            letterSpacing: -.8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          completed
                              ? 'Дууссан. Дахин давтаж болно!'
                              : '3 асуулт · 60 хүртэл XP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: style.heroSubtitle,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _TrophyArt(size: 101, shadow: style.trophyShadow),
                ],
              ),
              const SizedBox(height: 15),
              // Fixed-height single-line row: the IS subjects are longer, and
              // a wrapping row would make the hero jump when switching.
              SizedBox(
                height: 26,
                child: AnimatedSwitcher(
                  duration: _duration,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: ListView.separated(
                    key: ValueKey('subjects-$program'),
                    scrollDirection: Axis.horizontal,
                    itemCount: subjects.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) => Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        color: style.chipFill,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .24),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subjects[index],
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TweenAnimationBuilder<Color?>(
                  duration: _duration,
                  tween: ColorTween(end: style.accent),
                  builder: (context, accent, _) => FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded, size: 21),
                    label: const Text('ЭХЛҮҮЛЭХ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.white.withValues(alpha: alpha),
        width: 25,
      ),
    ),
  );
}

class _TrophyArt extends StatelessWidget {
  const _TrophyArt({this.size = 120, this.shadow = const Color(0xFF6D33BB)});
  final double size;
  final Color shadow;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 1.12,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * .87,
          height: size * .87,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: .24),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        Transform.rotate(
          angle: -.15,
          child: Icon(
            Icons.emoji_events_rounded,
            size: size * .92,
            color: const Color(0xFFFFD46A),
            shadows: [
              Shadow(color: shadow, offset: const Offset(3, 8), blurRadius: 1),
              const Shadow(color: Color(0xFFEF982C), offset: Offset(1, 3)),
            ],
          ),
        ),
        Positioned(
          top: size * .03,
          right: size * .02,
          child: Icon(
            Icons.auto_awesome,
            color: const Color(0xFFFFE7B0),
            size: size * .21,
          ),
        ),
        Positioned(
          bottom: size * .03,
          left: 0,
          child: Icon(
            Icons.star_rounded,
            color: const Color(0xFFFFC1E5),
            size: size * .19,
          ),
        ),
      ],
    ),
  );
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.level,
    required this.xp,
    required this.completed,
    required this.onStart,
  });
  final int level;
  final int xp;
  final bool completed;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = [
      const Color(0xFF23856B),
      AppColors.purple,
      const Color(0xFFB83D78),
    ][level];
    final background = [
      const Color(0xFFE0F7EE),
      const Color(0xFFEEE5FF),
      const Color(0xFFFCE3EF),
    ][level];
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 14, 9, 10),
      decoration: BoxDecoration(
        color: dark
            ? Color.alphaBlend(
                color.withValues(alpha: .2),
                const Color(0xFF211B32),
              )
            : background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: dark ? .28 : .09)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: dark
                  ? color.withValues(alpha: .18)
                  : Colors.white.withValues(alpha: .8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              completed
                  ? Icons.check_rounded
                  : [
                      Icons.eco_rounded,
                      Icons.bolt_rounded,
                      Icons.local_fire_department_rounded,
                    ][level],
              color: dark
                  ? [AppColors.mint, AppColors.lavender, AppColors.pink][level]
                  : color,
              size: 27,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ['Хялбар', 'Дунд', 'Хүнд'][level],
            style: TextStyle(
              color: dark ? Colors.white : color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            completed ? 'Авсан ✓' : '+$xp XP',
            style: TextStyle(
              color: dark ? Colors.white70 : color.withValues(alpha: .75),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: dark ? color.withValues(alpha: .4) : color,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 35),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              child: const Text('Эхлэх'),
            ),
          ),
        ],
      ),
    );
  }
}

const _podiumColors = {
  1: Color(0xFFFFD782),
  2: Color(0xFFD8CCFF),
  3: Color(0xFFF6BEDD),
};
const _podiumHeights = {1: 70.0, 2: 47.0, 3: 33.0};

void _showActivities(
  BuildContext context, {
  required String name,
  required String subtitle,
  required String initial,
  required Color color,
  required int xp,
  required Iterable<String> completed,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ActivitySheet(
      name: name,
      subtitle: subtitle,
      initial: initial,
      color: color,
      xp: xp,
      completed: completed.toSet(),
    ),
  );
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.progress});
  final LearningProgress progress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final byRank = {for (final student in demoLeaders) student.rank: student};
    Widget podium(int rank) {
      final student = byRank[rank]!;
      final color = _podiumColors[rank]!;
      return _PodiumStudent(
        key: ValueKey('leader-$rank'),
        rank: rank,
        name: student.name,
        initial: student.name.characters.first,
        xp: student.xp,
        color: color,
        height: _podiumHeights[rank]!,
        onTap: () => _showActivities(
          context,
          name: student.name,
          subtitle: '#$rank байр',
          initial: student.name.characters.first,
          color: color,
          xp: student.xp,
          completed: student.completed,
        ),
      );
    }

    final meColor = dark ? const Color(0xFF34234F) : const Color(0xFFF2EAFF);
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFE8A32A),
                size: 23,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Манлайлагчид',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF392C54)
                      : const Color(0xFFF0E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'TOP 3',
                  style: TextStyle(
                    color: dark ? AppColors.lavender : AppColors.purple,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: podium(2)),
              const SizedBox(width: 7),
              Expanded(child: podium(1)),
              const SizedBox(width: 7),
              Expanded(child: podium(3)),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_rounded, size: 14, color: AppColors.muted),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Нэр дээр дарж бодсон бодлогуудыг харна уу.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: meColor,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('leader-me'),
              onTap: () => _showActivities(
                context,
                name: 'Таны ахиц',
                subtitle: 'Таны байр: #${progress.rank}',
                initial: 'Та',
                color: dark ? AppColors.lavender : const Color(0xFFD8CCFF),
                xp: progress.xp,
                completed: progress.completed,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 21,
                      color: dark ? AppColors.lavender : AppColors.purple,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Таны байр: #${progress.rank}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${progress.xp} XP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: dark ? AppColors.lavender : AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumStudent extends StatelessWidget {
  const _PodiumStudent({
    super.key,
    required this.rank,
    required this.name,
    required this.initial,
    required this.xp,
    required this.color,
    required this.height,
    required this.onTap,
  });
  final int rank;
  final String name;
  final String initial;
  final int xp;
  final Color color;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Semantics(
        button: true,
        label: '$name, $xp XP. Бодсон бодлогуудыг харах',
        excludeSemantics: true,
        child: Column(
          children: [
            if (rank == 1) ...[
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFE5A21D),
                size: 22,
              ),
              const SizedBox(height: 2),
            ],
            CircleAvatar(
              radius: rank == 1 ? 24 : 21,
              backgroundColor: color,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$xp XP',
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
            const SizedBox(height: 9),
            Container(
              height: height,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: .25)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: .65),
                  fontSize: rank == 1 ? 25 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Bottom sheet listing which quiz and problems a person has completed,
/// grouped per program.
class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet({
    required this.name,
    required this.subtitle,
    required this.initial,
    required this.color,
    required this.xp,
    required this.completed,
  });
  final String name;
  final String subtitle;
  final String initial;
  final Color color;
  final int xp;
  final Set<String> completed;

  static List<String> _activityIds(int program) => [
    'quiz-$program',
    for (var level = 0; level < 3; level++) 'problem-$program-$level',
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final total = _programNames.length * 4;
    final done = [
      for (var program = 0; program < _programNames.length; program++)
        ..._activityIds(program),
    ].where(completed.contains).length;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subtitle · $done / $total дууссан',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF392B27)
                      : const Color(0xFFFFEBD9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  '$xp XP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: dark ? AppColors.orange : const Color(0xFFBD5B17),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (done == 0)
            Container(
              key: const ValueKey('activities-empty'),
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 30, color: AppColors.muted),
                  SizedBox(height: 8),
                  Text(
                    'Одоогоор бодсон бодлого алга.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          else
            for (var program = 0; program < _programNames.length; program++)
              _ProgramActivities(program: program, completed: completed),
        ],
      ),
    );
  }
}

class _ProgramActivities extends StatelessWidget {
  const _ProgramActivities({required this.program, required this.completed});
  final int program;
  final Set<String> completed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = _ProgramStyle.of(program);
    final problems = program == 0 ? softwareProblems : informationProblems;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: style.foreground(dark),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _programNames[program],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: style.foreground(dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ActivityRow(
            key: ValueKey('activity-quiz-$program'),
            style: style,
            done: completed.contains('quiz-$program'),
            title: 'Өдрийн quiz',
            detail: '3 асуулт',
            xp: '60 хүртэл XP',
          ),
          for (var level = 0; level < problems.length; level++)
            _ActivityRow(
              key: ValueKey('activity-problem-$program-$level'),
              style: style,
              done: completed.contains('problem-$program-$level'),
              title: '${_levelNames[level]} бодлого',
              detail: problems[level].prompt,
              xp: '+${problems[level].xp} XP',
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    super.key,
    required this.style,
    required this.done,
    required this.title,
    required this.detail,
    required this.xp,
  });
  final _ProgramStyle style;
  final bool done;
  final String title;
  final String detail;
  final String xp;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = style.foreground(dark);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: done ? style.tint(dark) : Colors.transparent,
        border: Border.all(
          color: done
              ? accent.withValues(alpha: .3)
              : Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: done ? accent : AppColors.muted,
            semanticLabel: done ? 'Хийсэн' : 'Хийгээгүй',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            xp,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: done ? accent : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizDialog extends StatefulWidget {
  const _QuizDialog({required this.questions, required this.style});
  final List<QuizQuestion> questions;
  final _ProgramStyle style;

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  int index = 0;
  int? selected;
  int correct = 0;
  bool checked = false;
  bool finished = false;

  void advance() {
    if (finished) {
      Navigator.pop(context, correct > 0 ? correct * 20 : null);
      return;
    }
    setState(() {
      if (!checked) {
        checked = true;
        if (selected == widget.questions[index].answer) correct++;
      } else if (index == widget.questions.length - 1) {
        finished = true;
      } else {
        index++;
        selected = null;
        checked = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[index];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _LearningDialogFrame(
      actions: [
        if (!finished)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Гарах'),
          ),
        Expanded(
          child: FilledButton.icon(
            onPressed: !finished && selected == null ? null : advance,
            icon: Icon(
              finished
                  ? Icons.check_rounded
                  : checked
                  ? Icons.arrow_forward_rounded
                  : Icons.check_circle_outline_rounded,
              size: 19,
            ),
            label: Text(
              finished
                  ? 'Дуусгах'
                  : checked
                  ? 'Дараах'
                  : 'Шалгах',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: widget.style.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
      child: finished
          ? _QuizResult(
              correct: correct,
              total: widget.questions.length,
              style: widget.style,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: widget.style.accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: widget.style.foreground(dark),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'QUIZ TIME',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      '${index + 1} / ${widget.questions.length}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (index + 1) / widget.questions.length,
                    minHeight: 7,
                    color: widget.style.accent,
                    backgroundColor: widget.style.accent.withValues(alpha: .12),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? widget.style.cardDark
                          : widget.style.cardLight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'АСУУЛТ ${index + 1}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: widget.style.foreground(dark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        question.prompt,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Зөв хариултыг сонгоорой',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                for (var option = 0; option < question.options.length; option++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _QuizOption(
                      style: widget.style,
                      number: option,
                      text: question.options[option],
                      selected: selected == option,
                      checked: checked,
                      correct: option == question.answer,
                      onSelect: () => setState(() => selected = option),
                    ),
                  ),
                if (checked) ...[
                  const SizedBox(height: 7),
                  _AnswerFeedback(
                    correct: selected == question.answer,
                    heading: selected == question.answer
                        ? 'Зөв хариуллаа! +20 XP'
                        : 'Дахин давтаарай.',
                    explanation: question.explanation,
                  ),
                ],
              ],
            ),
    );
  }
}

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.style,
    required this.number,
    required this.text,
    required this.selected,
    required this.checked,
    required this.correct,
    required this.onSelect,
  });
  final _ProgramStyle style;
  final int number;
  final String text;
  final bool selected;
  final bool checked;
  final bool correct;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final revealed = checked && (correct || selected);
    final active = selected || revealed;
    final color = checked && correct
        ? const Color(0xFF268E73)
        : checked && selected
        ? const Color(0xFFC54C72)
        : style.accent;
    final foreground = Theme.of(context).textTheme.bodyLarge?.color;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: checked ? null : onSelect,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          disabledForegroundColor: foreground,
          backgroundColor: active
              ? color.withValues(alpha: dark ? .2 : .09)
              : Colors.transparent,
          side: BorderSide(
            color: active
                ? color.withValues(alpha: .75)
                : Theme.of(context).dividerColor,
            width: active ? 1.5 : 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? color
                    : Theme.of(context).dividerColor.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                String.fromCharCode(65 + number),
                style: TextStyle(
                  color: active ? Colors.white : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Icon(
                revealed
                    ? correct
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded
                    : Icons.radio_button_checked_rounded,
                size: 18,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({
    required this.correct,
    required this.total,
    required this.style,
  });
  final int correct;
  final int total;
  final _ProgramStyle style;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: style.resultColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(23),
        ),
        child: const Column(
          children: [
            _TrophyArt(size: 125),
            SizedBox(height: 8),
            Text(
              'Quiz дууслаа 🎉',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 25),
      Text(
        correct == total ? 'Гайхалтай байлаа!' : 'Нэг алхам урагшиллаа!',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        'Та $total асуултаас $correct зөв хариуллаа.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 13),
        decoration: BoxDecoration(
          color: style.accent.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFFF1A02D), size: 25),
            const SizedBox(width: 5),
            Text(
              '+${correct * 20} XP',
              style: TextStyle(
                color: style.foreground(
                  Theme.of(context).brightness == Brightness.dark,
                ),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
    ],
  );
}

class _ProblemDialog extends StatefulWidget {
  const _ProblemDialog({
    required this.problem,
    required this.level,
    required this.style,
  });
  final PracticeProblem problem;
  final String level;
  final _ProgramStyle style;

  @override
  State<_ProblemDialog> createState() => _ProblemDialogState();
}

class _ProblemDialogState extends State<_ProblemDialog> {
  final answer = TextEditingController();
  bool? correct;
  bool showGuide = true;

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  void checkAnswer() {
    if (correct == true) {
      Navigator.pop(context, true);
    } else {
      FocusScope.of(context).unfocus();
      setState(() => correct = answer.text.trim() == widget.problem.answer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _LearningDialogFrame(
      actions: [
        if (correct != true)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Гарах'),
          ),
        Expanded(
          child: FilledButton.icon(
            onPressed: checkAnswer,
            icon: Icon(
              correct == true ? Icons.check_circle_rounded : Icons.bolt_rounded,
              size: 20,
            ),
            label: Text(correct == true ? 'Дуусгах' : 'Шалгах'),
            style: FilledButton.styleFrom(
              backgroundColor: widget.style.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: widget.style.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.terminal_rounded,
                  color: widget.style.foreground(dark),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.level} бодлого',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${widget.problem.xp} XP цуглуулаарай',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ProblemGuide(
            style: widget.style,
            expanded: showGuide,
            onToggle: () => setState(() => showGuide = !showGuide),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: widget.style.tint(dark),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'БОДООД ҮЗЬЕ',
                  style: TextStyle(
                    color: widget.style.foreground(dark),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  widget.problem.prompt,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: answer,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => checkAnswer(),
            enabled: correct != true,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Хариу',
              hintText: 'Хариугаа оруулаарай',
              hintStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                color: widget.style.foreground(dark),
              ),
              floatingLabelStyle: TextStyle(
                color: widget.style.foreground(dark),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: widget.style.foreground(dark),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: dark
                  ? const Color(0xFF241E31)
                  : const Color(0xFFFCFAFF),
              errorMaxLines: 3,
              errorText: correct == false
                  ? 'Хариу буруу байна. Дахин оролдоорой.'
                  : null,
            ),
          ),
          if (correct == true) ...[
            const SizedBox(height: 18),
            _AnswerFeedback(
              correct: true,
              heading: 'Зөв бодлоо! Сайн байна!',
              explanation: widget.problem.explanation,
            ),
          ] else ...[
            const SizedBox(height: 13),
            const Text(
              'Яаралгүй бодоод, өөрийгөө сориорой.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Short, collapsible "how it works" block at the top of a problem.
class _ProblemGuide extends StatelessWidget {
  const _ProblemGuide({
    required this.style,
    required this.expanded,
    required this.onToggle,
  });
  final _ProgramStyle style;
  final bool expanded;
  final VoidCallback onToggle;

  static const _steps = [
    'Хариуг тоогоор «Хариу» талбарт бичнэ.',
    '«Шалгах» дарж шалгана.',
    'Буруу бол торгуульгүй дахин оролдоно.',
    'XP нэг бодлогод зөвхөн нэг удаа олгоно.',
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = style.foreground(dark);
    return Container(
      key: const ValueKey('problem-guide'),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 17, color: accent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Заавар',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: accent,
                      semanticLabel: expanded ? 'Заавар нуух' : 'Заавар харах',
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    child: Text(
                                      '${i + 1}.',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _steps[i],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  const _AnswerFeedback({
    required this.correct,
    required this.heading,
    required this.explanation,
  });
  final bool correct;
  final String heading;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = correct ? const Color(0xFF268E73) : const Color(0xFFC16C26);
    final accent = dark
        ? correct
              ? AppColors.mint
              : AppColors.orange
        : color;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .2 : .09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  heading,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(explanation, style: const TextStyle(fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}

class _LearningDialogFrame extends StatelessWidget {
  const _LearningDialogFrame({required this.child, required this.actions});
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 460,
        maxHeight:
            MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom -
            60,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
              child: child,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Row(children: actions),
          ),
        ],
      ),
    ),
  );
}
