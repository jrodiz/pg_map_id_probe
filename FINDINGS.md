# R8 `pg_map_id` / `r8_map_id` — mapping-header version sweep

**TL;DR:** No R8 version emits an `r8_map_id` mapping-file header field. `pg_map_id` is present in every version, but its **value format changed at R8/AGP 8.12** — from a 7-character prefix to the full 64-character hash. The "r8-map-id" people refer to is the hyphenated `r8-map-id-<hash>` token R8 embeds in obfuscated **stack frames** (new in AGP 8.12), not a field in `mapping.txt`. Verified two independent ways: running R8 standalone across 8 versions, and real AGP `assembleRelease` builds across 5 versions (8.1.4 → 9.2.1).

## Context

Investigating the Crashlytics Gradle plugin change for issue #6770 (use R8's stable map id on AGP 8.12+ instead of a freshly generated id). Open question: does the R8 mapping file carry an `r8_map_id` field alongside `pg_map_id`, and from which version?

## Method (standalone R8 sweep)

R8 was run **standalone** (not through AGP) on a trivial input across 8 stable R8 releases pulled from Google's Maven (`dl.google.com/android/maven2/com/android/tools/r8`). For each version:

```
java -cp r8-<ver>.jar com.android.tools.r8.R8 \
  --release --min-api 21 \
  --lib <sdk>/platforms/android-34/android.jar \
  --pg-conf keep.pro \
  --pg-map-output mapping-<ver>.txt \
  --output out-<ver>.jar input.jar
```

- **Input:** a trivial 2-class Java program (one kept entry point + one helper class R8 obfuscates).
- **keep.pro:** `-keep class Hello { public static void main(java.lang.String[]); }`, `-dontwarn **`, `-keepattributes SourceFile,LineNumberTable`.
- The `# …` header comments of each generated `mapping.txt` were inspected.
- Environment: macOS, OpenJDK 24. R8 version tracks AGP version (e.g. R8 9.1.31 ships with AGP 9.1).

## Results

| R8 version (≈ AGP) | `pg_map_id` | length | `r8_map_id` present? |
|---|---|---|---|
| 8.1.72  | `c17d44e` | 7 (prefix) | no |
| 8.7.18  | `c17d44e` | 7 (prefix) | no |
| 8.11.32 | `c17d44e` | 7 (prefix) | no |
| **8.12.14** | `c17d44e1f925…b83a66b9` | **64 (full hash)** | no |
| 8.12.30 | `c17d44e1f925…b83a66b9` | 64 (full hash) | no |
| 8.13.19 | `c17d44e1f925…b83a66b9` | 64 (full hash) | no |
| 9.0.32  | `c17d44e1f925…b83a66b9` | 64 (full hash) | no |
| 9.1.31  | `c17d44e1f925…b83a66b9` | 64 (full hash) | no |

(The 7-char prefix `c17d44e` is literally the first 7 characters of the full hash `c17d44e1f925635aeaff07986054b59425f229529b408f5dcf9170a0b83a66b9`.)

**Header fields R8 writes in every version:** `compiler`, `compiler_version`, `compiler_hash`, `min_api`, the mapping-format version line (`# {"id":"com.android.tools.r8.mapping","version":"…"}`), `pg_map_id`, `pg_map_hash`.

## Cross-check: through real Android Gradle Plugin builds

To confirm the standalone results reflect real AGP-driven builds, a minimal Android app (one kept entry class + one obfuscated helper, `isMinifyEnabled = true`, default optimize rules) was built with `:assembleRelease` across five AGP versions on JDK 17, each AGP paired with its required Gradle version, and the resulting `app/build/outputs/mapping/release/mapping.txt` header inspected:

| AGP | bundled R8 | compileSdk | `pg_map_id` length | `r8_map_id` present? |
|---|---|---|---|---|
| 8.1.4  | 8.1.68 | 34 | 7 (prefix) | no |
| 8.7.3  | 8.7.18 | 34 | 7 (prefix) | no |
| 8.13.0 | 8.13.6 | 35 | 64 (full hash) | no |
| 9.1.0  | 9.1.31 | 36 | 64 (full hash) | no |
| 9.2.1  | 9.2.14 | 36 | 64 (full hash) | no |

The real-AGP results match the standalone sweep exactly: no `r8_map_id` field in any version, and `pg_map_id` switches from a 7-character prefix to the full 64-character hash across the 8.12 boundary (AGP 8.7.3 prefix → AGP 8.13.0 full hash). AGP 9.1.0 bundles R8 9.1.31 — the same `compiler_version` observed in a real AGP 9.1 mapping header — and produced the full-hash `pg_map_id` with no `r8_map_id`.

## Findings

1. **`r8_map_id` does not exist** as a mapping-file header field in any R8 version from 8.1 through 9.1.
2. **`pg_map_id`'s format changed at exactly 8.12:** 7-character prefix (≤ 8.11) → full 64-character SHA-256 hash (≥ 8.12, confirmed at the earliest 8.12 release, 8.12.14). At 8.12+, `pg_map_id` equals the `pg_map_hash` value.
3. This matches the AGP 9.0 release notes, which state the embedded id "uses the full map hash (not a 7-character prefix as previously used)" and that the change "started in AGP 8.12.0."
4. The **"r8-map-id"** (hyphenated) is the source-file attribute R8 embeds in obfuscated stack frames as `r8-map-id-<MAP_ID>` (new in AGP 8.12, used by Android Studio Logcat auto-retrace in AGP 9.0). Its `<MAP_ID>` is the same full hash carried by `pg_map_id` at 8.12+. It is **not** a `mapping.txt` header field.

## Source corroboration

R8's mapping-header writer, `ProguardMapMarkerInfo` (R8 `main` branch), emits only `pg_map_id` and `pg_map_hash` — no `r8_map_id`.

## Implication for the Crashlytics Gradle plugin (#6770)

- **Gating the new path at AGP 8.12 is correct** — it is exactly where `pg_map_id` becomes the full hash that matches the `r8-map-id` embedded in stack frames, so a crash deobfuscates against the uploaded mapping. Below 8.12, `pg_map_id` is only a 7-char prefix and there is no embedded id, so the new path correctly does not apply.
- The plugin extracts the map id from `mapping.txt` and uploads with it. Because `pg_map_id` is the only id field R8 actually writes, that is what is used at 8.12+. Parsing for `r8_map_id` is retained **defensively** (it is harmless and future-proofs against a hypothetical future field), preferring it when present and falling back to `pg_map_id`.
