import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/button.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';
import 'package:mashinow_washer/features/washer_repository.dart';

/// One editable day row.
class _DayDraft {
  final DateTime day;

  bool enabled;
  TimeOfDay start;
  TimeOfDay end;

  _DayDraft({
    required this.day,
    this.enabled = true,
    required this.start,
    required this.end,
  });
}

/// Weekly working-hours editor — bulk-creates working sessions for the
/// next seven days (this is how the backend models availability).
class WorkingHoursPage extends ConsumerStatefulWidget {
  const WorkingHoursPage({super.key});

  @override
  ConsumerState<WorkingHoursPage> createState() => _WorkingHoursPageState();
}

class _WorkingHoursPageState extends ConsumerState<WorkingHoursPage> {
  List<_DayDraft>? _days;
  bool _saving = false;

  Future<void> _pickTime(_DayDraft draft, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? draft.start : draft.end,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        draft.start = picked;
      } else {
        draft.end = picked;
      }
    });
  }

  Future<void> _save() async {
    final days =
        _days!.where((draft) => draft.enabled).toList(growable: false);

    if (days.isEmpty) {
      Toast.error(context, title: 'حداقل یک روز باید فعال باشد');
      return;
    }

    for (final draft in days) {
      if (draft.end.hour * 60 + draft.end.minute <=
          draft.start.hour * 60 + draft.start.minute) {
        Toast.error(
          context,
          title: 'ساعت پایان باید بعد از شروع باشد',
          description:
              'روز ${Formatter.weekdayName(draft.day)} را اصلاح کنید.',
        );
        return;
      }
    }

    setState(() => _saving = true);

    final repository = ref.read(washerRepositoryProvider);

    final items = days
        .map((draft) => WorkingSessionSaveItem(
              start: DateTime(
                draft.day.year,
                draft.day.month,
                draft.day.day,
                draft.start.hour,
                draft.start.minute,
              ),
              end: DateTime(
                draft.day.year,
                draft.day.month,
                draft.day.day,
                draft.end.hour,
                draft.end.minute,
              ),
            ))
        .toList();

    try {
      await repository.saveWorkingSessions(items);

      if (mounted) {
        Toast.success(context, title: 'ساعات کاری ثبت شد');
        ref.invalidate(workingSessionsProvider);
        ref.invalidate(timeSlotsProvider);
        setState(() => _saving = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        Toast.error(
          context,
          title: 'ثبت نشد',
          description: error is ServerError ? error.message : error.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    final sessionsAsync = ref.watch(workingSessionsProvider);

    _days ??= _initDaysSafe();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ساعات کاری',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // :: INFO CARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_rounded, color: colors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ساعات کاری هفته آینده را تعیین کنید؛ مشتری‌ها فقط در همین بازه‌ها می‌توانند رزرو کنند.',
                    style: types.bodySmall?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // :: DAY ROWS
          ..._days!.map(
            (draft) => _DayRow(
              draft: draft,
              onToggle: (value) =>
                  setState(() => draft.enabled = value ?? false),
              onPickStart: () => _pickTime(draft, true),
              onPickEnd: () => _pickTime(draft, false),
            ),
          ),

          const SizedBox(height: 20),
          AppButton(
            label: 'ثبت ساعات کاری',
            icon: Icons.save_rounded,
            onPressed: _saving ? null : _save,
          ),

          const SizedBox(height: 28),

          // :: EXISTING SESSIONS
          Text(
            'سشن‌های ثبت‌شده',
            style: types.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          sessionsAsync.when(
            loading: () => const PageLoading(),
            error: (error, _) => ViewState<List<dynamic>>(
              loading: false,
              error: error,
              data: const [],
              onRetry: () => ref.refresh(workingSessionsProvider.future),
              builder: (_) => const SizedBox.shrink(),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Text(
                  'هنوز سشنی ثبت نشده است.',
                  style: types.bodySmall?.copyWith(color: colors.outline),
                );
              }

              return Column(
                children: sessions
                    .map<Widget>(
                      (session) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                size: 20, color: colors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${Formatter.weekdayName(session.startTime)} ${Formatter.jalaliDate(session.startTime)}',
                                style: types.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${Formatter.time(session.startTime)} تا ${Formatter.time(session.endTime)}',
                              style: types.bodySmall
                                  ?.copyWith(color: colors.outline),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<_DayDraft> _initDaysSafe() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return List.generate(
      7,
      (index) {
        final day = today.add(Duration(days: index));
        final isFriday = day.weekday == DateTime.friday;
        return _DayDraft(
          day: day,
          enabled: !isFriday,
          start: const TimeOfDay(hour: 9, minute: 0),
          end: const TimeOfDay(hour: 18, minute: 0),
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  final _DayDraft draft;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DayRow({
    required this.draft,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: draft.enabled
            ? colors.surfaceContainerHigh
            : colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Formatter.weekdayName(draft.day)} — ${Formatter.jalaliDate(draft.day)}',
                  style: types.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: draft.enabled ? colors.onSurface : colors.outline,
                  ),
                ),
              ),
              Switch(
                value: draft.enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          if (draft.enabled)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _TimePill(
                      icon: Icons.play_arrow_rounded,
                      label: Formatter.timeOfDay(draft.start),
                      onTap: onPickStart,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('تا'),
                  ),
                  Expanded(
                    child: _TimePill(
                      icon: Icons.stop_rounded,
                      label: Formatter.timeOfDay(draft.end),
                      onTap: onPickEnd,
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

class _TimePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TimePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
