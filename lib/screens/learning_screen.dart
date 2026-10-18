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
    if (points == null || !mounted) {
      return;
    }
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
    if (solved != true || !mounted) {
      return;
    }
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(26, 16, 26, 40),
    children: [
      const Text(
        'Суралцах',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 22),
      SegmentTabs(
        labels: const ['Software Engineering', 'Information System'],
        selected: program,
        onSelected: (value) => setState(() => program = value),
      ),
      const SizedBox(height: 28),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🧠 QUIZ',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.navy,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final subject
                          in program == 0
                              ? ['OOP', 'Database', 'Web Programming']
                              : [
                                  'Системийн шинжилгээ',
                                  'Database',
                                  'Мэдээллийн систем',
                                ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PillButton(text: 'ЭХЛҮҮЛЭХ', onPressed: startQuiz),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💻 БОДЛОГО',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.navy,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 2 ? 0 : 10),
                    child: Column(
                      children: [
                        Text(
                          ['Хялбар', 'Дунд', 'Хүнд'][index],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: PillButton(
                            text: 'Эхлэх',
                            onPressed: () => startProblem(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏆 ОЮУТНЫ RANK',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            for (final student in [
              ('🥇 Бат-Эрдэнэ', 1250),
              ('🥈 Анужин', 1190),
              ('🥉 Тэмүүлэн', 1110),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.$1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${student.$2} XP',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFB3CCEB),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF3A4969)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Таны байр: #${widget.progress.rank}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${widget.progress.xp} XP',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF93C5FD),
                  ),
                ),
              ],
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[index];
    return AlertDialog(
      title: Text(
        finished
            ? 'Quiz дууслаа 🎉'
            : 'QUIZ • ${index + 1}/${widget.questions.length}',
      ),
      content: SingleChildScrollView(
        child: finished
            ? Text(
                'Та ${widget.questions.length} асуултаас $correct зөв хариуллаа.\n\n${correct * 20} XP',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: (index + 1) / widget.questions.length,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    question.prompt,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (
                    int option = 0;
                    option < question.options.length;
                    option++
                  )
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: checked
                            ? null
                            : () => setState(() => selected = option),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selected == option
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          padding: const EdgeInsets.all(14),
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(question.options[option]),
                      ),
                    ),
                  if (checked)
                    Text(
                      '${selected == question.answer ? 'Зөв хариуллаа!' : 'Дахин давтаарай.'}\n${question.explanation}',
                    ),
                ],
              ),
      ),
      actions: [
        if (!finished)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Гарах'),
          ),
        FilledButton(
          onPressed: !finished && selected == null
              ? null
              : () {
                  if (finished) {
                    Navigator.pop(context, correct > 0 ? correct * 20 : null);
                    return;
                  }
                  setState(() {
                    if (!checked) {
                      checked = true;
                      if (selected == question.answer) {
                        correct++;
                      }
                    } else if (index == widget.questions.length - 1) {
                      finished = true;
                    } else {
                      index++;
                      selected = null;
                      checked = false;
                    }
                  });
                },
          child: Text(
            finished
                ? 'Дуусгах'
                : checked
                ? 'Дараах'
                : 'Шалгах',
          ),
        ),
      ],
    );
  }
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.level} бодлого • ${widget.problem.xp} XP'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.problem.prompt),
          const SizedBox(height: 20),
          TextField(
            controller: answer,
            keyboardType: TextInputType.number,
            enabled: correct != true,
            decoration: InputDecoration(
              labelText: 'Хариу',
              errorText: correct == false
                  ? 'Хариу буруу байна. Дахин оролдоорой.'
                  : null,
            ),
          ),
          if (correct == true) ...[
            const SizedBox(height: 18),
            Text('Зөв! ${widget.problem.explanation}'),
          ],
        ],
      ),
    ),
    actions: [
      if (correct != true)
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Гарах'),
        ),
      FilledButton(
        onPressed: () {
          if (correct == true) {
            Navigator.pop(context, true);
          } else {
            setState(
              () => correct = answer.text.trim() == widget.problem.answer,
            );
          }
        },
        child: Text(correct == true ? 'Дуусгах' : 'Шалгах'),
      ),
    ],
  );
}
