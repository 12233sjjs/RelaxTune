Target: iPhone 13 Pro, iOS 16.6.1, Relaxin v0.5.6.

Game and display policy update in 0.1.5:

- Add an enabled-by-default low-power exemption for foreground Honor of Kings (`com.tencent.smoba`).
- Restore a suspended manual low-power state on leaving the game, locking, or disabling protection.
- Use `_PMLowPowerMode` on iOS 15+ with completion confirmation and a legacy fallback.
- Add an optional SpringBoard-only 120 Hz display-link preference, disabled by default.
- Restore original frame requests when disabled or in low-power mode.
- Do not withdraw the 120 Hz request based on thermal state; system thermal protections remain in control.
- This is not a CPU/GPU frequency lock or guaranteed 120 FPS; game render loops are unchanged.
- Package the supplied six sysctl values as a manual root-only apply/restore module.
- Skip unsupported keys, retain original values, and attempt rollback on a failed write.
- Do not run kernel writes at installation, startup, or game entry; the 24-hour pressure delay remains experimental.
- No device FPS, thermal, battery, or private-interface validation has been performed.

Battery overhead update in 0.1.4:

- Install audio hooks and route monitoring only after the EQ is enabled.
- Do not wrap new audio callbacks while the EQ or master switch is off.
- Run power-mode checks only in SpringBoard when preferences change.
- Keep ownership-aware lock-screen low-power mode and unlock/charging restoration.
- Enabling EQ for an already-playing app may require restarting that app.
- No device battery-life improvement has been measured.

Display name update in 0.1.3:

- Rename the package and Settings interface to cc优化系统.
- Preserve the package identifier and preference domain for in-place upgrades.

Settings icon and animation precision update in 0.1.2:

- Use the supplied cat silhouette with a transparent background, without the outer circle.
- Include standard, 2x and 3x Settings icons.
- Adjust animation multiplier in 0.01 steps and display two decimal places.

Includes the fixes for the missing Settings entry in 0.1.0:

- Add `isController = true` to the PreferenceLoader entry, matching the Theos preference-bundle template.
- Add the preference domain to each switch definition.
- Validate controller metadata, switch definitions and installed bundle paths in both packages.
- After upgrading, reload SpringBoard and fully reopen Settings.

- Animation toggle and duration multiplier 0.00 through 10.00 in 0.01 steps; default 0.90.
- Screen-off low-power mode with ownership-aware restoration.
- Waiting for connectivity on new default/ephemeral URLSession configurations.
- Experimental RemoteIO playback EQ, disabled by default.

Packages:
- `iphoneos-arm64.deb`: standard rootless, under `/var/jb`.
- `iphoneos-arm64e.deb`: RootHide package scheme, for the Relaxin environment.

Rootless and RootHide packages are alternatives. Install only the format supported by your package manager.

Compilation and automated core checks do not establish device compatibility. No phone testing, latency reduction, battery-life improvement, or all-app audio coverage has been established. EQ does not cover AVPlayer/AudioQueue/system audio paths and is not Dolby.
