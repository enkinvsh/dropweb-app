# =============================================================================
#  dropweb-app ProGuard / R8 rules
#  Goal: keep only the surfaces that are reflectively accessed (serialization,
#  JNI, MethodChannels, Quick Settings tile). Aggressively obfuscate / shrink
#  everything else so the release APK doesn't trivially reveal internal APIs.
# =============================================================================

# --- Keep JSON/serialization models (reflection via json_serializable) ------
-keep class app.dropweb.models.** { *; }
-keepclassmembers class app.dropweb.models.** { *; }

# --- Keep public service surfaces (bound by Android components / intents) ---
-keep class app.dropweb.MainActivity { *; }
-keep class app.dropweb.TempActivity { *; }
-keep class app.dropweb.FilesProvider { *; }
-keep class app.dropweb.DropwebApplication { *; }
-keep class app.dropweb.services.** { *; }
-keep class app.dropweb.widgets.** { *; }

# --- JNI surface (Go mihomo core invoked via libclash.so) -------------------
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Enums (valueOf / values() invoked by json_serializable et al) ----------
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- Parcelable contract ---------------------------------------------------
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# --- Serializable contract -------------------------------------------------
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# --- Flutter embedding -----------------------------------------------------
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.view.** { *; }

# --- Kotlin metadata (shrinker keeps metadata for @Keep / reflection) ------
-keep class kotlin.Metadata { *; }
-keepattributes *Annotation*, InnerClasses, EnclosingMethod, Signature, Exceptions

# --- Keep source file / line numbers in stack traces (maps uploaded to Play)
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile

# --- Strip verbose logging in release ---------------------------------------
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}

# --- Suppress common safe warnings from OkHttp/Conscrypt/etc ---------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
