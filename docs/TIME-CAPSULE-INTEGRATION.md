# DateInfo dependency / launcher integration

## Decision and boundaries

RelaxTune 0.5.2 uses DateInfo as a separate package dependency, not as vendored code. `control` requires `com.zhuifeng.dateinfo (>= 1.3.10)`. This keeps the capsule implementation, resources, preferences, and `com.zhuifeng.dateinfo` defaults domain owned by the DateInfo package, while the RelaxTune Settings page adds a convenience link to its settings controller. RelaxTune's `Enabled` switch does not control DateInfo's `Enabled` switch. The only new production runtime code is the separately named, fail-closed battery-temperature companion; existing RelaxTune hooks and filters remain unchanged.

The bridge gets the currently loaded `RelaxTunePrefs.bundle` with `NSBundle bundleForClass:`, finds its adjacent `DateInfoPrefs.bundle` using a relative bundle URL, explicitly loads it, resolves the donor's declared `DIRootListController`, verifies it is a `PSListController` subclass, then pushes it on the current navigation controller. It does not assume `/var/jb`, `/Library`, or another fixed jailbreak prefix. Missing bundle, load/class mismatch, or missing navigation controller produces an alert instead of a crash. This is source-checked only; navigation through a third-party Preference bundle has not been verified on-device.

DateInfo's own `PreferenceLoader/Preferences/DateInfoPrefs.plist` remains installed by the separate dependency. Therefore users will see DateInfo's own Settings entry plus the RelaxTune shortcut; both should lead to the same independent DateInfo preferences. RelaxTune cannot remove or replace the files/entry owned by another package. This differs from an embedded-copy design that would omit the donor entry.

## Dependency and package feed

The package dependency is satisfiable from the maintainer's public package feed:

```text
https://temple002.github.io/zhuifeng/
```

The user must add that source in their package manager and refresh package indexes. This repository does not configure a package manager feed and does not bundle the DateInfo DEB; merely building RelaxTune does not make that feed available. If the source is missing or unreachable, the package manager will report an unresolved dependency and cannot install the RelaxTune package. The public repo at revision `f7f28069c686dc57664bf83b2c7506d1e9d7fb91` advertises DateInfo 1.3.10 for `iphoneos-arm64e` (RootHide), matching this RootHide-only build.

## Source / rights / battery temperature

The candidate public repository is a package feed, not a source repository. Its tracked tree at the revision above contains DEBs, package indexes, depictions, and the repository builder; no DateInfo `.m`, `.mm`, `.x`, `.c`, `.h`, Swift, or tweak `Makefile` source was found. The public description lists date/time, weather, and current network speed. The supplied DateInfo preferences plist includes the original `Enabled`, `AvoidActivity`, weather options, log viewer, respring and donation entries under `com.zhuifeng.dateinfo`. Its settings schema has no battery-temperature option.

Because no donor source was available, RelaxTune 0.5.2 does not alter or repackage DateInfo. Its separately named SpringBoard companion is an experimental opt-in (`TimeCapsuleBatteryTemp`, default OFF) which also obeys RelaxTune's master switch. Before hooking, it checks DateInfo image origin, UIView inheritance, the update method's void return/six arguments, and the timeLabel object getter signature. It preserves the original method call and arguments. Extra UI work is main-thread and visible-only, with at most one real temperature read per second and no resident timer. It appends `电池 %.1f°C` or `电池 --°C` only if the full original-plus-suffix text fits the existing time label at its original font; otherwise it preserves the original time. It does not shrink fonts, enlarge frames, add a footer or edit masks. Own prior appended text is tracked to avoid cumulative suffixes and to allow next-update cleanup when disabled. These are conservative prototype guards, not measured proof of non-overlap on a real donor UI.

The temperature reader resolves the IOKit registry APIs dynamically, reads the real `IOPMPowerSource` `Temperature` `CFNumber`, validates it, converts the documented centi-degree value to Celsius and shows unavailable on failure. It does not use CPU temperature, `thermalState`, guessed values or donor-binary patches. The pure conversion checks and mocked ownership/type tests are present, but actual IORegistry availability, loader ordering, visible label fit and runtime stability have not been tested on a jailbroken device. Therefore this is an experimental source-level companion, not a claim of a universally supported DateInfo layout.

The donor package's `DateInfoPrefs.bundle/Info.plist` reports version `1.3.4`, despite the DEB being version `1.3.10`. It is owned by the separate package and intentionally left untouched. Dependency resolution checks the DEB package version; the bridge uses the known preference bundle path and controller class, not the stale embedded version string.

## Provenance (reference only; no payload copied)

The supplied donor DEB is SHA-256 `8673a62e53237c320e980fc94ad55ab273364c6d607452967de31f3f4546768a`. The reference manifest [TIME-CAPSULE-DONOR-MANIFEST.json](TIME-CAPSULE-DONOR-MANIFEST.json) records all eight payload file hashes, modes, and byte sizes, plus the omitted standalone PreferenceLoader entry hash. It is an audit record only: none of those payloads are copied into this repository or RelaxTune package.

## Verification and limits

`python3 tests/test_preferences.py` checks existing PreferenceLoader metadata and filters, the single RelaxTune entry, 0.5.2 metadata, the dependency, independent settings, relative bundle resolution and class checks, and the absence of DateInfo payload files. The same script accepts a staged package data root to validate the installed layout and no-vendoring boundary:

```sh
python3 tests/test_preferences.py
python3 tests/test_preferences.py /path/to/extracted-package-data
```

The existing full checks should still be run before release (`python3 tests/test_promotion_adapter.py`, `python3 tests/test_animation_fixture_namespace.py`, `python3 tests/test_kernel_script.py`, native core/network/temperature/animation tests, and RootHide Theos build). The workflow trigger includes this branch so GitHub can perform the macOS Theos build; the new companion and cross-bundle navigation still require verification by the owning build/release agent. There has been no jailbroken-device installation or runtime test.
