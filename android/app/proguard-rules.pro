# media_kit
-keep class com.arthenica.** { *; }
-dontwarn com.arthenica.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep media_kit Flutter plugin
-keep class com.soonyeong.kim.** { *; }
