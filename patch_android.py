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

mediapipe_dep = "    implementation 'com.google.mediapipe:tasks-genai:0.10.22'"
if 'tasks-genai' not in gradle:
    gradle = gradle.replace(
        'dependencies {',
        'dependencies {\n' + mediapipe_dep
    )
    print('MediaPipe dependency added')
else:
    print('MediaPipe already present')

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

# Add import if missing
if 'LLMPlugin' not in main:
    main = main.replace(
        'import com.getcapacitor.BridgeActivity;',
        'import com.getcapacitor.BridgeActivity;\nimport com.getcapacitor.Plugin;\nimport java.util.ArrayList;'
    )
    # Add registerPlugin call
    main = main.replace(
        'public class MainActivity extends BridgeActivity {',
        'public class MainActivity extends BridgeActivity {\n'
        '  @Override\n'
        '  public void onCreate(android.os.Bundle savedInstanceState) {\n'
        '    registerPlugin(LLMPlugin.class);\n'
        '    super.onCreate(savedInstanceState);\n'
        '  }'
    )
    # Remove duplicate onCreate if any
    with open(main_path, 'w') as f:
        f.write(main)
    print('MainActivity patched OK')
else:
    print('MainActivity already has LLMPlugin')

print(f'\nAll patches done! Build number: {build_number}')
