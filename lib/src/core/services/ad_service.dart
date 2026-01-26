import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service for managing rewarded ads in the app
class AdService extends ChangeNotifier {
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  bool get isAdLoaded => _isAdLoaded;
  bool get isLoading => _isLoading;

  /// Ad Unit IDs
  static String get rewardedAdUnitId {
    if (kDebugMode) {
      // Test ad unit IDs for development
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/5224354917'; // Test rewarded ad
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/1712485313'; // Test rewarded ad
      }
    }
    // Production ad unit ID
    return 'ca-app-pub-5118580699569063/6977600482';
  }

  /// Initialize the Mobile Ads SDK
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    debugPrint('AdMob SDK initialized');
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_isLoading || _isAdLoaded) return;

    _isLoading = true;
    notifyListeners();

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded ad loaded successfully');
          _rewardedAd = ad;
          _isAdLoaded = true;
          _isLoading = false;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Failed to load rewarded ad: ${error.message}');
          _rewardedAd = null;
          _isAdLoaded = false;
          _isLoading = false;
          notifyListeners();
        },
      ),
    );
  }

  /// Show the rewarded ad and call onRewarded when user earns reward
  /// Returns true if ad was shown, false if not available
  Future<bool> showRewardedAd({
    required Function onRewarded,
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailed,
  }) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      debugPrint('Rewarded ad not loaded, granting reward anyway');
      await Future.value(onRewarded());
      return false;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('Rewarded ad showed full screen content');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded ad dismissed');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        notifyListeners();
        // Preload next ad
        loadRewardedAd();
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        notifyListeners();
        // Grant reward anyway on failure
        onRewarded();
        onAdFailed?.call();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        onRewarded();
      },
    );

    return true;
  }

  /// Dispose of the ad
  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}
