# pg_map_id / r8_map_id probe

Empirical check of what R8 actually writes into its mapping-file header across versions —
specifically whether a `r8_map_id` field exists alongside `pg_map_id`, and how `pg_map_id` changes
across the AGP 8.12 boundary.

**Result:** no R8 version emits an `r8_map_id` mapping-file field. `pg_map_id` is the only id field;
its value goes from a **7-character prefix** (≤ 8.11) to the **full 64-character hash** (≥ 8.12).
The "r8-map-id" people refer to is the hyphenated `r8-map-id-<hash>` token R8 embeds in obfuscated
**stack frames** (new in AGP 8.12), not a `mapping.txt` field. Full write-up in [`FINDINGS.md`](FINDINGS.md).

## Layout

- `standalone-r8/` — runs the R8 compiler directly across 8 versions (`run.sh`). The captured
  mapping headers are in `standalone-r8/mappings/`.
- `agp/` — a minimal Android app built through several real AGP versions (`sweep.sh`), inspecting
  `app/build/outputs/mapping/release/mapping.txt`. Combined table in `agp/RESULTS.md`.

## Reproduce

Standalone R8 sweep:

```bash
export ANDROID_HOME=/path/to/Android/sdk
./standalone-r8/run.sh
```

Through-AGP sweep (needs a JDK 17):

```bash
export JAVA_HOME=/path/to/jdk-17
export ANDROID_HOME=/path/to/Android/sdk
./agp/sweep.sh
```

Both scripts download the compiler/Gradle/AGP versions they need.
