import json
import pathlib
import plistlib
import sys


def read(path):
    with path.open("rb") as stream:
        return plistlib.load(stream)


root = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(".")
repo = pathlib.Path(__file__).resolve().parents[1]
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
    assert sorted(p.name for p in (library / "PreferenceLoader/Preferences").glob("*.plist")) == ["RelaxTune.plist"]
    assert not (library / "PreferenceBundles/DateInfoPrefs.bundle").exists(), "Do not vendor donor preference bundle"
    assert not (library / "MobileSubstrate/DynamicLibraries/DateInfo.dylib").exists(), "Do not vendor donor binary"
    assert not (library / "MobileSubstrate/DynamicLibraries/DateInfo.plist").exists(), "Do not vendor donor filter"
    assert not (library / "PreferenceLoader/Preferences/DateInfoPrefs.plist").exists(), "Use only RelaxTune root entry"
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
    library = root / "layout/Library"
    entry_file = library / "PreferenceLoader/Preferences/RelaxTune.plist"
    info_file = root / "prefs/Resources/Info.plist"
    root_file = root / "prefs/Resources/Root.plist"
    filter_file = root / "RelaxTune.plist"
    assert sorted(p.name for p in (library / "PreferenceLoader/Preferences").glob("*.plist")) == ["RelaxTune.plist"]
    assert not (library / "PreferenceBundles/DateInfoPrefs.bundle").exists(), "Do not vendor donor preference bundle"
    assert not (library / "MobileSubstrate/DynamicLibraries/DateInfo.dylib").exists(), "Do not vendor donor binary"
    assert not (library / "MobileSubstrate/DynamicLibraries/DateInfo.plist").exists(), "Do not vendor donor filter"
    assert not (library / "PreferenceLoader/Preferences/DateInfoPrefs.plist").exists(), "Use only RelaxTune root entry"

assert set(read(filter_file)["Filter"]["Bundles"]) == {
    "com.apple.UIKit", "com.apple.springboard", "com.apple.UserNotificationsUIServer",
    "com.apple.springboard.SpringBoardOutofCallUI"
}

entry = read(entry_file)["entry"]
info = read(info_file)
settings = read(root_file)["items"]
assert info["CFBundleVersion"] == info["CFBundleShortVersionString"] == "0.5.2"
control = (repo / "control").read_text(encoding="utf-8")
assert "Version: 0.5.2" in control
assert "com.zhuifeng.dateinfo (>= 1.3.10)" in control
manifest = json.loads((repo / "docs/TIME-CAPSULE-DONOR-MANIFEST.json").read_text(encoding="utf-8"))
assert manifest["donor"]["source_deb_sha256"] == "8673a62e53237c320e980fc94ad55ab273364c6d607452967de31f3f4546768a"
assert len(manifest["donor"]["payload_sha256"]) == 8
assert set(manifest["donor"]["payload_sha256"]) == set(manifest["donor"]["payload_mode_size"])
assert manifest["capsule_battery_temperature"]["unit"] == "°C"
assert manifest["capsule_battery_temperature"]["enabled_by_default"] is False
assert entry["isController"] is True, "Controller bundle must be marked for lazy loading"
assert entry["cell"] == "PSLinkCell"
assert entry["bundle"] == info["CFBundleExecutable"] == "RelaxTunePrefs"
assert entry["detail"] == info["NSPrincipalClass"] == "RTRootController"
switches = {item["key"]: item for item in settings if item["cell"] == "PSSwitchCell"}
assert set(switches) == {"Enabled", "Animations", "Network", "TCPNoDelay",
                         "HighRefresh", "ZombieReap",
                         "WakeAnimations", "UnlockAnimations", "TimeCapsuleBatteryTemp"}
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
capsule_links = [item for item in settings if item.get("action") == "rtOpenTimeCapsule:"]
assert len(capsule_links) == 1
assert capsule_links[0]["cell"] == "PSLinkCell"
capsule_group = next(item for item in settings if item.get("label") == "快捷时间胶囊（独立模块）")
assert "独立偏好域" in capsule_group["footerText"]
assert "不受 RelaxTune 总开关影响" in capsule_group["footerText"]
assert "电池温度" in capsule_group["footerText"]
assert switches["TimeCapsuleBatteryTemp"]["default"] is False
assert "实验选项" in capsule_group["footerText"]
assert "空间" in capsule_group["footerText"]
assert not any(item.get("defaults") == "com.zhuifeng.dateinfo" for item in settings)
if len(sys.argv) == 1:
    controller_source = (root / "prefs/RootController.m").read_text(encoding="utf-8")
    assert "rtEditAnimationExclusions:(PSSpecifier *)specifier" in controller_source
    assert "RTAnimationExclusionController" not in controller_source
    assert "_factorStepper.stepValue = 0.1;" in controller_source
    for required in ("[NSBundle bundleForClass:[self class]]",
                     "URLByDeletingLastPathComponent",
                     "URLByAppendingPathComponent:@\"DateInfoPrefs.bundle\"",
                     "loadAndReturnError:",
                     "NSClassFromString(@\"DIRootListController\")",
                     "RTIsPSListControllerSubclass(capsuleControllerClass)",
                     "[NSBundle bundleForClass:capsuleControllerClass]",
                     "isEqual:capsuleBundle.bundleURL.URLByStandardizingPath",
                     "pushViewController:capsuleController animated:YES",
                     "rtShowTimeCapsuleUnavailable"):
        assert required in controller_source, f"Missing safe capsule bridge part: {required}"
    assert "/var/jb" not in controller_source
    tweak_source = (root / "src/Animation.x").read_text(encoding="utf-8")
    # The existing 0.5 implementation preserves the caller's curve/options.
    assert "RTSmoothOptions" not in tweak_source
    assert "%orig(value, wait, options, animations, completion);" in tweak_source
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
