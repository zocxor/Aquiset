#!/usr/bin/env python3
"""Patch the Flutter-generated android/app/build.gradle.kts for AQUISET v5.

Run by GitHub Actions AFTER `flutter create --platforms=android`.
Does NOT touch any file under lib/ (theme untouched).

What it does:
  1. Loads key.properties into keystoreProperties (top of file).
  2. Forces namespace / applicationId to com.aquiset.app,
     minSdk 28, compileSdk 36, targetSdk 36.
  3. Adds signingConfigs.release from key.properties and wires
     buildTypes.release to it (replaces the template's debug signing).
  4. Adds the Kotlin Compose plugin + Glance deps (needed by
     TodayWidget.kt, which imports androidx.glance.*).
     Also adds the Compose plugin (same Kotlin version) to
     android/settings.gradle.kts when that file exists, so the bare
     `id("org.jetbrains.kotlin.plugin.compose")` in the app file resolves.

Idempotent: running it twice changes nothing the second time.
Fails loudly (exit 1) if a pattern it needs is missing, so the
Actions log shows the file instead of a silent bad build.
Usage: python3 tools/patch_android.py apps/mobile_flutter/android/app/build.gradle.kts
"""
import sys
from pathlib import Path

APP_ID = "com.aquiset.app"

KEYPROPS_HEADER = '''import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

'''

SIGNING_BLOCK = '''    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

'''


def fail(msg, text):
    print(f"PATCH FAILED: {msg}")
    print("---- build.gradle.kts ----")
    print(text)
    print("--------------------------")
    sys.exit(1)


def main():
    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8")
    orig = text

    # 1. key.properties loader at the top (once only).
    if "keystoreProperties" not in text:
        text = KEYPROPS_HEADER + text

    # 2. Namespace + applicationId.
    # Template forms vary; handle the common ones, fail if none match.
    replaced = False
    for old_prefix in ('namespace = "com.aquiset.aquiset"',
                       'namespace = "com.aquiset.app"'):
        if old_prefix in text:
            text = text.replace(old_prefix, f'namespace = "{APP_ID}"')
            replaced = True
    if 'namespace = ' in text and f'namespace = "{APP_ID}"' not in text:
        # Generic fallback: rewrite whatever namespace line exists.
        lines = text.splitlines(True)
        for i, line in enumerate(lines):
            if line.strip().startswith("namespace = "):
                lines[i] = f'    namespace = "{APP_ID}"\n'
                replaced = True
                break
        text = "".join(lines)
    if not replaced:
        fail("no namespace line found", text)

    replaced = False
    for old in ('applicationId = "com.aquiset.aquiset"',
                'applicationId = "com.aquiset.app"'):
        if old in text:
            text = text.replace(old, f'applicationId = "{APP_ID}"')
            replaced = True
    if 'applicationId = ' in text and f'applicationId = "{APP_ID}"' not in text:
        lines = text.splitlines(True)
        for i, line in enumerate(lines):
            if "applicationId = " in line:
                indent = line[: len(line) - len(line.lstrip())]
                lines[i] = f'{indent}applicationId = "{APP_ID}"\n'
                replaced = True
                break
        text = "".join(lines)
    if not replaced:
        fail("no applicationId line found", text)

    # 3. SDK levels. Template uses flutter.* versions; pin to v5 spec.
    text = text.replace("minSdk = flutter.minSdkVersion", "minSdk = 28")
    text = text.replace("compileSdk = flutter.compileSdkVersion", "compileSdk = 36")
    text = text.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 36")
    # If the template already has literal numbers, force them too.
    import re
    text = re.sub(r"minSdk = \d+", "minSdk = 28", text)
    text = re.sub(r"compileSdk = \d+", "compileSdk = 36", text)
    text = re.sub(r"targetSdk = \d+", "targetSdk = 36", text)
    for needle in ("minSdk = 28", "compileSdk = 36", "targetSdk = 36"):
        if needle not in text:
            fail(f"missing {needle} after patch", text)

    # 4. Compose plugin (once only).
    if "org.jetbrains.kotlin.plugin.compose" not in text:
        text = text.replace(
            '    id("kotlin-android")',
            '    id("kotlin-android")\n    id("org.jetbrains.kotlin.plugin.compose")',
        )
        if "org.jetbrains.kotlin.plugin.compose" not in text:
            fail("could not add compose plugin after kotlin-android", text)

    # 5. signingConfigs.release (once only), inserted before buildTypes.
    if 'create("release")' not in text:
        if "buildTypes {" not in text:
            fail("no buildTypes block found", text)
        text = text.replace("    buildTypes {", SIGNING_BLOCK + "    buildTypes {", 1)

    # 6. Wire release buildType to the release signing config.
    if 'signingConfig = signingConfigs.getByName("release")' not in text:
        text = text.replace(
            'signingConfig = signingConfigs.getByName("debug")',
            'signingConfig = signingConfigs.getByName("release")',
        )
    if 'signingConfig = signingConfigs.getByName("release")' not in text:
        fail("release buildType is not wired to release signingConfig", text)

    # 7. Glance + coroutines deps (once only).
    glance = '    implementation("androidx.glance:glance-appwidget:1.1.1")\n'
    if "androidx.glance:glance-appwidget" not in text:
        if "dependencies {" in text:
            text = text.replace(
                "dependencies {",
                "dependencies {\n"
                + glance
                + '    implementation("androidx.glance:glance-material3:1.1.1")\n'
                + '    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")\n',
                1,
            )
        else:
            text += (
                "\ndependencies {\n"
                + glance
                + '    implementation("androidx.glance:glance-material3:1.1.1")\n'
                + '    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")\n'
                + "}\n"
            )

    # 8. settings.gradle.kts: declare the Compose plugin version (once only).
    # flutter create puts the Kotlin version on the kotlin.android line;
    # mirror that version for the compose plugin so the app file's bare id resolves.
    settings_path = path.parent.parent / "settings.gradle.kts"
    if settings_path.exists():
        settings = settings_path.read_text(encoding="utf-8")
        if "org.jetbrains.kotlin.plugin.compose" not in settings:
            m = re.search(
                r'id\("org\.jetbrains\.kotlin\.android"\) version "([^"]+)"( apply false)?',
                settings,
            )
            if m:
                settings = settings.replace(
                    m.group(0),
                    f'id("org.jetbrains.kotlin.android") version "{m.group(1)}" apply false'
                    + f'\n    id("org.jetbrains.kotlin.plugin.compose") version "{m.group(1)}" apply false',
                    1,
                )
                settings_path.write_text(settings, encoding="utf-8")
                print(f"patched settings: {settings_path} (compose {m.group(1)})")
            else:
                print("note: no versioned kotlin.android line in settings.gradle.kts; "
                      "leaving settings unchanged")

    if text != orig:
        path.write_text(text, encoding="utf-8")
        print("patched: " + str(path))
    else:
        print("already patched: " + str(path))
    print("checks: namespace/appId com.aquiset.app, minSdk 28, compileSdk 36, "
          "targetSdk 36, release signing, compose + glance deps")


if __name__ == "__main__":
    main()
