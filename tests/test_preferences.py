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
    payloads = list((library / "MobileSubstrate/DynamicLibraries").glob("*.dylib"))
    payloads += [bundle / "RelaxTunePrefs", library / "ccSystem/system_tweaks.sh"]
    for path in payloads:
        binary = path.read_bytes()
        for removed in (b"SBPocketStateMonitor", b"SBThermalController", b"RTLowPower",
                        b"RTPocketThermal", b"RTSunlightThermal", b"RTPowerDecision",
                        b"RTGamePower", b"RTGamePerformance", b"GamePerformance",
                        b"GameRestoreLowPower", b"OwnsLowPower", b"RTApplyPower",
                        b"_PMLowPowerMode", b"_CDBatterySaver", b"setPowerMode:",
                        b"LowPowerMode.framework", b"putDeviceInThermalSimulationMode:"):
            assert removed not in binary, f"Removed feature in {path}: {removed!r}"
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
                         "HighRefresh", "ZombieReap",
                         "WakeAnimations", "UnlockAnimations"}
for key, item in switches.items():
    assert item["defaults"] == "com.12233sjjs.relaxtune", key
    assert type(item["default"]) is bool, key
assert switches["TCPNoDelay"]["default"] is False
assert switches["HighRefresh"]["default"] is True
assert switches["ZombieReap"]["default"] is False
assert switches["WakeAnimations"]["default"] is False
assert switches["UnlockAnimations"]["default"] is False
levels = {item["key"]: item for item in settings if item.get("cellClass") == "RTFactorCell"}
assert set(levels) == {"AnimationAcceleration", "WakeAcceleration", "UnlockAcceleration"}
assert any(item.get("action") == "rtEditAnimationExclusions:" and "detail" not in item
           for item in settings)
assert not any("音效" in item.get("label", "") or item.get("key") == "Audio"
               for item in settings)
if len(sys.argv) == 1:
    controller_source = (root / "prefs/RootController.m").read_text(encoding="utf-8")
    assert "rtEditAnimationExclusions:(PSSpecifier *)specifier" in controller_source
    assert "RTAnimationExclusionController" not in controller_source
    assert "_factorStepper.stepValue = 0.1;" in controller_source
    tweak_source = (root / "src/Animation.x").read_text(encoding="utf-8")
    assert "UIViewAnimationOptions smoothed = RTSmoothOptions(options);" in tweak_source
    lifecycle_source = (root / "src/Tweak.x").read_text(encoding="utf-8")
    # Every packaged app entry uses bundle eligibility, never external blacklists.
    settings_source = (root / "src/Settings.m").read_text(encoding="utf-8")
    for removed in ("RootHideConfig.plist", "appconfig", "com.tencent.smoba",
                    "RTIsExcludedApp"):
        assert removed not in settings_source, f"External blacklist exclusion restored: {removed}"
    main_ctor = lifecycle_source.split("%ctor", 1)[1]
    main_guard = main_ctor.index("if (!RTSpringBoard && !RTShouldLoadAppHooks()) return;")
    assert main_guard < main_ctor.index("RTLoadSettings();")
    assert main_guard < main_ctor.index("CFNotificationCenterAddObserver")
    assert main_guard < main_ctor.index("RTInstallAnimationHooks")
    assert main_guard < main_ctor.index("%init(RTApps)")
    network_source = (root / "src/Network.x").read_text(encoding="utf-8")
    network_ctor = network_source.split("%ctor", 1)[1]
    network_guard = network_ctor.index("!RTShouldLoadAppHooks()")
    assert network_guard < network_ctor.index("RTLoadSettings();")
    assert network_guard < network_ctor.index("MSHookFunction")
    for removed in ("RTApplyPower", "setPowerMode:", "LowPowerMode.framework",
                    "GameRestoreLowPower", "OwnsLowPower", "frontDisplayDidChange:",
                    "com.apple.springboard.lockstate"):
        assert removed not in lifecycle_source, f"Removed power path: {removed}"
    assert not (root / "src/PowerPolicy.c").exists()
    assert not (root / "src/PowerPolicy.h").exists()
print("PASS: PreferenceLoader metadata, independent animation settings, no power/thermal controls")
