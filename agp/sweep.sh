#!/usr/bin/env bash
# Build a minimal app with several AGP versions and inspect the R8 mapping header.
# Requires: a JDK 17 (export JAVA_HOME), ANDROID_HOME, and internet (downloads AGP + Gradle).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${JAVA_HOME:?Set JAVA_HOME to a JDK 17}"
: "${ANDROID_HOME:?Set ANDROID_HOME to your Android SDK}"
RES="$HERE/RESULTS.md"; : > "$RES"
echo "| AGP | bundled R8 | Gradle | compileSdk | pg_map_id len | r8_map_id |" >> "$RES"
echo "|---|---|---|---|---|---|" >> "$RES"
# AGP version, the Gradle version it requires, compileSdk
while read AGP GV CS; do
  [ -z "$AGP" ] && continue
  rm -rf "$HERE/build"
  cat > "$HERE/gradle/wrapper/gradle-wrapper.properties" <<PROPS
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-${GV}-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
PROPS
  cat > "$HERE/build.gradle.kts" <<BUILD
plugins { id("com.android.application") version "${AGP}" }
android {
  namespace = "com.example.agpprobe"
  compileSdk = ${CS}
  defaultConfig { minSdk = 24 }
  buildTypes { release { isMinifyEnabled = true
    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro") } }
}
BUILD
  echo "########## AGP $AGP (Gradle $GV, compileSdk $CS) ##########"
  ( cd "$HERE" && ./gradlew --no-daemon :assembleRelease < /dev/null ) > "$HERE/log-$AGP.txt" 2>&1
  MAP="$HERE/build/outputs/mapping/release/mapping.txt"
  if [ -f "$MAP" ]; then
    CV=$(grep -iE "^#.*compiler_version" "$MAP" | sed 's/.*: *//')
    ID=$(grep -iE "^#.*pg_map_id" "$MAP" | head -1 | sed 's/.*: *//')
    R8=$(grep -qi "r8_map_id" "$MAP" && echo YES || echo no)
    echo "| $AGP | $CV | $GV | $CS | ${#ID} | $R8 |" >> "$RES"
    grep -iE "^#.*(map_id|map_hash)" "$MAP"
  else
    echo "  BUILD FAILED (see log-$AGP.txt)"
    echo "| $AGP | BUILD FAILED | $GV | $CS | - | - |" >> "$RES"
  fi
done <<MATRIX
8.1.4  8.5     34
8.7.3  8.13    34
8.12.0 8.13    35
8.13.0 8.13    35
9.1.0  9.3.1   36
9.2.1  9.4.1   36
MATRIX
echo "===== DONE ====="; cat "$RES"
