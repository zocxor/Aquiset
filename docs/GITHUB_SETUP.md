# GitHub setup — AQUISET v5 (Liquid Glass)

Theme is NOT changed in this package. Only added: `.gitignore` files,
`key.properties.example`, `tools/patch_android.py`,
`.github/workflows/release.yml` + `ci.yml`, and these docs.
No file under `apps/mobile_flutter/lib/` was edited.

## What v5 is

- Source-only Flutter project. `lib/` is complete, but the platform shells
  are partial: Android has `src/main/` only (no `build.gradle.kts`),
  iOS has Swift files only (no `.xcodeproj`). That is by design in the
  Claude delivery — see README.md.
- Identity: package `aquiset`, org `com.aquiset`, Android app id
  `com.aquiset.app`, version `0.1.0+1`, Flutter `>=3.29`, Dart `>=3.7`,
  Android compile/target SDK 36, minSdk 28, iOS 17+ (AlarmKit on 26+).
- This is a NEW structure, NOT the v0.1.1 Rise & Shine drop-in.
  Do NOT unzip it over `C:\dev\aquiset\apps\mobile_flutter`.

## How GitHub builds the APK + AAB (no Windows build)

`release.yml` does it all on a tag push: `flutter create
--platforms=android`, delete the duplicate generated MainActivity,
run `tools/patch_android.py` (signing + Glance deps), restore the
keystore from Secrets, then `flutter build appbundle --release` +
`flutter build apk --release`. The AAB + APK land on the GitHub
Release page and as run artifacts. `ci.yml` does the same shell
generation on every push to `main`, unsigned, for analyze + test.

## 1. Create the repo

github.com > New repository. Name: `aquiset` (private to start).
Do NOT tick “Add a README”.

## 2. Upload this zip's contents

Unzip `AQUISET_v5.2_GitHub-Ready.zip`, upload the `aquiset/` folder
contents to the repo (GitHub web upload, or git push — either works).
Check on github.com: `lib/core/design/tokens.dart` is there, and NO
`.env`, `.jks`, or `key.properties` file is listed. If one is listed,
delete it before the next step.

## 3. Add the 4 Secrets (once)

Repo > Settings > Secrets and variables > Actions > New repository secret.
See `docs/RELEASE_SIGNING.md` §2 for how to make the keystore and the
base64 value. The 4 secrets:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS` (= `upload`)
- `KEY_PASSWORD`

Without all 4, the release job stops with `MISSING SECRET: ...` — that
is intentional, so you never get an unsigned build mistaken for signed.

## 4. Tag it — GitHub builds

Create the tag on GitHub (Releases > Draft a new release > tag `v0.1.0`,
or git push a tag). The `release` workflow runs. Wait for the green tick,
then open that Release: `app-release.aab` + `app-release.apk` are
attached there. Download the APK, install it on the phone, and check the
Liquid Glass Home / Hydration / Sleep screens load.

If the run is red, open the failed step's log — the patch script prints
the build file, and the secrets check names the missing secret.

## Branch rule

- `main` = always buildable. Feature work on `feature/<name>` branches,
  pull request into `main`, CI must be green before merge.
- Never commit `.env`, keystore, or `key.properties`. Ever.
