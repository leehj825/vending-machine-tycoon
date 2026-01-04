import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config.dart';

/// Manager for handling rewarded video ads
class RewardedAdManager {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isReady = false;

  /// Check if ad is loaded and ready to show
  bool get isReady => _isReady && _rewardedAd != null;

  /// Get the appropriate ad unit ID based on build type
  /// - Bundle builds (with BUILD_TYPE=bundle): Use real ad unit ID
  /// - APK builds (debug or release): Use test ad unit ID
  /// - Can be overridden via AppConfig.forceTestAds
  String get _adUnitId {
    if (kIsWeb) {
      // Web doesn't support rewarded ads, return test ID as fallback
      return AppConfig.admobRewardedTestId;
    }
    
    // If forceTestAds is enabled, always use test ads
    if (AppConfig.forceTestAds) {
      return AppConfig.admobRewardedTestId;
    }
    
    // Check if BUILD_TYPE was set to 'bundle' via --dart-define
    // This allows distinguishing bundle builds from APK builds
    if (AppConfig.buildType == 'bundle' && kReleaseMode) {
      return AppConfig.admobRewardedRealId;
    }
    
    // Default: Use test ads for all APK builds (both debug and release)
    // Only bundle builds with BUILD_TYPE=bundle will use real ads
    return AppConfig.admobRewardedTestId;
  }

  RewardedAdManager() {
    loadAd();
  }

  /// Load a rewarded ad
  void loadAd() {
    if (_isLoading || _isReady) return;

    _isLoading = true;
    _isReady = false;

    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('✅ Rewarded ad loaded');
          _rewardedAd = ad;
          _isLoading = false;
          _isReady = true;
          
          // Set up full screen content callbacks
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('Rewarded ad dismissed');
              ad.dispose();
              _rewardedAd = null;
              _isReady = false;
              // Reload ad after dismissal
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print('Rewarded ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
              _isReady = false;
              // Reload ad after failure
              loadAd();
            },
            onAdShowedFullScreenContent: (RewardedAd ad) {
              print('Rewarded ad showed');
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ Rewarded ad failed to load: $error');
          _isLoading = false;
          _isReady = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Show the rewarded ad
  /// [onReward] callback is called when user earns the reward
  void showAd({required Function() onReward}) {
    if (!isReady || _rewardedAd == null) {
      print('⚠️ Rewarded ad not ready');
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('🎉 User earned reward: ${reward.amount} ${reward.type}');
        onReward();
      },
    );
  }

  /// Dispose of the ad manager
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isReady = false;
    _isLoading = false;
  }
}

