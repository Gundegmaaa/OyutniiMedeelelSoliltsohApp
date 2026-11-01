import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../theme.dart';

Color calendarEventColor(CalendarEventType type, {bool dark = false}) {
  return switch (type) {
    CalendarEventType.exam =>
      dark ? const Color(0xFFFF99CB) : const Color(0xFFBB347B),
    CalendarEventType.assignment =>
      dark ? const Color(0xFFFFBA80) : const Color(0xFFA95310),
    CalendarEventType.seminar => dark ? AppColors.lavender : AppColors.purple,
    CalendarEventType.other => dark ? AppColors.mint : const Color(0xFF127D6B),
  };
}

IconData calendarEventIcon(CalendarEventType type) {
  return switch (type) {
    CalendarEventType.exam => Icons.school_rounded,
    CalendarEventType.assignment => Icons.assignment_rounded,
    CalendarEventType.seminar => Icons.groups_rounded,
    CalendarEventType.other => Icons.push_pin_rounded,
  };
}

String _dateLabel(DateTime date) =>
    '${date.year} оны ${date.month}-р сарын ${date.day}';

String _timeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

Future<CalendarEvent?> showCalendarEventEditor(
  BuildContext context, {
  required DateTime date,
  CalendarEvent? event,
  Future<bool> Function(CalendarEvent)? onSave,
}) {
  return showModalBottomSheet<CalendarEvent>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (context) =>
        _CalendarEventEditor(date: date, event: event, onSave: onSave),
  );
}

class _CalendarEventEditor extends StatefulWidget {
  const _CalendarEventEditor({required this.date, this.event, this.onSave});

  final DateTime date;
  final CalendarEvent? event;
  final Future<bool> Function(CalendarEvent)? onSave;

  @override
  State<_CalendarEventEditor> createState() => _CalendarEventEditorState();
}

class _CalendarEventEditorState extends State<_CalendarEventEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _date;
  late CalendarEventType _type;
  int? _minutes;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _date = event?.date ?? widget.date;
    _type = event?.type ?? CalendarEventType.exam;
    _minutes = event?.minutes;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final firstDate = DateTime(1900);
    final lastDate = DateTime(2100, 12, 31);
    final initialDate = _date.isBefore(firstDate)
        ? firstDate
        : _date.isAfter(lastDate)
        ? lastDate
        : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Өдөр сонгох',
      cancelText: 'Болих',
      confirmText: 'Сонгох',
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _chooseTime() async {
    final minutes = _minutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: minutes == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: 'Цаг сонгох',
      cancelText: 'Болих',
      confirmText: 'Сонгох',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _minutes = selected.hour * 60 + selected.minute);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final event = CalendarEvent(
      id: widget.event?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      date: DateTime(_date.year, _date.month, _date.day),
      type: _type,
      notes: _notes.text.trim(),
      minutes: _minutes,
    );
    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop(event);
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final saved = await onSave(event);
    if (!mounted) return;
    if (saved) {
      setState(() => _saving = false);
      Navigator.of(context).pop(event);
    } else {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = calendarEventColor(_type, dark: dark);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = (MediaQuery.sizeOf(context).height * .9 - keyboardInset)
        .clamp(120.0, double.infinity);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              24,
              4,
              24,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.event == null
                              ? 'Чухал өдөр нэмэх'
                              : 'Тэмдэглэл засах',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        tooltip: 'Хаах',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Шалгалт, бие даалт, семинарын өдрөө тэмдэглээрэй.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Төрөл',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final type in CalendarEventType.values)
                        ChoiceChip(
                          avatar: Icon(
                            calendarEventIcon(type),
                            size: 18,
                            color: calendarEventColor(type, dark: dark),
                          ),
                          label: Text(type.label),
                          selected: _type == type,
                          showCheckmark: false,
                          selectedColor: calendarEventColor(
                            type,
                            dark: dark,
                          ).withValues(alpha: dark ? .22 : .12),
                          labelStyle: TextStyle(
                            color: _type == type
                                ? calendarEventColor(type, dark: dark)
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: _type == type
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: _type == type
                                ? calendarEventColor(type, dark: dark)
                                : theme.dividerColor,
                          ),
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => _type = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('event-title'),
                    controller: _title,
                    enabled: !_saving,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Гарчиг',
                      hintText: 'Жишээ: Математикийн шалгалт',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Гарчиг оруулна уу.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('event-date'),
                    onPressed: _saving ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(_dateLabel(_date)),
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('event-time'),
                          onPressed: _saving ? null : _chooseTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(
                            _minutes == null
                                ? 'Цаг нэмэх (заавал биш)'
                                : _timeLabel(_minutes!),
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      if (_minutes != null)
                        IconButton(
                          tooltip: 'Цагийг арилгах',
                          onPressed: _saving
                              ? null
                              : () => setState(() => _minutes = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const ValueKey('event-notes'),
                    controller: _notes,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Тайлбар (заавал биш)',
                      hintText: 'Өрөө, бэлдэх зүйл, санах тэмдэглэл…',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_saveFailed) ...[
                    Text(
                      'Хадгалж чадсангүй. Дахин оролдоно уу.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    key: const ValueKey('save-calendar-event'),
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: dark
                          ? theme.colorScheme.surface
                          : Colors.white,
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Хадгалж байна…' : 'Хадгалах'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarEventCard extends StatelessWidget {
  const CalendarEventCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = calendarEventColor(event.type, dark: dark);
    return Container(
      key: ValueKey('event-card-${event.id}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .1 : .06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(calendarEventIcon(event.type), size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.type.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('edit-event-${event.id}'),
                onPressed: onEdit,
                tooltip: 'Тэмдэглэл засах',
                icon: const Icon(Icons.edit_outlined, size: 19),
                color: theme.colorScheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                key: ValueKey('delete-event-${event.id}'),
                onPressed: onDelete,
                tooltip: 'Тэмдэглэл устгах',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: theme.colorScheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              event.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (event.minutes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: color),
                const SizedBox(width: 5),
                Text(
                  _timeLabel(event.minutes!),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
          if (event.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                event.notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
