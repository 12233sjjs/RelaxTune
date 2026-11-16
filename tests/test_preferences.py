import pathlib
import plistlib
import sys


def read(path):
    with path.open("rb") as stream:
        return plistlib.load(stream)


root = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(".")
if len(sys.argv) > 1:
    libraries = [root / "Library", root / "var/jb/Library"]
    libraries = [path for path in libraries if path.exists()]
    assert len(libraries) == 1, "Package must contain exactly one installation prefix"
    library = libraries[0]
    entry_file = library / "PreferenceLoader/Preferences/RelaxTune.plist"
    bundle = library / "PreferenceBundles/RelaxTunePrefs.bundle"
    info_file = bundle / "Info.plist"
    root_file = bundle / "Root.plist"
    filter_file = library / "MobileSubstrate/DynamicLibraries/RelaxTune.plist"
    assert (bundle / "RelaxTunePrefs").is_file(), "Missing settings executable"
    assert (library / "ccSystem/system_tweaks.sh").is_file(), "Missing manual kernel module"
    binary = (library / "MobileSubstrate/DynamicLibraries/RelaxTune.dylib").read_bytes()
    for removed in (b"SBPocketStateMonitor", b"SBThermalController", b"RTLowPower",
                    b"RTPocketThermal", b"RTSunlightThermal", b"RTPowerDecision"):
        assert removed not in binary, f"Removed feature is still packaged: {removed!r}"
else:
    entry_file = root / "layout/Library/PreferenceLoader/Preferences/RelaxTune.plist"
    info_file = root / "prefs/Resources/Info.plist"
    root_file = root / "prefs/Resources/Root.plist"
    filter_file = root / "RelaxTune.plist"

assert set(read(filter_file)["Filter"]["Bundles"]) == {"com.apple.UIKit", "com.apple.springboard"}

entry = read(entry_file)["entry"]
info = read(info_file)
settings = read(root_file)["items"]
assert entry["isController"] is True, "Controller bundle must be marked for lazy loading"
assert entry["cell"] == "PSLinkCell"
assert entry["bundle"] == info["CFBundleExecutable"] == "RelaxTunePrefs"
assert entry["detail"] == info["NSPrincipalClass"] == "RTRootController"
switches = {item["key"]: item for item in settings if item["cell"] == "PSSwitchCell"}
assert set(switches) == {"Enabled", "Animations", "Network", "TCPNoDelay",
                         "GamePerformance", "HighRefresh", "ZombieReap"}
for key, item in switches.items():
    assert item["defaults"] == "com.12233sjjs.relaxtune", key
    assert type(item["default"]) is bool, key
assert switches["GamePerformance"]["default"] is True
assert switches["TCPNoDelay"]["default"] is False
assert switches["HighRefresh"]["default"] is True
assert switches["ZombieReap"]["default"] is False
assert any(item.get("cellClass") == "RTFactorCell" for item in settings)
assert any(item.get("action") == "rtEditAnimationExclusions:" and "detail" not in item
           for item in settings)
assert not any("音效" in item.get("label", "") or item.get("key") == "Audio"
               for item in settings)
if len(sys.argv) == 1:
    controller_source = (root / "prefs/RootController.m").read_text(encoding="utf-8")
    assert "rtEditAnimationExclusions:(PSSpecifier *)specifier" in controller_source
    assert "RTAnimationExclusionController" not in controller_source
    tweak_source = (root / "src/Animation.x").read_text(encoding="utf-8")
    assert "UIViewAnimationOptions smoothed = RTSmoothOptions(options);" in tweak_source
print("PASS: PreferenceLoader controller declaration, settings metadata and switches")
