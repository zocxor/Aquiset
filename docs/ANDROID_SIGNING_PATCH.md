# Android signing patch — automatic in GitHub Actions

File: `apps/mobile_flutter/android/app/build.gradle.kts`
(does not exist in the v5 zip — `flutter create` generates it, in CI.)

You do NOT need to edit it by hand. The release workflow runs:

```bash
flutter create --platforms=android --org com.aquiset .
python3 ../../tools/patch_android.py android/app/build.gradle.kts
```

`tools/patch_android.py` does exactly this, and fails loudly if a
pattern is missing:

1. At the top, load `key.properties` into `keystoreProperties`.
2. Force `namespace = "com.aquiset.app"`,
   `applicationId = "com.aquiset.app"`, `minSdk = 28`,
   `compileSdk = 36`, `targetSdk = 36`.
3. Inside `android { ... }`, add `signingConfigs { create("release") {
   ... } }` from `key.properties`, and set
   `buildTypes.release.signingConfig =
   signingConfigs.getByName("release")` (replacing the template's debug
   signing).
4. Add the Kotlin Compose plugin and Glance deps
   (`glance-appwidget`, `glance-material3`, `kotlinx-coroutines-android`)
   — needed by `TodayWidget.kt`, which imports `androidx.glance.*`.

If `key.properties` is missing, the build fails on the signing block —
that is intentional: it proves no hard-coded password is in the repo.
In CI, `key.properties` is created from Secrets just before this step.

Do NOT edit any file under `lib/` for signing. Theme is untouched.
