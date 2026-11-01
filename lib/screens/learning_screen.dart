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

class _LearningScreenState extends State<LearningScreen> {
  int program = 0;

  Future<void> startQuiz() async {
    final points = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _QuizDialog(questions: program == 0 ? softwareQuiz : informationQuiz),
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
      builder: (context) => _ProblemDialog(
        problem: problem,
        level: ['Хялбар', 'Дунд', 'Хүнд'][difficulty],
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
        SegmentTabs(
          labels: const ['Software Engineering', 'Information System'],
          selected: program,
          onSelected: (value) => setState(() => program = value),
        ),
        const SizedBox(height: 18),
        _QuizHero(
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

class _QuizHero extends StatelessWidget {
  const _QuizHero({
    required this.subjects,
    required this.completed,
    required this.onStart,
  });
  final List<String> subjects;
  final bool completed;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B30DC), Color(0xFF985BF1), Color(0xFFB393F8)],
      ),
      borderRadius: BorderRadius.circular(27),
      boxShadow: [
        BoxShadow(
          color: AppColors.purple.withValues(alpha: .19),
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
                        const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFFFDB8F),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'ӨДРИЙН QUIZ',
                                style: TextStyle(
                                  color: Color(0xFFEDE0FF),
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
                          style: const TextStyle(
                            color: Color(0xFFE9DFFF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _TrophyArt(size: 101),
                ],
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: subjects
                    .map(
                      (subject) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .2),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          subject,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 21),
                  label: const Text('ЭХЛҮҮЛЭХ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.purple,
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
  const _TrophyArt({this.size = 120});
  final double size;

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
            shadows: const [
              Shadow(
                color: Color(0xFF6D33BB),
                offset: Offset(3, 8),
                blurRadius: 1,
              ),
              Shadow(color: Color(0xFFEF982C), offset: Offset(1, 3)),
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

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.progress});
  final LearningProgress progress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _PodiumStudent(
                  rank: 2,
                  name: 'Анужин',
                  initial: 'А',
                  xp: 1190,
                  color: Color(0xFFD8CCFF),
                  height: 47,
                ),
              ),
              SizedBox(width: 7),
              Expanded(
                child: _PodiumStudent(
                  rank: 1,
                  name: 'Бат-Эрдэнэ',
                  initial: 'Б',
                  xp: 1250,
                  color: Color(0xFFFFD782),
                  height: 70,
                ),
              ),
              SizedBox(width: 7),
              Expanded(
                child: _PodiumStudent(
                  rank: 3,
                  name: 'Тэмүүлэн',
                  initial: 'Т',
                  xp: 1110,
                  color: Color(0xFFF6BEDD),
                  height: 33,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF34234F) : const Color(0xFFF2EAFF),
              borderRadius: BorderRadius.circular(16),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumStudent extends StatelessWidget {
  const _PodiumStudent({
    required this.rank,
    required this.name,
    required this.initial,
    required this.xp,
    required this.color,
    required this.height,
  });
  final int rank;
  final String name;
  final String initial;
  final int xp;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
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
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
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
  );
}

class _QuizDialog extends StatefulWidget {
  const _QuizDialog({required this.questions});
  final List<QuizQuestion> questions;

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
              backgroundColor: AppColors.purple,
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
          ? _QuizResult(correct: correct, total: widget.questions.length)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.psychology_rounded,
                        color: dark ? AppColors.lavender : AppColors.purple,
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
                    color: AppColors.purple,
                    backgroundColor: AppColors.purple.withValues(alpha: .12),
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
                          ? [const Color(0xFF3D295D), const Color(0xFF292039)]
                          : [const Color(0xFFE8DAFF), const Color(0xFFF6F0FF)],
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
                          color: dark ? AppColors.lavender : AppColors.purple,
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
    required this.number,
    required this.text,
    required this.selected,
    required this.checked,
    required this.correct,
    required this.onSelect,
  });
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
        : AppColors.purple;
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
  const _QuizResult({required this.correct, required this.total});
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8145E8), Color(0xFFBDA0F8)],
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
          color: AppColors.purple.withValues(alpha: .1),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.lavender
                    : AppColors.purple,
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
  const _ProblemDialog({required this.problem, required this.level});
  final PracticeProblem problem;
  final String level;

  @override
  State<_ProblemDialog> createState() => _ProblemDialogState();
}

class _ProblemDialogState extends State<_ProblemDialog> {
  final answer = TextEditingController();
  bool? correct;

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
              backgroundColor: AppColors.purple,
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
                  color: AppColors.purple.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.terminal_rounded,
                  color: dark ? AppColors.lavender : AppColors.purple,
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
          const SizedBox(height: 23),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF332748) : const Color(0xFFF2EAFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'БОДООД ҮЗЬЕ',
                  style: TextStyle(
                    color: dark ? AppColors.lavender : AppColors.purple,
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
          const SizedBox(height: 22),
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
                color: dark ? AppColors.lavender : AppColors.purple,
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
