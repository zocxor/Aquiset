# Signed APK + AAB — GitHub builds them

No APK or AAB is in this zip. GitHub Actions builds them when you push
a tag (see `docs/GITHUB_SETUP.md`). Theme is not touched by any step here.

## 0. The one rule that cannot be undone

Create ONE release keystore, back it up in TWO safe places offline
(USB + password manager), and NEVER lose it. If it is lost, Google Play
will never accept an update to the same app — you would have to publish
a new app with a new package name. Never commit it to GitHub, never send
it in chat, never reuse a test keystore as the release key.

Decide first, and keep the answers private:
- Keystore password (storePassword) — choose a strong one, save it now.
- Key password (keyPassword) — can be the same, save it now.
- Key alias: `upload`
- Validity: 10000 days.

## 1. Make the keystore once (only Windows step)

You need `keytool`, which ships with any JDK 17. If you do not have a
JDK on the PC, install Temurin JDK 17 first, then in PowerShell:

```powershell
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Answer the prompts (name / organisation / city / country). `keytool`
asks for the keystore password, then the key password — use the ones
you chose above. This creates `upload-keystore.jks` in the current folder.

Back it up NOW, before anything else:

```powershell
Get-ChildItem upload-keystore.jks
```

Copy it to your offline backup (USB + password manager). Do NOT put it
in the repo folder.

## 2. Turn it into the 4 GitHub Secrets

In the same PowerShell window, copy the base64 of the keystore to the
clipboard:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

Then in GitHub: repo > Settings > Secrets and variables > Actions >
New repository secret, one at a time:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | paste from clipboard |
| `KEYSTORE_PASSWORD` | your keystore password |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | your key password |

Paste into GitHub only — never into chat, never into a file in the repo.
Close the PowerShell window after; the clipboard clears on its own, but
do not save the base64 anywhere.

## 3. Tag it — GitHub builds

On GitHub: Releases > Draft a new release > tag `v0.1.0` > Publish.
Or with git:

```powershell
git tag v0.1.0
git push origin v0.1.0
```

The `release` workflow then: generates the Android shell, patches
signing + Glance deps (`tools/patch_android.py`), restores the keystore
from Secrets, runs `flutter analyze`, `flutter test`,
`flutter build appbundle --release`, `flutter build apk --release`,
verifies the APK signature, and attaches both files to the Release.

Download from that Release page:
- `app-release.aab` — what Play wants for a new app.
- `app-release.apk` — install directly on the phone to test.

## 4. How you know it is the signed v5 build

- The Release files show today's date in the workflow run.
- The workflow log's `Verify outputs + signature` step shows
  `jar verified` and your alias `upload`.
- On the phone, the Liquid Glass Home / Hydration / Sleep screens load.
  If the phone shows an old screen, it installed an old APK — uninstall
  the old app first, then install this APK.

## Play Store note

Before any Play upload you still need: privacy policy at a public URL,
Data Safety form, and the exact-alarm / full-screen-intent policy check
in `docs/PLATFORM_FEATURES.md`. None of that is in this zip — it is a
separate step after the signed build works on the phone.

## Local build (optional, not needed for GitHub)

If you ever want the same build on Windows: run `flutter create
--platforms=android --org com.aquiset .` in `apps/mobile_flutter`,
copy `key.properties.example` to `key.properties` with your passwords,
run `python3 ../../tools/patch_android.py android/app/build.gradle.kts`,
then `flutter build appbundle --release` + `flutter build apk --release`.
See `docs/ANDROID_SIGNING_PATCH.md` for what the script does.
