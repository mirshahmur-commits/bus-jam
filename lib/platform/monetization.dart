import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'analytics.dart';

enum AdOutcome { rewarded, dismissed, unavailable, error }

enum PurchaseOutcome { purchased, cancelled, pending, unavailable, error }

abstract interface class AdsPort {
  Future<AdOutcome> rewarded();
  Future<bool> interstitial();
  Future<void> privacyOptions();
  void dispose();
}

class OfflineAds implements AdsPort {
  @override
  Future<AdOutcome> rewarded() async => AdOutcome.unavailable;
  @override
  Future<bool> interstitial() async => false;
  @override
  Future<void> privacyOptions() async {}
  @override
  void dispose() {}
}

/// UMP must authorize ad requests before the Mobile Ads SDK is initialized.
/// Unit IDs are injected at build time; release never silently uses sample IDs.
class AdMobAds implements AdsPort {
  AdMobAds({required this.rewardedId, required this.interstitialId, this.analytics});
  final AnalyticsPort? analytics;
  final String rewardedId, interstitialId;
  bool _ready = false, _busy = false, _disposed = false;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  Future<void> initialize() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((error) async {
          if (await ConsentInformation.instance.canRequestAds() && !_disposed) {
            await MobileAds.instance.initialize();
            _ready = true;
          }
          if (!done.isCompleted) {
            done.complete();
          }
        });
      },
      (_) {
        if (!done.isCompleted) {
          done.complete();
        }
      },
    );
    await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  @override
  Future<AdOutcome> rewarded() async {
    if (!_ready || _busy || _disposed || rewardedId.isEmpty) {
      return AdOutcome.unavailable;
    }
    _busy = true;
    final done = Completer<AdOutcome>();
    var earned = false;
    void finish(AdOutcome result) {
      if (!done.isCompleted) {
        done.complete(result);
      }
    }

    try {
      await RewardedAd.load(
        adUnitId: rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdFailedToLoad: (_) => finish(AdOutcome.unavailable),
          onAdLoaded: (ad) {
            if (_disposed || done.isCompleted) {
              ad.dispose();
              return;
            }
            _rewarded = ad;
            ad.onPaidEvent = (ad, value, precision, currency) { analytics?.track('ad_revenue', {'micros': value, 'currency': currency, 'precision': precision.name}); };
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (_) { analytics?.track('ad_impression', {'format': 'rewarded'}); },
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _rewarded = null;
                finish(earned ? AdOutcome.rewarded : AdOutcome.dismissed);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _rewarded = null;
                finish(AdOutcome.error);
              },
            );
            ad.show(
              onUserEarnedReward: (ad, reward) {
                earned = true;
              },
            );
          },
        ),
      );
      return await done.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          finish(AdOutcome.error);
          _rewarded?.dispose();
          _rewarded = null;
          return AdOutcome.error;
        },
      );
    } catch (_) {
      return AdOutcome.error;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<bool> interstitial() async {
    if (!_ready || _busy || _disposed || interstitialId.isEmpty) {
      return false;
    }
    _busy = true;
    final done = Completer<bool>();
    void finish(bool shown) {
      if (!done.isCompleted) {
        done.complete(shown);
      }
    }

    try {
      await InterstitialAd.load(
        adUnitId: interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdFailedToLoad: (_) => finish(false),
          onAdLoaded: (ad) {
            if (_disposed || done.isCompleted) {
              ad.dispose();
              return;
            }
            _interstitial = ad;
            ad.onPaidEvent = (ad, value, precision, currency) { analytics?.track('ad_revenue', {'micros': value, 'currency': currency, 'precision': precision.name}); };
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitial = null;
                finish(true);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _interstitial = null;
                finish(false);
              },
            );
            ad.show();
          },
        ),
      );
      return await done.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          finish(false);
          _interstitial?.dispose();
          _interstitial = null;
          return false;
        },
      );
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> privacyOptions() async {
    if (_disposed) {
      return;
    }
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) {
        done.complete();
      }
    });
    await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
  }

  @override
  void dispose() {
    _disposed = true;
    _rewarded?.dispose();
    _interstitial?.dispose();
  }
}

abstract interface class PurchasesPort {
  Future<PurchaseOutcome> buyRemoveAds();
  Future<bool?> restore();
  Future<String?> price();
}

class OfflinePurchases implements PurchasesPort {
  @override
  Future<PurchaseOutcome> buyRemoveAds() async => PurchaseOutcome.unavailable;
  @override
  Future<bool?> restore() async => null;
  @override
  Future<String?> price() async => null;
}

/// iOS uses StoreKit 2 verified transactions in the native bridge. No client
/// flag or unverified receipt is accepted as a new purchase.
class StoreKitPurchases implements PurchasesPort {
  static const channel = MethodChannel('com.systemcraft.busjam/store');
  @override
  Future<PurchaseOutcome> buyRemoveAds() async {
    try {
      final result = await channel.invokeMethod<String>('purchase');
      return switch (result) {
        'purchased' => PurchaseOutcome.purchased,
        'cancelled' => PurchaseOutcome.cancelled,
        'pending' => PurchaseOutcome.pending,
        'unavailable' => PurchaseOutcome.unavailable,
        _ => PurchaseOutcome.error,
      };
    } catch (_) {
      return PurchaseOutcome.error;
    }
  }

  @override
  Future<bool?> restore() async {
    try {
      return await channel.invokeMethod<bool>('restore');
    } catch (_) {
      return null;
    }
  }

  Future<bool?> entitlement() async {
    try {
      return await channel.invokeMethod<bool>('entitlement');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> price() async {
    try {
      return await channel.invokeMethod<String>('price');
    } catch (_) {
      return null;
    }
  }
}

class AdPolicy {
  const AdPolicy({
    this.firstLevel = 6,
    this.everyWins = 4,
    this.cooldownSeconds = 180,
  });
  final int firstLevel, everyWins, cooldownSeconds;
  bool allows({
    required int level,
    required int wins,
    required bool removed,
    required DateTime now,
    DateTime? lastAd,
  }) =>
      !removed &&
      level >= firstLevel &&
      wins > 0 &&
      everyWins > 0 &&
      wins % everyWins == 0 &&
      (lastAd == null || now.difference(lastAd).inSeconds >= cooldownSeconds);
  factory AdPolicy.fromJson(Map<String, dynamic> j) => AdPolicy(
    firstLevel: (j['firstLevel'] as int? ?? 6).clamp(6, 100),
    everyWins: (j['everyWins'] as int? ?? 4).clamp(3, 20),
    cooldownSeconds: (j['cooldownSeconds'] as int? ?? 180).clamp(120, 3600),
  );
}

AdsPort defaultAds([AnalyticsPort? analytics]) {
  if (kIsWeb ||
      ![
        TargetPlatform.iOS,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform)) {
    return OfflineAds();
  }
  const reward = String.fromEnvironment('ADMOB_REWARDED_ID');
  const interstitial = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');
  return reward.isEmpty
      ? OfflineAds()
      : AdMobAds(rewardedId: reward, interstitialId: interstitial, analytics: analytics);
}
