import 'dart:async';
import 'dart:convert';

import 'analytics.dart';
import 'progress_store.dart';

/// Anonymous local funnel/retention journal, separate from gameplay saves.
/// No network collector or personal data. Integrates via AnalyticsPort.
class DurableAnalytics implements AnalyticsPort {
  DurableAnalytics(this.store, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final ProgressStore store;
  final DateTime Function() clock;
  final List<Map<String, dynamic>> events = [];
  DateTime? firstSeen;
  final Set<String> activeDays = {};
  Future<void> _writes = Future.value();
  Future<void> load() async {
    try {
      final raw = await store.read();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        firstSeen = DateTime.parse(j['firstSeen'] as String);
        activeDays.addAll((j['days'] as List).cast<String>());
        events.addAll(
          (j['events'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .take(600),
        );
      }
    } catch (_) {
      events.clear();
      activeDays.clear();
    }
    firstSeen ??= clock();
  }

  @override
  void track(String event, Map<String, Object> properties) {
    final now = clock();
    firstSeen ??= now;
    final day = now.toIso8601String().substring(0, 10);
    activeDays.add(day);
    while (activeDays.length > 370) {
      activeDays.remove(activeDays.first);
    }
    if (events.length >= 600) {
      events.removeAt(0);
    }
    events.add({
      'event': event,
      'utc': now.toUtc().toIso8601String(),
      'properties': properties,
    });
    final value = jsonEncode({
      'firstSeen': firstSeen!.toIso8601String(),
      'days': activeDays.toList(),
      'events': events,
    });
    _writes = _writes.then((_) => store.write(value)).catchError((Object _) {});
    unawaited(_writes);
  }

  Future<void> flush() => _writes;
}
