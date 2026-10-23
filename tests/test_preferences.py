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
    assert (bundle / "RelaxTunePrefs").is_file(), "Missing settings executable"
else:
    entry_file = root / "layout/Library/PreferenceLoader/Preferences/RelaxTune.plist"
    info_file = root / "prefs/Resources/Info.plist"
    root_file = root / "prefs/Resources/Root.plist"

entry = read(entry_file)["entry"]
info = read(info_file)
settings = read(root_file)["items"]
assert entry["isController"] is True, "Controller bundle must be marked for lazy loading"
assert entry["cell"] == "PSLinkCell"
assert entry["bundle"] == info["CFBundleExecutable"] == "RelaxTunePrefs"
assert entry["detail"] == info["NSPrincipalClass"] == "RTRootController"
switches = {item["key"]: item for item in settings if item["cell"] == "PSSwitchCell"}
assert set(switches) == {"Enabled", "Animations", "Network", "LowPower", "Audio",
                         "GamePerformance", "HighRefresh"}
for key, item in switches.items():
    assert item["defaults"] == "com.12233sjjs.relaxtune", key
    assert type(item["default"]) is bool, key
assert switches["Audio"]["default"] is False
assert switches["GamePerformance"]["default"] is True
assert switches["HighRefresh"]["default"] is False
assert any(item.get("cellClass") == "RTFactorCell" for item in settings)
print("PASS: PreferenceLoader controller declaration, settings metadata and switches")
