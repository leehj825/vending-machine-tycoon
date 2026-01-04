import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config.dart';
import '../utils/screen_utils.dart';

/// Banner ad widget for displaying AdMob banner ads
class AdMobBanner extends StatefulWidget {
  /// Ad unit ID - automatically selects test ID for APK builds, real ID for bundle releases
  /// Override this parameter if you need to manually specify an ad unit ID
  final String? adUnitId;
  
  const AdMobBanner({
    super.key,
    this.adUnitId,
  });
  
  /// Get the appropriate ad unit ID based on build type
  /// - Bundle builds (with BUILD_TYPE=bundle): Use real ad unit ID
  /// - APK builds (debug or release): Use test ad unit ID
  /// - Can be overridden via AppConfig.forceTestAds or by passing adUnitId parameter
  String get effectiveAdUnitId {
    if (adUnitId != null) {
      return adUnitId!;
    }
    // If forceTestAds is enabled, always use test ads
    if (AppConfig.forceTestAds) {
      return AppConfig.admobBannerTestId;
    }
    // Check if BUILD_TYPE was set to 'bundle' via --dart-define
    // This allows distinguishing bundle builds from APK builds
    if (AppConfig.buildType == 'bundle' && kReleaseMode) {
      return AppConfig.admobBannerRealId;
    }
    // Default: Use test ads for all APK builds (both debug and release)
    // Only bundle builds with BUILD_TYPE=bundle will use real ads
    return AppConfig.admobBannerTestId;
  }

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Only load ads on Android and iOS
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _loadBannerAd();
      // Set a timeout to stop showing loading indicator after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && !_isAdLoaded && !_hasError) {
          setState(() {
            _hasError = true;
          });
          debugPrint('Banner ad loading timeout - hiding banner');
        }
      });
    } else {
      // On other platforms (macOS, Windows, Linux, Web), don't try to load ads
      _hasError = true;
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.effectiveAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _hasError = false;
            });
          }
          debugPrint('Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed to load: ${error.code} - ${error.message}');

          // Fix: Only hide the banner if we haven't loaded one yet (initial load failure).
          // If _isAdLoaded is true, it means a refresh failed, but the old ad is still there.
          if (!_isAdLoaded) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _hasError = true;
              });
            }
          } else {
            // It was a refresh failure. Do NOT dispose.
            // The SDK will try again automatically or keep the old ad visible.
            debugPrint('Refresh failed, keeping existing ad visible.');
          }
        },
        onAdOpened: (_) {
          debugPrint('Banner ad opened');
        },
        onAdClosed: (_) {
          debugPrint('Banner ad closed');
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide banner if there's an error or if it hasn't loaded after timeout
    if (_hasError && !_isAdLoaded) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _bannerAd == null) {
      // Show a placeholder with fixed height while loading (max 10 seconds)
      return Container(
        width: double.infinity,
        height: AdSize.banner.height.toDouble(),
        color: Colors.grey[200],
        child: Center(
          child: SizedBox(
            width: ScreenUtils.relativeSize(context, AppConfig.iconSizeSmallFactor),
            height: ScreenUtils.relativeSize(context, AppConfig.iconSizeSmallFactor),
            child: CircularProgressIndicator(
              strokeWidth: ScreenUtils.relativeSize(context, AppConfig.borderWidthFactorSmall),
            ),
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      color: Colors.white,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

