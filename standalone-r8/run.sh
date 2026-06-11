#!/usr/bin/env bash
# Sweep R8 mapping-file headers across versions, running R8 standalone (no AGP).
# Requires: java, javac, curl; ANDROID_HOME pointing at an Android SDK (for android.jar).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${ANDROID_HOME:?Set ANDROID_HOME to your Android SDK path}"
AJ="$ANDROID_HOME/platforms/android-34/android.jar"
rm -rf "$HERE/classes" "$HERE/input.jar"; mkdir -p "$HERE/mappings"
javac --release 17 -d "$HERE/classes" "$HERE/Hello.java"
( cd "$HERE/classes" && jar cf "$HERE/input.jar" . )
for ver in 8.1.72 8.7.18 8.11.32 8.12.14 8.12.30 8.13.19 9.0.32 9.1.31; do
  jar="$HERE/r8-$ver.jar"
  [ -f "$jar" ] || curl -fsSL -o "$jar" "https://dl.google.com/android/maven2/com/android/tools/r8/$ver/r8-$ver.jar"
  java -cp "$jar" com.android.tools.r8.R8 --release --min-api 21 --lib "$AJ" \
    --pg-conf "$HERE/keep.pro" --pg-map-output "$HERE/mappings/mapping-$ver.txt" \
    --output "$HERE/out-$ver.jar" "$HERE/input.jar"
  echo "=== R8 $ver ==="
  grep -iE "^#.*(compiler_version|map_id|map_hash)" "$HERE/mappings/mapping-$ver.txt"
done
