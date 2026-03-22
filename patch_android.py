import os, re, sys, shutil

build_number = int(sys.argv[1]) if len(sys.argv) > 1 else 1

# ── 1. Patch AndroidManifest.xml ─────────────────────────────────────────────
manifest_path = 'android/app/src/main/AndroidManifest.xml'
with open(manifest_path) as f:
    manifest = f.read()

if 'INTERNET' not in manifest:
    manifest = manifest.replace('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    '
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n    '
        '<application')

if 'networkSecurityConfig' not in manifest:
    manifest = manifest.replace('<application',
        '<application android:networkSecurityConfig="@xml/network_security_config"', 1)

with open(manifest_path, 'w') as f:
    f.write(manifest)
print('Manifest OK')

# ── 2. Network security config ───────────────────────────────────────────────
os.makedirs('android/app/src/main/res/xml', exist_ok=True)
nsc = ('<?xml version="1.0" encoding="utf-8"?>\n'
       '<network-security-config>\n'
       '  <base-config cleartextTrafficPermitted="true">\n'
       '    <trust-anchors><certificates src="system"/></trust-anchors>\n'
       '  </base-config>\n'
       '</network-security-config>')
with open('android/app/src/main/res/xml/network_security_config.xml', 'w') as f:
    f.write(nsc)
print('NSC OK')

# ── 3. Add MediaPipe dependency to build.gradle ──────────────────────────────
gradle_path = 'android/app/build.gradle'
with open(gradle_path) as f:
    gradle = f.read()

# BUG FIX: Remove the rootProject-based google-services block that causes
# "Cannot get property 'rootProject' on null object" error at build.gradle line 8.
# Capacitor generates a try/catch block that accesses rootProject before it's
# initialized, crashing the build. We strip it out entirely since this app
# doesn't use Firebase/Push Notifications.
google_services_pattern = re.compile(
    r'try\s*\{[^}]*google-services[^}]*\}[^\n]*\n?'
    r'(?:[^\n]*\n?)*?'
    r'[^\n]*google-services[^\n]*\n?',
    re.DOTALL
)
# Simpler targeted removal: remove the specific try/catch block Capacitor adds
gradle = re.sub(
    r'try \{[^}]*def servicesJSON.*?google-services plugin not applied[^\n]*\n?\}',
    '// google-services plugin removed (not needed - no Firebase)',
    gradle,
    flags=re.DOTALL
)
print('google-services block patched OK')

mediapipe_dep = "    implementation 'com.google.mediapipe:tasks-genai:0.10.22'"
if 'tasks-genai' not in gradle:
    # BUG FIX: Target the *last* dependencies { block (the app dependencies),
    # not the first one (which may be a buildscript block), to avoid corrupting
    # the wrong section of build.gradle.
    last_dep_pos = gradle.rfind('dependencies {')
    if last_dep_pos != -1:
        gradle = gradle[:last_dep_pos + len('dependencies {')] + '\n' + mediapipe_dep + gradle[last_dep_pos + len('dependencies {'):]
        print('MediaPipe dependency added')
    else:
        print('WARNING: Could not find dependencies block!')
else:
    print('MediaPipe already present')

# Bump minSdk to 24 (required by MediaPipe tasks-genai)
gradle = re.sub(r'minSdkVersion\s+\d+', 'minSdkVersion 24', gradle)
gradle = re.sub(r'minSdk\s*=?\s*\d+', 'minSdk 24', gradle)

# Bump versionCode and versionName
gradle = re.sub(r'versionCode \d+', f'versionCode {build_number}', gradle)
gradle = re.sub(r'versionName "[^"]*"', f'versionName "1.{build_number}"', gradle)

with open(gradle_path, 'w') as f:
    f.write(gradle)
print(f'build.gradle OK (v1.{build_number})')

# ── 4. Copy LLMPlugin.java into Android project ──────────────────────────────
plugin_dir = 'android/app/src/main/java/com/iamborednowok/smartcalc'
os.makedirs(plugin_dir, exist_ok=True)
shutil.copy('LLMPlugin.java', os.path.join(plugin_dir, 'LLMPlugin.java'))
print('LLMPlugin.java copied OK')

# ── 5. Register plugin in MainActivity.java ──────────────────────────────────
main_path = os.path.join(plugin_dir, 'MainActivity.java')
with open(main_path) as f:
    main = f.read()

if 'LLMPlugin' not in main:
    # Add import for LLMPlugin (no ArrayList — it's not used)
    main = main.replace(
        'import com.getcapacitor.BridgeActivity;',
        'import com.getcapacitor.BridgeActivity;\nimport com.getcapacitor.Plugin;'
    )

    # BUG FIX: Before inserting our onCreate, check whether the template already
    # has one (Capacitor sometimes pre-generates it). If it does, just insert
    # registerPlugin() as the first line inside the existing onCreate instead of
    # creating a duplicate method (which would cause a compile error).
    if 'void onCreate(' in main:
        # Insert registerPlugin as first statement inside existing onCreate
        main = re.sub(
            r'(void onCreate\([^)]*\)\s*\{)',
            r'\1\n    registerPlugin(LLMPlugin.class);',
            main,
            count=1
        )
        print('Inserted registerPlugin into existing onCreate OK')
    else:
        # No onCreate yet — inject a full override
        main = main.replace(
            'public class MainActivity extends BridgeActivity {',
            'public class MainActivity extends BridgeActivity {\n'
            '  @Override\n'
            '  public void onCreate(android.os.Bundle savedInstanceState) {\n'
            '    registerPlugin(LLMPlugin.class);\n'
            '    super.onCreate(savedInstanceState);\n'
            '  }'
        )
        print('MainActivity onCreate injected OK')

    with open(main_path, 'w') as f:
        f.write(main)
    print('MainActivity patched OK')
else:
    print('MainActivity already has LLMPlugin')

print(f'\nAll patches done! Build number: {build_number}')
