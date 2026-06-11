plugins { id("com.android.application") version "9.2.1" }
android {
  namespace = "com.example.agpprobe"
  compileSdk = 36
  defaultConfig { minSdk = 24 }
  buildTypes { release { isMinifyEnabled = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro") } }
}
