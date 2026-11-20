# Extra R8 rules for release builds. Flutter's Gradle plugin adds this file
# automatically when it exists (alongside its own flutter_proguard_rules.pro).

# Room creates its generated database classes by reflection
# (Class.forName("<Database>_Impl").newInstance()).
#
# ML Kit's pose-detection pulls in androidx.work 2.7.0, which uses Room 2.2.5.
# That Room version only ships the consumer rule
#     -keep class * extends androidx.room.RoomDatabase
# which relied on the default constructor being kept implicitly. R8 full mode
# (the default since AGP 8, so also in this project) no longer does that, so the
# release build removed WorkDatabase_Impl.<init>() and the app crashed at startup
# in androidx.startup.InitializationProvider with
#     "Failed to create an instance of androidx.work.impl.WorkDatabase".
# Keep the no-arg constructor explicitly.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
