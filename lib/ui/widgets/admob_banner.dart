import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Banner ad widget for displaying AdMob banner ads
class AdMobBanner extends StatefulWidget {
  /// Ad unit ID - use test ID for development
  /// Replace with your actual ad unit ID for production
  final String adUnitId;
  
  const AdMobBanner({
    super.key,
    // Test ad unit ID for banner ads
    this.adUnitId = 'ca-app-pub-4400173019354346/5798507534',
  });

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _errorMessage = null;
            });
          }
          debugPrint('Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          // Dispose the ad if it fails to load
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _errorMessage = error.message;
            });
          }
          debugPrint('Banner ad failed to load: ${error.code} - ${error.message}');
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
    // Show error message in debug mode
    if (_errorMessage != null) {
      debugPrint('AdMob Banner Error: $_errorMessage');
    }

    if (!_isAdLoaded || _bannerAd == null) {
      // Show a placeholder with fixed height while loading
      return Container(
        width: double.infinity,
        height: AdSize.banner.height.toDouble(),
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
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

