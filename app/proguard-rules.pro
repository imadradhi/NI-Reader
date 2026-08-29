# Proguard rules for Iraqi National ID Reader
-keep class org.jmrtd.** { *; }
-keep class net.sf.scuba.** { *; }
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.jmrtd.**
-dontwarn net.sf.scuba.**
