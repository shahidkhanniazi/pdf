import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';

bool get _adsSupported =>
    AppConfig.adsEnabled &&
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// AdMob setup: a banner at the bottom of the main screens and an
/// occasional full-screen ad between stories.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _started = false;
  InterstitialAd? _interstitial;

  Future<void> init() async {
    if (!_adsSupported || _started) return;
    try {
      await MobileAds.instance.initialize();
      _started = true;
      _loadInterstitial();
    } catch (e) {
      debugPrint('Ads unavailable: $e');
    }
  }

  void _loadInterstitial() {
    if (!_started) return;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Shows the full-screen ad if one is ready, then loads the next one.
  void showInterstitial() {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }
}

/// An adaptive banner ad that takes no space until an ad has loaded.
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width.truncate();
    if (_adsSupported && width != _width) {
      _width = width;
      _load(width);
    }
  }

  Future<void> _load(int width) async {
    final orientation = MediaQuery.orientationOf(context);
    AdSize? size;
    try {
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
          orientation, width);
    } catch (_) {}
    if (!mounted) return;
    _ad?.dispose();
    _loaded = false;
    final ad = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size: size ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    setState(() => _ad = ad);
    try {
      await ad.load();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
