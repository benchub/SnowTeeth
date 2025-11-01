# Add project specific ProGuard rules here.

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep data classes used for GPS/Location (serialization)
-keep class com.snowteeth.app.model.** { *; }
-keep class com.snowteeth.app.util.LocationData { *; }
-keep class com.snowteeth.app.util.TrackStats { *; }

# Keep LocationTrackingService (Android Service)
-keep public class * extends android.app.Service
-keep class com.snowteeth.app.service.LocationTrackingService { *; }

# Keep all Activities
-keep public class * extends android.app.Activity
-keep class com.snowteeth.app.MainActivity { *; }
-keep class com.snowteeth.app.ConfigurationActivity { *; }
-keep class com.snowteeth.app.VisualizationActivity { *; }
-keep class com.snowteeth.app.StatsActivity { *; }

# Keep custom views
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
}
-keep class com.snowteeth.app.view.** { *; }

# Keep View Binding classes
-keep class com.snowteeth.app.databinding.** { *; }

# Android Location Services
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Material Design
-keep class com.google.android.material.** { *; }
-dontwarn com.google.android.material.**

# Preserve line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
