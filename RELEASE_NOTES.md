Target: iPhone 13 Pro, iOS 16.6.1, Relaxin v0.5.6.

Spring speed regression fix in 0.2.2:

- Fix SBFAnimationSettings speed direction: multiplier values below 1 now increase spring speed instead of slowing it down.
- Values above 1 slow spring playback proportionally; 0 is capped at 10x speed to avoid a stalled folder transition.
- This restores folder and app-launch spring responsiveness; 0.2.1 frame alignment and interruption handling remain.
- If stutter persists, turn off the thermal toggles and zombie reaping before testing again.

Animation smoothness update in 0.2.1:

- Frame-align accelerated UIView animation durations to 120 Hz on ProMotion devices, with a 60 Hz fallback.
- Keep the requested animation multiplier while avoiding fractional display-frame durations.
- Add BeginFromCurrentState to option-based UIView animations so interrupted transitions continue from the visible state.
- Spring behavior keeps its shape; only playback speed changes.
- No device animation smoothness or dropped-frame measurement has been performed.

Thermal state toggles in 0.2.0:

- Add a disabled-by-default "禁用口袋高温" switch: SBPocketStateMonitor reports out-of-pocket and forwards pocket updates as out-of-pocket.
- Add a disabled-by-default "锁定阳光暴晒" switch: SBThermalController reports isInSunlight as YES while SpringBoard thermal level and blocked state are reported as nominal, avoiding SpringBoard-side throttling from the forced sunlight state.
- This does not disable kernel, hardware, thermalmonitord or per-app thermal protection.
- Forcing sunlight state is an explicit override and is not a cooling or battery optimization.
- No device thermal, frequency or stability validation has been performed.

Zombie reaping update in 0.1.9:

- Add an enabled-by-default option to reap SpringBoard zombie child processes every five seconds.
- Reaps only terminated children of the SpringBoard process with WNOHANG, preventing PID exhaustion without touching running processes.
- Add a "自动清理僵尸进程" switch under 网络与电池; disabling it cancels the timer.
- No device PID-count or stability measurement has been performed; reaping consumes exit statuses SpringBoard has not read itself.

App launch animation update in 0.1.8:

- Apply the animation duration multiplier to SpringBoard's SBFAnimationSettings speed, which covers the app-open icon zoom and home screen spring animations.
- Keep the spring curve shape unchanged; only playback speed scales.
- Honor the existing animation switch, Reduce Motion and 0.00-10.00 multiplier behavior.
- No device launch-latency or animation measurement has been performed.

Relaxin blacklist integration in 0.1.7:

- Read RootHideConfig.plist through jbroot in RootHide packages before installing plugin hooks.
- Exclude app identifiers whose appconfig values are true; preserve the fixed Honor of Kings exclusion.
- Use the shared entry policy for the main, audio and SpringBoard refresh modules.
- Keep the blacklist read-only. Standard rootless packages retain only the fixed game exclusion.
- Missing, unreadable or malformed configuration does not activate the extra exclusions.
- Changes require fully quitting and reopening the affected app.
- RootHide itself controls pre-launch injection. This additional check cannot unload dylibs or guarantee anti-cheat compatibility.
- Add Foundation-based tests for exclusion matching, plist booleans and malformed data.
- Device configuration access, injection behavior and game compatibility remain untested.

Game exclusion update in 0.1.6:

- Exclude Honor of Kings (`com.tencent.smoba`) from the main and audio plugin initialization.
- Do not install animation, network or audio hooks, or register plugin observers in the game process.
- Preserve foreground-game low-power management in SpringBoard and the SpringBoard-only 120 Hz option.
- Fully quit and reopen the game after upgrading to remove hooks from the old process.
- This does not modify the Relaxin/RootHide blacklist or prevent the injector from loading the dylibs.
- No device or anti-cheat compatibility validation has been performed.

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
