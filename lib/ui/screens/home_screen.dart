import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/alarm.dart';
import '../providers/alarm_providers.dart';
import '../widgets/alarm_card.dart';
import '../widgets/empty_alarms_view.dart';

/// Main screen of the app. Lists every saved alarm in a card-based
/// layout, supports:
///   * Toggling each alarm on/off via a switch (instant persistence).
///   * Swiping a card left or right to delete it, with a confirmation
///     dialog and a snackbar "Undo" affordance.
///   * Adding a new alarm via a floating action button (the actual
///     editor screen will be implemented by a later agent; this screen
///     only exposes a stable hook).
///
/// The UI is driven by [alarmListProvider], a Riverpod [StreamProvider]
/// that watches the underlying Hive box. Any change made anywhere in
/// the app (or by background isolates) flows back into this list with
/// no extra wiring.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Alarm>> alarmsAsync = ref.watch(alarmListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms'),
        actions: <Widget>[
          // Quick visual feedback hook: tapping the AppBar refreshes
          // the stream-derived view. The stream itself never errors out
          // in practice (it's backed by a local Hive box), so this is
          // mostly here for resiliency on cold restart.
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              // Re-emit the latest snapshot.
              // ignore: unused_result
              ref.refresh(alarmListProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        // Smooth, animated transitions between states (loading → list,
        // list → empty, etc.) – feels far more polished than a hard cut.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: alarmsAsync.when(
            // While the very first snapshot is coming in.
            loading: () => const _LoadingView(key: ValueKey<String>('loading')),
            error: (Object error, StackTrace _) => _ErrorView(
              key: const ValueKey<String>('error'),
              message: error.toString(),
              onRetry: () {
                // ignore: unused_result
                ref.refresh(alarmListProvider);
              },
            ),
            data: (List<Alarm> alarms) {
              if (alarms.isEmpty) {
                return EmptyAlarmsView(
                  key: const ValueKey<String>('empty'),
                  onAddPressed: () => _handleAddAlarm(context),
                );
              }
              return _AlarmList(
                key: const ValueKey<String>('list'),
                alarms: alarms,
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleAddAlarm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add alarm'),
        tooltip: 'Add a new alarm',
      ),
    );
  }

  /// Hook for the "+" affordance. The editor lives in another agent's
  /// scope, so for now we surface a lightweight notice so the screen
  /// remains fully functional in isolation. When the editor screen
  /// lands, swap the snackbar for `Navigator.push(... AlarmEditorScreen)`.
  void _handleAddAlarm(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Alarm editor coming soon.'),
          duration: Duration(seconds: 2),
        ),
      );
  }
}

// ---------------------------------------------------------------------------
//  States
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 56, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Could not load alarms',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  The actual list
// ---------------------------------------------------------------------------

/// Scrollable list of alarm cards, with swipe-to-delete support.
///
/// Uses a [ConsumerStatefulWidget] only so we can keep a stable
/// scroll controller across rebuilds. Repository access still flows
/// through Riverpod – no controller state is duplicated.
class _AlarmList extends ConsumerStatefulWidget {
  const _AlarmList({super.key, required this.alarms});

  final List<Alarm> alarms;

  @override
  ConsumerState<_AlarmList> createState() => _AlarmListState();
}

class _AlarmListState extends ConsumerState<_AlarmList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive horizontal padding: tighter on narrow phones, more
    // breathing room on tablets / large screens.
    final double width = MediaQuery.sizeOf(context).width;
    final double horizontalPadding = width > 700
        ? (width - 640) / 2 // center within a 640-wide column
        : 16;

    return Scrollbar(
      controller: _controller,
      child: ListView.separated(
        controller: _controller,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          // Leave space so the FAB never covers the last card.
          120,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget.alarms.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          final Alarm alarm = widget.alarms[index];
          return _DismissibleAlarmCard(
            key: ValueKey<String>('alarm-${alarm.id}'),
            alarm: alarm,
          );
        },
      ),
    );
  }
}

/// Wraps an [AlarmCard] with [Dismissible] + confirmation + Undo,
/// so deletion is always recoverable.
class _DismissibleAlarmCard extends ConsumerWidget {
  const _DismissibleAlarmCard({super.key, required this.alarm});

  final Alarm alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    Widget swipeBackground({required Alignment alignment}) {
      return Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: alignment == Alignment.centerLeft
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: <Widget>[
            Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Text(
              'Delete',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
    }

    return Dismissible(
      key: ValueKey<String>('dismiss-${alarm.id}'),
      direction: DismissDirection.horizontal,
      background: swipeBackground(alignment: Alignment.centerLeft),
      secondaryBackground: swipeBackground(alignment: Alignment.centerRight),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _onDismissed(context, ref),
      child: AlarmCard(
        alarm: alarm,
        onToggleEnabled: (bool _) => _toggleEnabled(context, ref),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete alarm?'),
          content: Text(
            alarm.label.trim().isEmpty
                ? 'This alarm will be removed permanently.'
                : '"${alarm.label.trim()}" will be removed permanently.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
                foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onDismissed(BuildContext context, WidgetRef ref) async {
    // Capture a snapshot BEFORE deletion so Undo can restore it byte-for-byte.
    final Alarm snapshot = alarm;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alarmRepositoryProvider).delete(snapshot.id);
    } catch (e) {
      // Surface the error; we don't want to lose user data silently.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Alarm deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await ref.read(alarmRepositoryProvider).upsert(snapshot);
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Could not restore alarm')),
                );
              }
            },
          ),
        ),
      );
  }

  Future<void> _toggleEnabled(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(alarmRepositoryProvider).toggleEnabled(alarm.id);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not update alarm: $e')));
    }
  }
}
