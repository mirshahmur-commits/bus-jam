import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'game/controller.dart';
import 'platform/monetization.dart';
import 'platform/leaderboards.dart';
import 'platform/durable_analytics.dart';
import 'platform/remote_config.dart';
import 'platform/progress_store.dart';
import 'ui/app.dart';
import 'ui/urban_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UrbanAssets.instance.load();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final analytics = DurableAnalytics(
    PreferencesProgressStore(key: 'bus_jam.analytics.v1'),
  );
  await analytics.load();
  final ads = defaultAds(analytics);
  final storeKit = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? StoreKitPurchases()
      : null;
  final controller = GameController(
    store: PreferencesProgressStore(),
    ads: ads,
    purchases: storeKit,
    analytics: analytics,
    leaderboards: defaultLeaderboards(),
  );
  await controller.load();
  if (storeKit != null) {
    StoreKitPurchases.channel.setMethodCallHandler((call) async {
      if (call.method == 'entitlementChanged' && call.arguments is bool) {
        controller.updateEntitlement(call.arguments as bool);
      }
    });
    unawaited(
      storeKit.entitlement().then((value) {
        if (value != null) {
          controller.updateEntitlement(value);
        }
      }),
    );
  }
  runApp(BusJamApp(controller: controller));
  const configUrl = String.fromEnvironment('REMOTE_CONFIG_URL');
  if (configUrl.isNotEmpty) {
    unawaited(
      loadAdPolicy(configUrl).then((policy) {
        controller.adPolicy = policy;
      }),
    );
  }
  if (ads is AdMobAds) {
    unawaited(ads.initialize());
  }
}
