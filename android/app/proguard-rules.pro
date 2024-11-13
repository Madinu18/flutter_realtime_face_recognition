-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.** { *; }

-dontwarn org.tensorflow.lite.**
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.support.**

-keepclassmembers class * {
    @org.tensorflow.lite.annotations.** *;
}

-keep class * extends org.tensorflow.lite.Interpreter { *; }