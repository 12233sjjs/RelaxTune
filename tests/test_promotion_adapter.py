#!/usr/bin/env python3
"""Static regression checks; not an iOS runtime test."""
from pathlib import Path
import hashlib, plistlib, re, struct, sys
root = Path(__file__).resolve().parents[1]
# Source checks always run; an optional extracted-package root adds payload gates.
if len(sys.argv) > 1:
    package = Path(sys.argv[1]).resolve()
    providers = list(package.rglob('RelaxTuneProMotion120.dylib'))
    assert len(providers) == 1, f'Expected one embedded provider, got {providers}'
    libdir = providers[0].parent
    payload = providers[0].parents[3]
    assert hashlib.sha256(providers[0].read_bytes()).hexdigest() == 'ed0d0d483735bf0157cc848f5704a3925f2206c40a5ecea4f9b70b96611dddeb'
    assert plistlib.loads((libdir / 'RelaxTuneProMotion120.plist').read_bytes()) == {'Filter': {'Bundles': ['com.12233sjjs.relaxtune.manual-loader-only']}}
    assert set(plistlib.loads((libdir / 'RelaxTune.plist').read_bytes())['Filter']['Bundles']) == {'com.apple.UIKit', 'com.apple.springboard', 'com.apple.UserNotificationsUIServer', 'com.apple.springboard.SpringBoardOutofCallUI'}
    packaged = plistlib.loads((payload / 'Library/PreferenceBundles/RelaxTunePrefs.bundle/Root.plist').read_bytes())
    switches = {i.get('key'): i for i in packaged['items'] if i.get('key')}
    assert all(switches[k]['default'] is True for k in ['Enabled', 'HighRefresh'])
    assert '重启生效' in switches['HighRefresh']['label']
def plist(path):
    return plistlib.loads((root / path).read_bytes())
base = 'layout/Library/MobileSubstrate/DynamicLibraries/'
provider = (root / base / 'RelaxTuneProMotion120.dylib').read_bytes()
assert hashlib.sha256(provider).hexdigest() == 'ed0d0d483735bf0157cc848f5704a3925f2206c40a5ecea4f9b70b96611dddeb'
assert struct.unpack_from('<III', provider) == (0xfeedfacf, 0x100000c, 0x80000002)
assert b'@loader_path/.jbroot/usr/lib/libsubstrate.dylib' in provider
assert plist(base + 'RelaxTuneProMotion120.plist') == {'Filter': {'Bundles': ['com.12233sjjs.relaxtune.manual-loader-only']}}
assert set(plist('RelaxTune.plist')['Filter']['Bundles']) == {
    'com.apple.UIKit', 'com.apple.springboard', 'com.apple.UserNotificationsUIServer',
    'com.apple.springboard.SpringBoardOutofCallUI'}
source = (root / 'src/Refresh.x').read_text()
guard = 'if (!atomic_load(&RTEnabled) || !atomic_load(&RTHighRefresh)) return;'
assert guard in source and source.index(guard) < source.index('(void)dlopen(')
# Expansion changes the injection candidates, not per-feature eligibility.
tweak = (root / 'src/Tweak.x').read_text()
network = (root / 'src/Network.x').read_text()
assert 'RTShouldLoadAppHooks()' in tweak
assert 'RTHighRefresh' not in tweak and 'RTHighRefresh' not in network
assert 'RTEnabled' in network and 'RTTCPNoDelay' in network
assert '@loader_path/RelaxTuneProMotion120.dylib' in source
assert 'RTLD_NOW | RTLD_LOCAL' in source
assert '%hook' not in source and 'dlclose(' not in source
animation = (root / 'src/Animation.x').read_text()
helper = re.search(r'static void RTApply120FrameRate\(id settings\) \{(.*?)\n\}', animation, re.S).group(1)
assert '(void)settings;' in helper and 'CAFrameRateRangeMake' not in helper
items = plist('prefs/Resources/Root.plist')['items']
settings = {i.get('key'): i for i in items if i.get('key')}
for key in ['Enabled', 'HighRefresh']:
    assert settings[key]['default'] is True
assert '重启生效' in settings['HighRefresh']['label']
assert 'Version: 0.5.1\n' in (root / 'control').read_text()
assert 'Conflicts: com.doimty.promotion,' in (root / 'control').read_text()
assert 'THEOS_PACKAGE_SCHEME ?= roothide' in (root / 'Makefile').read_text()
print('PASS: original provider, manual filter, startup switches, old helper removal, source metadata')
