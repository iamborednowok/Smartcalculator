"""
patch_android.py  —  SmartCalc Android post-cap-sync patcher
=============================================================

Strategy: COPY templates, don't patch generated files with regex.

  templates/MainActivity.java   → copied verbatim (no regex on Java)
  templates/variables.gradle    → copied verbatim (Capacitor reads it officially)
  templates/mediapipe.gradle    → applied via `apply from:` (no dep-block injection)
  AndroidManifest.xml           → patched with proper XML parser (not string.replace)
  build.gradle                  → only two safe line-level sed-style ops:
                                  1. Remove google-services try/catch (balanced-brace parser)
                                  2. Inject `apply from:` for mediapipe.gradle
  versionCode / versionName     → set via sed on EXACT patterns only

Usage:
    python3 patch_android.py <build_number>
"""

import os, re, sys, shutil
from xml.etree import ElementTree as ET

# ─── Config ───────────────────────────────────────────────────────────────────
BUILD_NUMBER  = int(sys.argv[1]) if len(sys.argv) > 1 else 1
APP_ID        = "com.iamborednowok.smartcalc"
PLUGIN_DIR    = f"android/app/src/main/java/{APP_ID.replace('.', '/')}"
MANIFEST_PATH = "android/app/src/main/AndroidManifest.xml"
GRADLE_PATH   = "android/app/build.gradle"
VARIABLES_DST = "android/variables.gradle"
MEDIAPIPE_DST = "android/mediapipe.gradle"

def step(msg): print(f"\n── {msg}")
def ok(msg):   print(f"   ✅ {msg}")
def warn(msg): print(f"   ⚠️  {msg}")
def fail(msg): print(f"   ❌ {msg}"); sys.exit(1)


# ═══════════════════════════════════════════════════════════════════════════════
# Step 1: Copy stable templates (no regex, no parsing, just shutil.copy)
# ═══════════════════════════════════════════════════════════════════════════════
step("Copying templates")

# 1a. variables.gradle → android/variables.gradle
# Capacitor's android/build.gradle already contains:
#   apply from: "../variables.gradle"
# so dropping our file there is all that's needed.
shutil.copy("templates/variables.gradle", VARIABLES_DST)
ok(f"variables.gradle → {VARIABLES_DST}")

# 1b. mediapipe.gradle → android/mediapipe.gradle
shutil.copy("templates/mediapipe.gradle", MEDIAPIPE_DST)
ok(f"mediapipe.gradle → {MEDIAPIPE_DST}")

# 1c. MainActivity.java → copied verbatim, zero regex
os.makedirs(PLUGIN_DIR, exist_ok=True)
shutil.copy("templates/MainActivity.java", os.path.join(PLUGIN_DIR, "MainActivity.java"))
ok("MainActivity.java copied (no regex)")

# 1d. LLMPlugin.java
shutil.copy("LLMPlugin.java", os.path.join(PLUGIN_DIR, "LLMPlugin.java"))
ok("LLMPlugin.java copied")


# ═══════════════════════════════════════════════════════════════════════════════
# Step 2: AndroidManifest.xml — proper XML parser, not string.replace
# ═══════════════════════════════════════════════════════════════════════════════
step("Patching AndroidManifest.xml (XML parser)")

ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
NS = "http://schemas.android.com/apk/res/android"

tree = ET.parse(MANIFEST_PATH)
root = tree.getroot()

def has_permission(manifest_root, name):
    for el in manifest_root.findall("uses-permission"):
        if el.get(f"{{{NS}}}name") == name:
            return True
    return False

# Add INTERNET permission if absent
if not has_permission(root, "android.permission.INTERNET"):
    perm = ET.Element("uses-permission")
    perm.set(f"{{{NS}}}name", "android.permission.INTERNET")
    root.insert(0, perm)
    ok("INTERNET permission added")
else:
    ok("INTERNET permission already present")

if not has_permission(root, "android.permission.ACCESS_NETWORK_STATE"):
    perm = ET.Element("uses-permission")
    perm.set(f"{{{NS}}}name", "android.permission.ACCESS_NETWORK_STATE")
    root.insert(1, perm)
    ok("ACCESS_NETWORK_STATE added")
else:
    ok("ACCESS_NETWORK_STATE already present")

# Add networkSecurityConfig to <application> if absent
app_el = root.find("application")
if app_el is not None:
    nsc_attr = f"{{{NS}}}networkSecurityConfig"
    if not app_el.get(nsc_attr):
        app_el.set(nsc_attr, "@xml/network_security_config")
        ok("networkSecurityConfig attribute added")
    else:
        ok("networkSecurityConfig already present")

# Write back — preserve declaration
tree.write(MANIFEST_PATH, encoding="unicode", xml_declaration=True)
ok("AndroidManifest.xml written")

# Write network_security_config.xml (idempotent — always overwrite with known-good content)
nsc_dir = "android/app/src/main/res/xml"
os.makedirs(nsc_dir, exist_ok=True)
nsc_content = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<network-security-config>\n'
    '  <base-config cleartextTrafficPermitted="true">\n'
    '    <trust-anchors><certificates src="system"/></trust-anchors>\n'
    '  </base-config>\n'
    '</network-security-config>'
)
with open(f"{nsc_dir}/network_security_config.xml", "w") as f:
    f.write(nsc_content)
ok("network_security_config.xml written")


# ═══════════════════════════════════════════════════════════════════════════════
# Step 3: build.gradle — minimal, safe operations only
# ═══════════════════════════════════════════════════════════════════════════════
step("Patching android/app/build.gradle")

with open(GRADLE_PATH) as f:
    lines = f.readlines()


# ── 3a. Remove google-services try/catch using balanced-brace parser ──────────
# This is the ONLY safe way to remove a multi-line block — not regex.
def remove_google_services_block(lines):
    result = []
    i = 0
    removed = 0
    while i < len(lines):
        line = lines[i]
        # Detect start of a try { block
        if re.match(r'\s*try\s*\{', line):
            # Collect entire try/catch using brace counting
            block = [line]
            depth = line.count('{') - line.count('}')
            j = i + 1
            while j < len(lines) and depth > 0:
                block.append(lines[j])
                depth += lines[j].count('{') - lines[j].count('}')
                j += 1
            # Also consume catch { } if present
            while j < len(lines) and re.match(r'\s*catch', lines[j]):
                block.append(lines[j])
                depth = lines[j].count('{') - lines[j].count('}')
                j += 1
                while j < len(lines) and depth > 0:
                    block.append(lines[j])
                    depth += lines[j].count('{') - lines[j].count('}')
                    j += 1
            block_text = ''.join(block)
            if 'servicesJSON' in block_text or 'google-services' in block_text:
                result.append('    // google-services block removed (no Firebase)\n')
                removed += len(block)
                ok(f"google-services block removed ({len(block)} lines)")
            else:
                result.extend(block)
            i = j
            continue
        result.append(line)
        i += 1
    if not removed:
        ok("No google-services block found (already clean)")
    return result

lines = remove_google_services_block(lines)


# ── 3b. Inject `apply from: '../../mediapipe.gradle'` once ───────────────────
# Find the last `apply plugin:` line and insert after it — much safer than
# injecting into a dependencies{} block via string search.
mediapipe_apply = "apply from: '../../mediapipe.gradle'\n"
full_text = ''.join(lines)

if mediapipe_apply.strip() not in full_text:
    # Find last 'apply plugin:' line index
    last_apply_idx = None
    for idx, line in enumerate(lines):
        if re.match(r'\s*apply\s+plugin:', line):
            last_apply_idx = idx
    if last_apply_idx is not None:
        lines.insert(last_apply_idx + 1, mediapipe_apply)
        ok("apply from: mediapipe.gradle injected after last 'apply plugin:'")
    else:
        # Fallback: append at end of file
        lines.append('\n' + mediapipe_apply)
        warn("apply from: mediapipe.gradle appended at end (no 'apply plugin:' found)")
else:
    ok("mediapipe.gradle already applied")


# ── 3c. versionCode / versionName — set build number ─────────────────────────
# These patterns match BOTH Capacitor 6 (rootProject.ext.*) and plain numbers.
# Using re.sub on individual lines is much safer than multi-line regex.
new_lines = []
for line in lines:
    line = re.sub(
        r'(versionCode\s+)(?:rootProject\.ext\.versionCode|\d+)',
        rf'\g<1>{BUILD_NUMBER}',
        line
    )
    line = re.sub(
        r'(versionName\s+)(?:rootProject\.ext\.versionName|"[^"]*")',
        rf'\g<1>"1.{BUILD_NUMBER}"',
        line
    )
    new_lines.append(line)
lines = new_lines
ok(f"versionCode={BUILD_NUMBER}, versionName=1.{BUILD_NUMBER}")


# ── 3d. Write build.gradle ────────────────────────────────────────────────────
with open(GRADLE_PATH, 'w') as f:
    f.writelines(lines)
ok("build.gradle written")


# ── 3e. Safety check: verify no rootProject references remain ─────────────────
remaining = [l.strip() for l in lines if 'rootProject' in l]
if remaining:
    fail(f"rootProject still present in build.gradle:\n  " + "\n  ".join(remaining))
ok("No rootProject references remain")


# ═══════════════════════════════════════════════════════════════════════════════
# Done
# ═══════════════════════════════════════════════════════════════════════════════
print(f"\n{'─'*55}")
print(f"✅  All patches done!  Build {BUILD_NUMBER}  (v1.{BUILD_NUMBER})")
print(f"{'─'*55}")
