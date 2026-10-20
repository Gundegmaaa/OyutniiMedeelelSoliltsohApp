import 'package:flutter/material.dart';

import '../theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
  );
}

class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.text, required this.onPressed});
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF253858)
          : AppColors.paleBlue,
      foregroundColor: AppColors.blue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
    ),
    child: Text(text),
  );
}

class SegmentTabs extends StatelessWidget {
  const SegmentTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(
      labels.length,
      (index) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 6),
          child: Semantics(
            selected: selected == index,
            child: FilledButton(
              onPressed: () => onSelected(index),
              style: FilledButton.styleFrom(
                backgroundColor: selected == index
                    ? AppColors.blue
                    : Theme.of(context).dividerColor,
                foregroundColor: selected == index
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 17,
                ),
                textStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: labels.length == 2 ? 12 : 14,
                ),
              ),
              child: Text(labels[index], textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ),
  );
}
