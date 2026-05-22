# Ripple ProGuard Rules — Production Release
#
# Keep Flutter + Dart entry points
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Daily.co / InAppWebView
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Encryption (encrypt package)
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# ML Kit (Face Detection for Telepathy)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Camera
-keep class io.flutter.plugins.camera.** { *; }

# Sensors / Battery / Geolocator (Chronos)
-keep class dev.fluttercommunity.plus.** { *; }
-dontwarn dev.fluttercommunity.plus.**

# Keep Parcelable/Serializable
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable { *; }

# Remove debug logging in release
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
}
