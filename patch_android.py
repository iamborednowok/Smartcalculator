import os, re, sys

# 1. Patch AndroidManifest.xml
path = 'android/app/src/main/AndroidManifest.xml'
with open(path) as f:
    m = f.read()

if 'INTERNET' not in m:
    m = m.replace('<application',
        '<uses-permission android:name="android.permission.INTERNET"/>'
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>'
        '<application')

if 'networkSecurityConfig' not in m:
    m = m.replace('<application',
        '<application android:networkSecurityConfig="@xml/network_security_config"', 1)

with open(path, 'w') as f:
    f.write(m)
print('Manifest OK')

# 2. Create network_security_config.xml
os.makedirs('android/app/src/main/res/xml', exist_ok=True)
nsc = '<?xml version="1.0" encoding="utf-8"?>\n<network-security-config>\n  <base-config cleartextTrafficPermitted="true">\n    <trust-anchors><certificates src="system"/></trust-anchors>\n  </base-config>\n</network-security-config>'
with open('android/app/src/main/res/xml/network_security_config.xml', 'w') as f:
    f.write(nsc)
print('NSC OK')

# 3. Bump versionCode
build = int(sys.argv[1])
with open('android/app/build.gradle') as f:
    g = f.read()
g = re.sub(r'versionCode \d+', f'versionCode {build}', g)
g = re.sub(r'versionName "[^"]*"', f'versionName "1.{build}"', g)
with open('android/app/build.gradle', 'w') as f:
    f.write(g)
print(f'versionCode: {build}')
