# ==============================================================================
# Flutter Core, Embedding & Plugins
# ==============================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepclassmembers class io.flutter.plugins.** { *; }

# Preserve native JNI callback methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve Flutter platform channels and message codecs
-keep class * extends io.flutter.plugin.common.StandardMessageCodec { *; }
-keep class * implements io.flutter.plugin.common.MessageCodec { *; }
-keepclassmembers class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler {
    public <methods>;
}

# ==============================================================================
# Shared Preferences & Pigeon JNI Registrar
# ==============================================================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }

# ==============================================================================
# Kotlin Standard Library, kotlin.Result & Metadata (Required by Pigeon JNI)
# ==============================================================================
-keep class kotlin.** { *; }
-keepclassmembers class kotlin.** { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$* { *; }
-keep class kotlin.Metadata { *; }

# ==============================================================================
# Kotlin Coroutines
# ==============================================================================
-keep class kotlinx.coroutines.** { *; }
-keepclassmembers class kotlinx.coroutines.** { *; }

-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ==============================================================================
# Additional Installed Plugins & Persistence
# ==============================================================================
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class net.nfet.printing.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Hive & Data serialization preservation
-keep class hive.** { *; }
-keep class * extends hive.TypeAdapter { *; }

# Suppress benign warnings from optional build-time dependencies
-dontwarn io.flutter.embedding.**
-dontwarn net.nfet.printing.**
-dontwarn com.mr.flutter.plugin.filepicker.**
