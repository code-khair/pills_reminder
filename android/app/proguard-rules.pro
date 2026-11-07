# flutter_local_notifications menyimpan jadwal notifikasi memakai Gson (refleksi
# generik). Tanpa aturan ini, R8 pada build release membuang informasi tipe
# sehingga penjadwalan gagal ("Missing type parameter") dan notifikasi tidak
# pernah muncul di HP yang sudah menginstal APK release.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
