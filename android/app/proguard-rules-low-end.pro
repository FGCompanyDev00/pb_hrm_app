 # ProGuard rules for very low-end Android devices
# These rules are more aggressive than standard rules to maximize performance

# Basic Flutter rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Preserve main application class
-keep class com.phongsavanh.pb_hrsystem.MainActivity { *; }

# Controlled obfuscation for low-end devices (less aggressive to prevent APK corruption)
-dontpreverify
-allowaccessmodification
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*

# Remove debugging information
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Remove debug print statements
-assumenosideeffects class java.io.PrintStream {
    public void println(%);
    public void println(**);
    public void print(%);
    public void print(**);
}

# Balanced optimization (prevent APK corruption)
-optimizationpasses 5

# Kotlin optimizations
-dontwarn kotlin.**
-dontwarn kotlinx.**
-keep class kotlin.** { *; }

# AndroidX optimizations
-keep class androidx.** { *; }
-dontwarn androidx.**

# Firebase optimizations for low-end devices
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Networking optimizations
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# Image loading optimizations
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# Remove unnecessary features for very low-end devices
-assumenosideeffects class ** {
    void setAnimation*(...);
    void startAnimation*(...);
    android.view.animation.Animation getAnimation*();
}

# Optimize reflection usage
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Preserve enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Serialization optimizations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Remove unnecessary annotations
-assumenosideeffects class java.lang.annotation.Annotation {
    *;
}

# Controlled class optimization
-overloadaggressively

# Remove parameter names for smaller APK
-keepparameternames

# Additional optimizations for very low-end devices
-keepattributes LineNumberTable,SourceFile

# Remove unnecessary constructors
-assumenosideeffects class java.lang.StringBuilder {
    public java.lang.StringBuilder();
    public java.lang.StringBuilder(int);
    public java.lang.StringBuilder(java.lang.String);
    public java.lang.StringBuilder append(java.lang.Object);
    public java.lang.StringBuilder append(java.lang.String);
    public java.lang.StringBuilder append(java.lang.StringBuffer);
    public java.lang.StringBuilder append(char[]);
    public java.lang.StringBuilder append(char[], int, int);
    public java.lang.StringBuilder append(boolean);
    public java.lang.StringBuilder append(char);
    public java.lang.StringBuilder append(int);
    public java.lang.StringBuilder append(long);
    public java.lang.StringBuilder append(float);
    public java.lang.StringBuilder append(double);
    public java.lang.String toString();
}

# Optimize collections
-assumenosideeffects class java.util.* {
    <init>(...);
}

# Remove expensive operations for very low-end devices
-assumenosideeffects class ** {
    void setLayerType(...);
    void setElevation(...);
    void setTranslationZ(...);
}

# Final optimizations
-dontnote
-dontwarn
-ignorewarnings