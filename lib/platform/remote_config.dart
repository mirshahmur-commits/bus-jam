import 'dart:convert';

import 'package:http/http.dart' as http;

import 'monetization.dart';

/// Optional public JSON config. No service account, billing, or runtime AI.
/// Invalid/offline config always retains conservative local defaults.
Future<AdPolicy> loadAdPolicy(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return const AdPolicy();
  }
  final client = http.Client();
  try {
    final response = await client.get(uri).timeout(const Duration(seconds: 3));
    if (response.statusCode != 200 || response.body.length > 10000) {
      return const AdPolicy();
    }
    return AdPolicy.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  } catch (_) {
    return const AdPolicy();
  } finally {
    client.close();
  }
}
