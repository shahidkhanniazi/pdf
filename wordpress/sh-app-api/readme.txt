=== Something Historic App API ===
Requires at least: 6.0
Requires PHP: 7.4
Stable tag: 1.0.0

Gives the Something Historic mobile app everything it shows in one download.

== Description ==

Adds two read-only REST endpoints:

* /wp-json/sh-app/v1/version   Current content version and languages.
* /wp-json/sh-app/v1/bundle?lang=en   All published episodes, empires, series,
  blog posts, museums, ancient cities and castles for one language, with their
  images, meta fields and Polylang translation links.

The bundle is cached per language and rebuilt only after content changes, so
it is cheap to serve. The app downloads it once and then works offline.

Works with the sh-stories, sh-museums, sh-cities and sh-castles plugins and
with Polylang. A section is simply empty when its plugin is not active.

== Installation ==

1. Zip the sh-app-api folder (or use sh-app-api.zip).
2. WordPress admin > Plugins > Add New > Upload Plugin, choose the zip, Install, Activate.
3. Visit https://your-site/wp-json/sh-app/v1/version to check it answers.
