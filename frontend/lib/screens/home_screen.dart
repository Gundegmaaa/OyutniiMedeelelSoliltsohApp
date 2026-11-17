import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../services/calendar_event_store.dart';
import '../theme.dart';
import '../widgets/calendar_events.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.today,
    this.eventStore,
    this.displayName = 'Гүндэгмаа',
  });

  final String displayName;
  final DateTime? today;
  final CalendarEventStore? eventStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DateTime _today;
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  late final CalendarEventStore _eventStore;
  List<CalendarEvent> _events = [];
  bool _eventsLoading = true;
  bool _eventsSaving = false;
  bool _eventsLoadFailed = false;
  CalendarEventType? _filterType;

  static const _weekdays = [
    'Даваа',
    'Мягмар',
    'Лхагва',
    'Пүрэв',
    'Баасан',
    'Бямба',
    'Ням',
  ];
  static const _lessons = [
    [('09:00', 'Database', '302'), ('13:00', 'Software Engineering', '405')],
    [('10:00', 'Математик', '301')],
    [('09:00', 'OOP', '402')],
    [('11:00', 'Web Programming', '403')],
    [('13:00', 'Software Engineering', '405')],
    <(String, String, String)>[],
    <(String, String, String)>[],
  ];

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDate = _today;
    _visibleMonth = DateTime(now.year, now.month);
    _eventStore = widget.eventStore ?? SharedPreferencesCalendarEventStore();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _eventsLoading = true;
      _eventsLoadFailed = false;
    });
    try {
      final saved = await _eventStore.load();
      saved.sort(_compareEvents);
      if (!mounted) return;
      setState(() => _events = saved);
    } catch (_) {
      if (mounted) setState(() => _eventsLoadFailed = true);
    } finally {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  static int _compareEvents(CalendarEvent a, CalendarEvent b) {
    final dateOrder = a.date.compareTo(b.date);
    if (dateOrder != 0) return dateOrder;
    final timeOrder = (a.minutes ?? 1440).compareTo(b.minutes ?? 1440);
    return timeOrder != 0 ? timeOrder : a.title.compareTo(b.title);
  }

  List<CalendarEvent> _eventsOn(DateTime date) =>
      _events.where((event) => _sameDate(event.date, date)).toList();

  /// All events of [type]: upcoming ones by date first, then past ones with
  /// the most recent first.
  List<CalendarEvent> _eventsOfType(CalendarEventType type) {
    final matching = _events.where((event) => event.type == type);
    final upcoming =
        matching.where((event) => !event.date.isBefore(_today)).toList()
          ..sort(_compareEvents);
    final past = matching.where((event) => event.date.isBefore(_today)).toList()
      ..sort((a, b) => _compareEvents(b, a));
    return [...upcoming, ...past];
  }

  void _toggleFilter(CalendarEventType type) =>
      setState(() => _filterType = _filterType == type ? null : type);

  Future<bool> _saveEvents(
    List<CalendarEvent> updated, {
    DateTime? focusDate,
  }) async {
    if (_eventsLoading || _eventsLoadFailed || _eventsSaving) return false;
    setState(() => _eventsSaving = true);
    try {
      updated.sort(_compareEvents);
      await _eventStore.save(updated);
      if (!mounted) return false;
      setState(() {
        _events = updated;
        if (focusDate != null) {
          _selectedDate = focusDate;
          _visibleMonth = DateTime(focusDate.year, focusDate.month);
        }
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _eventsSaving = false);
    }
  }

  Future<void> _editEvent([CalendarEvent? event]) async {
    if (_eventsLoading || _eventsLoadFailed || _eventsSaving) return;
    if (event == null && _selectedDate.isBefore(_today)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Өнгөрсөн өдөрт тэмдэглэл нэмэх боломжгүй.'),
          ),
        );
      return;
    }
    final saved = await showCalendarEventEditor(
      context,
      date: _selectedDate,
      today: _today,
      event: event,
      onSave: (draft) => _saveEvents([
        ..._events.where((item) => item.id != draft.id),
        draft,
      ], focusDate: draft.date),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Тэмдэглэл хадгалагдлаа')));
    }
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    if (_eventsSaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Тэмдэглэл устгах уу?'),
        content: Text('“${event.title}” тэмдэглэлийг устгана.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-event'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = await _saveEvents(
      _events.where((item) => item.id != event.id).toList(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Тэмдэглэл устгагдлаа'
              : 'Устгаж чадсангүй. Дахин оролдоно уу.',
        ),
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _goToToday() => setState(() {
    _selectedDate = _today;
    _visibleMonth = DateTime(_today.year, _today.month);
  });

  void _changeMonth(int offset) => setState(() {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
  });

  void _showAnnouncement() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('📢 Шалгалтын хуваарь'),
      content: const Text(
        'Намрын улирлын шалгалтын хуваарь шинэчлэгдлээ.\n\n'
        'Дэлгэрэнгүй хуваарийг сургалтын албаны 201 тоотоос авна уу.\n\n'
        'Сургалтын алба • Өнөөдөр',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Хаах'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedLessons = _lessons[_selectedDate.weekday - 1];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF302343) : const Color(0xFFEDE4FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: AppColors.purple,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'YOUR STUDENT SPACE',
                    style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.waving_hand_rounded,
              color: AppColors.orange,
              size: 24,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Сайн байна уу, ${widget.displayName} 👋',
          style: TextStyle(
            fontSize: 25,
            height: 1.28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Өнөөдөр ч бас нэг алхам урагшилъя.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _welcomeCard(),
        const SizedBox(height: 22),
        _announcementCard(dark),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: SectionTitle('Миний календарь')),
            TextButton(
              onPressed: _goToToday,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.purple,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                'Өнөөдөр',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _calendar(dark),
        const SizedBox(height: 24),
        _importantDates(dark),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    _sameDate(_selectedDate, _today)
                        ? 'Өнөөдрийн хичээл'
                        : 'Сонгосон өдрийн хичээл',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_selectedDate.month} сарын ${_selectedDate.day} • ${_weekdays[_selectedDate.weekday - 1]}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF302343) : const Color(0xFFEDE4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${selectedLessons.length} хичээл',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: const ValueKey('open-week-schedule'),
            onPressed: _showWeekSchedule,
            style: FilledButton.styleFrom(
              backgroundColor: dark
                  ? const Color(0xFF403052)
                  : AppColors.paleBlue,
              foregroundColor: dark
                  ? const Color(0xFFD2B8FF)
                  : AppColors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            icon: const Icon(Icons.view_week_rounded, size: 19),
            label: const Text('Долоо хоногийн хуваарь харах'),
          ),
        ),
        const SizedBox(height: 16),
        if (selectedLessons.isEmpty) _emptySchedule(dark),
        for (var index = 0; index < selectedLessons.length; index++) ...[
          _lessonCard(selectedLessons[index], index, dark),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        const Text(
          'Долоо хоног бүр давтагдах хичээлийн хуваарь',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _welcomeCard() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9A67F9), Color(0xFF7030DC), Color(0xFF5631BD)],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: AppColors.purple.withValues(alpha: 0.2),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -44,
          top: -44,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          right: 30,
          bottom: -74,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 20,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ШИНЭ ӨДӨР. ШИНЭ БОЛОМЖ.',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 11),
                        const Text(
                          'Их мөрөөдөл,\nжижиг алхмууд.',
                          style: TextStyle(
                            fontSize: 26,
                            height: 1.14,
                            letterSpacing: -0.6,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.rotate(
                    angle: -0.12,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC4AEFF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x553A1688),
                            blurRadius: 0,
                            offset: Offset(4, 7),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 43,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFFD479),
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _lessons[_today.weekday - 1].isEmpty
                            ? 'Өнөөдөр амарч, эрч хүчээ цэнэглээрэй!'
                            : 'Өнөөдөр ${_lessons[_today.weekday - 1].length} хичээл таныг хүлээж байна',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _announcementCard(bool dark) => Material(
    color: dark ? const Color(0xFF342A40) : const Color(0xFFFFECDD),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: _showAnnouncement,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 46,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF61432D) : const Color(0xFFFFD2AE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Color(0xFFD87532),
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ШИНЭ ЗАРЛАЛ',
                    style: TextStyle(
                      color: Color(0xFFCC793D),
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Шалгалтын хуваарь шинэчлэгдлээ',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                      color: dark
                          ? const Color(0xFFFFDFC6)
                          : const Color(0xFF704021),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Сургалтын алба • Өнөөдөр',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFCC793D),
              size: 14,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _importantDates(bool dark) {
    final filter = _filterType;
    final events = filter == null
        ? _eventsOn(_selectedDate)
        : _eventsOfType(filter);
    return Column(
      key: const ValueKey('important-dates'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: SectionTitle('Чухал өдрүүд')),
            TextButton.icon(
              key: const ValueKey('add-calendar-event'),
              onPressed: _eventsLoading || _eventsLoadFailed || _eventsSaving
                  ? null
                  : () => _editEvent(),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Нэмэх'),
            ),
          ],
        ),
        Text(
          filter == null
              ? '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')} • ${events.length} тэмдэглэл'
              : '${filter.label} • ${events.length} тэмдэглэл',
          key: const ValueKey('important-dates-subtitle'),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        if (_eventsLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_eventsLoadFailed)
          SurfaceCard(
            child: Column(
              children: [
                const Text(
                  'Тэмдэглэлүүдийг уншиж чадсангүй. Дахин оролдоно уу.',
                  textAlign: TextAlign.center,
                ),
                TextButton.icon(
                  key: const ValueKey('retry-calendar-events'),
                  onPressed: _loadEvents,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Дахин оролдох'),
                ),
              ],
            ),
          )
        else if (events.isEmpty)
          Container(
            key: const ValueKey('no-calendar-events'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF302343) : const Color(0xFFF0E8FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  filter == null
                      ? Icons.event_note_rounded
                      : calendarEventIcon(filter),
                  color: filter == null
                      ? Theme.of(context).colorScheme.primary
                      : calendarEventColor(filter, dark: dark),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filter == null
                            ? 'Энэ өдөр тэмдэглэлгүй'
                            : 'Энэ төрлийн тэмдэглэл алга.',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        filter == null
                            ? 'Шалгалт, бие даалт, семинараа мартахгүйн тулд нэмээрэй.'
                            : 'Төрлийг дахин дарж бүх өдрийн тэмдэглэл рүү буцна.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final event in events) ...[
          CalendarEventCard(
            event: event,
            showDate: filter != null,
            onEdit: () => _editEvent(event),
            onDelete: () => _deleteEvent(event),
          ),
          const SizedBox(height: 10),
        ],
        if (_eventsSaving) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _calendar(bool dark) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingDays = first.weekday - 1;
    final cellCount = ((leadingDays + daysInMonth) / 7).ceil() * 7;

    return SurfaceCard(
      padding: 14,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF302343)
                      : const Color(0xFFF0E9FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_visibleMonth.year} он\n${_visibleMonth.month} сар',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Өмнөх сар',
                onPressed: () => _changeMonth(-1),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left_rounded, size: 23),
              ),
              IconButton(
                tooltip: 'Дараах сар',
                onPressed: () => _changeMonth(1),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right_rounded, size: 23),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final day in ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'])
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 56,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final date = DateTime(
                first.year,
                first.month,
                index - leadingDays + 1,
              );
              final isSelected = _sameDate(date, _selectedDate);
              final isToday = _sameDate(date, _today);
              final inMonth = date.month == _visibleMonth.month;
              final hasLessons = date.weekday <= DateTime.friday;
              final events = _eventsOn(date)
                  .where(
                    (event) => _filterType == null || event.type == _filterType,
                  )
                  .toList();
              final eventTypes = events.map((event) => event.type).toSet();
              final labelColor = isSelected
                  ? Colors.white
                  : !inMonth
                  ? AppColors.muted.withValues(alpha: 0.45)
                  : isToday
                  ? AppColors.purple
                  : Theme.of(context).textTheme.bodyLarge?.color;
              return Semantics(
                key: ValueKey(
                  'calendar-${date.year}-${date.month}-${date.day}',
                ),
                label:
                    '${date.year} оны ${date.month} сарын ${date.day}, ${_weekdays[date.weekday - 1]}${isToday ? ', өнөөдөр' : ''}'
                    '${events.isEmpty ? '' : ', ${events.length} тэмдэглэл: ${eventTypes.map((type) => type.label).join(', ')}'}',
                selected: isSelected,
                button: true,
                child: Material(
                  color: isSelected
                      ? AppColors.purple
                      : isToday
                      ? (dark
                            ? const Color(0xFF38264F)
                            : const Color(0xFFEFE6FF))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _selectedDate = date;
                      _visibleMonth = DateTime(date.year, date.month);
                    }),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: labelColor,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 30,
                          width: 30,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 2,
                            runSpacing: 2,
                            children: events.isNotEmpty
                                ? [
                                    for (final type in eventTypes)
                                      Tooltip(
                                        message: events
                                            .where(
                                              (event) => event.type == type,
                                            )
                                            .map(
                                              (event) =>
                                                  '${type.label}: ${event.title}',
                                            )
                                            .join('\n'),
                                        child: Container(
                                          key: ValueKey(
                                            'event-marker-${date.year}-${date.month}-${date.day}-${type.name}',
                                          ),
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            color: isSelected
                                                ? Colors.white
                                                : calendarEventColor(
                                                    type,
                                                    dark: dark,
                                                  ).withValues(alpha: .1),
                                          ),
                                          child: Icon(
                                            calendarEventIcon(type),
                                            size: 12,
                                            color: calendarEventColor(
                                              type,
                                              dark: dark,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ]
                                : [
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: !hasLessons || !inMonth
                                            ? Colors.transparent
                                            : isSelected
                                            ? const Color(0xFFE1D4FF)
                                            : AppColors.lavender,
                                      ),
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 15),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          const SizedBox(height: 13),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in CalendarEventType.values)
                _filterChip(type, dark),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Өдрөө сонгоод тэмдэглэлээ нэмээрэй. Төрөл дээр дарвал тухайн төрлийн бүх тэмдэглэл харагдана.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(CalendarEventType type, bool dark) {
    final selected = _filterType == type;
    final color = calendarEventColor(type, dark: dark);
    return Semantics(
      button: true,
      selected: selected,
      label: '${type.label} төрлөөр шүүх',
      excludeSemantics: true,
      child: Material(
        key: ValueKey('event-filter-${type.name}'),
        color: selected
            ? color.withValues(alpha: dark ? .22 : .12)
            : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? color : Theme.of(context).dividerColor,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => _toggleFilter(type),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(calendarEventIcon(type), size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? color
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.close_rounded, size: 13, color: color),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWeekSchedule() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (context) {
      final theme = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: ListView(
          key: const ValueKey('week-schedule-sheet'),
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const SectionTitle('Хичээлийн хуваарь'),
            const SizedBox(height: 4),
            Text(
              'Долоо хоног бүр давтагдана',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var day = 0; day < _weekdays.length; day++) ...[
              _weekScheduleDay(context, day, dark),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );
    },
  );

  Widget _weekScheduleDay(BuildContext context, int day, bool dark) {
    final theme = Theme.of(context);
    final isToday = _today.weekday - 1 == day;
    final lessons = _lessons[day];
    return Container(
      key: ValueKey('week-day-$day'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isToday
            ? (dark ? const Color(0xFF38264F) : const Color(0xFFF0E9FF))
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday
              ? AppColors.purple.withValues(alpha: dark ? .7 : .45)
              : theme.dividerColor,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _weekdays[day],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              if (isToday)
                Container(
                  key: const ValueKey('week-day-today'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Өнөөдөр',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (lessons.isEmpty)
            Text(
              'Хичээлгүй',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final lesson in lessons)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: lesson.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    TextSpan(
                      text: ' • ${lesson.$2}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: ' • ${lesson.$3} тоот',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lessonCard((String, String, String) lesson, int index, bool dark) {
    final accent = index.isEven ? AppColors.purple : const Color(0xFF199C83);
    final pale = index.isEven
        ? const Color(0xFFF0E9FF)
        : const Color(0xFFE2F7EF);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: dark ? accent.withValues(alpha: 0.15) : pale,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Icon(
                  index.isEven
                      ? Icons.auto_stories_rounded
                      : Icons.code_rounded,
                  color: accent,
                  size: 20,
                ),
                const SizedBox(height: 7),
                Text(
                  lesson.$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.$2,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: accent),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${lesson.$3} тоот',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySchedule(bool dark) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: dark ? const Color(0xFF253932) : const Color(0xFFE5F7EF),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Column(
      children: [
        Icon(Icons.weekend_rounded, size: 42, color: Color(0xFF42AF8E)),
        SizedBox(height: 12),
        Text(
          'Амралтын өдөр 🌿',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 7),
        Text(
          'Энэ өдөр хичээлгүй.\nӨөртөө цаг гаргаарай!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
        ),
      ],
    ),
  );
}
