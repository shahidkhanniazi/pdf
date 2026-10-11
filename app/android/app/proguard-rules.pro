# Keep rules for the release build's code shrinker (R8).

# WorkManager (pulled in by Google Mobile Ads) creates its Room database by
# reflection. Without these rules R8 removes the generated constructor and the
# app crashes at start-up: "Failed to create an instance of WorkDatabase".
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }

# flutter_local_notifications stores notification details with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
