abstract interface class AnalyticsPort {
  void track(String event, Map<String, Object> properties);
}

/// Bounded local buffer. No tracking SDK, network requests, or personal data.
class LocalAnalytics implements AnalyticsPort {
  final events = <({String name, Map<String, Object> properties})>[];
  @override
  void track(String event, Map<String, Object> properties) {
    if (events.length >= 200) events.removeAt(0);
    events.add((name: event, properties: Map.unmodifiable(properties)));
  }
}
