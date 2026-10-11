/// App-wide settings. Change these before publishing to the Play Store.
class AppConfig {
  AppConfig._();

  static const String appName = 'Something Historic';

  /// The WordPress site the app reads from. The site needs the small
  /// "Something Historic App API" plugin (wordpress/sh-app-api) installed.
  static const String siteUrl = 'https://somethinghistoric.com';

  static String get versionUrl => '$siteUrl/wp-json/sh-app/v1/version';
  static String bundleUrl(String lang) =>
      '$siteUrl/wp-json/sh-app/v1/bundle?lang=$lang';

  /// The app checks the site for new content at most this often, quietly in
  /// the background. Users can also pull down on the home screen to check.
  static const Duration updateCheckInterval = Duration(hours: 6);

  static const List<String> languages = ['en', 'ur'];

  // ---------------------------------------------------------------- AdMob
  // These are Google's official TEST ids. They always show test ads and are
  // safe to use while developing. Replace them with your own ids from
  // https://admob.google.com before publishing, and also replace the
  // APPLICATION_ID in android/app/src/main/AndroidManifest.xml.
  static const bool adsEnabled = true;
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/9214589741';
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Show a full-screen ad after this many opened stories/places, at most
  /// once every [interstitialCooldown].
  static const int interstitialEvery = 4;
  static const Duration interstitialCooldown = Duration(minutes: 3);
}
