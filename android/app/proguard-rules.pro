# Preserve Kotlin metadata and generated serializers used by kotlinx.serialization.
-keepattributes *Annotation*,InnerClasses,EnclosingMethod,Signature
-keepclassmembers,allowoptimization class ** {
    @kotlinx.serialization.SerialName <fields>;
}
-keepclassmembers class ** {
    *** Companion;
}
-keepclassmembers class **$Companion {
    kotlinx.serialization.KSerializer serializer(...);
}
-if @kotlinx.serialization.Serializable class *
-keep class <1>
-if @kotlinx.serialization.Serializable class **$*
-keep class <1>

# Keep Dagger/Hilt generated entry points referenced reflectively by the Android runtime.
-keep class dagger.hilt.** { *; }
-keep class hilt_aggregated_deps.** { *; }
-keep class * extends dagger.hilt.internal.GeneratedComponent { *; }
-keep class * extends dagger.hilt.android.internal.lifecycle.HiltViewModelFactory { *; }
