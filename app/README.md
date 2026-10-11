# Something Historic: Flutter app

Stories (empires, series, episodes), blog posts, museums, ancient cities and
castles from [somethinghistoric.com](https://somethinghistoric.com), in English
and Urdu, readable offline.

## Aasaan alfaaz mein (Roman Urdu)

1. **Website par plugin lagayein:** `wordpress/sh-app-api` folder ko zip kar ke
   WordPress > Plugins > Add New > Upload se install aur Activate karein.
   Is se app website ka sara data ek dafa download kar sakti hai.
2. **APK:** GitHub par har push ke baad "Build Android APK" khud chalta hai aur
   Releases page par `something-historic.apk` daal deta hai. Woh phone par
   download kar ke install karein.
3. **Ads:** abhi Google ke *test* ads hain. Asli AdMob IDs milne par
   `lib/config.dart` aur `android/app/src/main/AndroidManifest.xml` mein badal dein.
4. **Pehli dafa:** app website se poori library (English + Urdu) download kar ke
   phone mein save kar leti hai. Us ke baad internet ke baghair chalti hai.
   Internet ho to har 6 ghante baad chupke se naya mawad check karti hai, aur
   nayi episode aaye to notification deti hai.

## Features

- Animated splash, 4-page onboarding (language and theme choice)
- Dashboard like the site's homepage: hero episode, continue reading, latest
  episodes, series rows, empires, museums, cities, castles, blog
- Stories: empires, series (Episode X of Y, ongoing/completed), episode reader
  with progress bar, resume position, prev/next, text size, bookmarks, share
- Museums (filter by type and country), ancient cities and castles (filter by
  region): facts, must-see list, timeline, map and website links
- Search across everything, with kind filters; works for Urdu text too
- Light, dark or same-as-phone theme; English and Urdu (full right-to-left,
  Noto Nastaliq Urdu); any page can switch to its translation
- Bell icon in the app bar with in-app notices, plus phone notifications for
  new episodes (local notifications, no Firebase needed)
- AdMob adaptive banner above the bottom bar and an occasional interstitial
  (every 4th opened item, at most once per 3 minutes)
- One-time download, then fully offline. Images are cached as they are viewed.
  If the site can't be reached on first launch, a built-in library (the
  plugins' sample content) is used until it can.

## How data loading works

```
first launch ──► GET /wp-json/sh-app/v1/bundle?lang=en and ?lang=ur
                 └─ saved as files on the phone (app support folder)
every launch ──► read the saved files (no network needed)
every 6 hours ─► GET /wp-json/sh-app/v1/version; download again only if it changed
                 └─ new episodes/posts → bell notice + phone notification
offline/first ─► assets/seed/en.json, assets/seed/ur.json (built-in library)
```

The `sh-app-api` WordPress plugin (in `../wordpress/sh-app-api`) provides both
endpoints. It reads the sh-stories, sh-museums, sh-cities and sh-castles
plugins and Polylang, caches the result, and bumps the version whenever
content is saved.

## Project layout

```
lib/
  config.dart              site URL, AdMob ids, update interval
  main.dart                start-up, theme, locale
  router.dart              opens any item (and shows interstitials)
  theme.dart               colours and fonts from the website theme
  l10n/strings.dart        every English and Urdu label
  data/models.dart         Bundle, Entry (episode/post/museum/city/castle), Term
  data/repository.dart     load saved/built-in library, download and save
  state/app_state.dart     settings, library, bookmarks, history, notices
  services/ads.dart        AdMob banner and interstitial
  services/notifications.dart  phone notifications
  widgets/                 cards, rows, painted cover art
  screens/                 splash, onboarding, dashboard, stories, explore,
                           collection, reader, place, blog, search,
                           notifications, more/settings
assets/seed/               built-in library (generated, see below)
assets/fonts/              Lora, Playfair Display, Inter, Noto Nastaliq Urdu (OFL)
tool/build_seed.php        rebuilds assets/seed from the plugins' sample content
test/                      library parsing tests
```

## Build it yourself

Needs Flutter 3.47 (stable) and Android Studio's SDK.

```
flutter pub get
flutter test
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
```

The release build is signed with the debug key so it installs directly. For
the Play Store, create an upload key and set `signingConfig` in
`android/app/build.gradle.kts`, and replace the test AdMob ids.

Regenerate icons or splash after changing `assets/images/`:

```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Rebuild the built-in library from the plugins' sample content:

```
php tool/build_seed.php <folder with sh-stories, sh-museums, sh-cities, sh-castles> assets/seed
```
