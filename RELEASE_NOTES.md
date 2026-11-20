Target: iPhone 13 Pro, iOS 16.6.1, Relaxin.

Startup animation phase timing in 0.4.12:

- Restrict SpringBoard conversion to source durations from 0.12 through 1.0 seconds, matching UIKit eligibility. Preserve shorter and longer phase durations and delays. Scale eligible durations and delays with the same factor without flooring different phases to a shared 0.12-second duration.
- Preserve caller UIKit curves and spring parameters, and pass through the original SpringBoard timing function.
- Keep the configured acceleration level for eligible animations. Fixture tests cover short and long exclusions, range boundaries and curve/spring preservation.
- This preserves relative timing among eligible phases but allows short phases to finish in fewer frames at higher acceleration levels. No iPhone frame-time measurement or device validation is available.

External blacklist self-exclusion removal in 0.4.10:

- Stop reading RootHideConfig.plist and remove the fixed game exclusion from the shared app-hook policy. Once injected, all application bundles are eligible for hooks regardless of RootHide blacklist membership.
- Retain master/module switches and the separate manual animation exclusion list. Do not change the jailbreak injector or RootHide configuration.
- A system-level no-injection blacklist can still prevent the library from loading. This package cannot make in-process hooks run when the injector does not load it. Target-device validation has not been performed.

Phase timing and native folder animations in 0.4.9:

- Scale eligible UIKit startup delays with the same acceleration as duration. Scale exported SpringBoard delay by the acceleration level too, preserving the source delay at level zero. This fixes a demonstrated timing mismatch, not a measured device frame-drop diagnosis.
- Stop rewriting nested UIView animation options or replacing nested public spring calls. Keep the outer conversion's final delay/duration and preserve nested caller curves; do not force repeated begin-from-current-state options at each level.
- Exclude folder-specific central, crossfade, icon-grid and inner/outer fade settings from conversion. Use signature-checked SBFolderIconZoomAnimator and _SBInnerFolderIconZoomAnimator entry points to preserve native UIKit timing within folder animation setup. Settings tags keep later exports native without a global folder-visible flag or timer.
- Keep ordinary App transitions eligible even when launched from a folder. Keep independent 120 Hz requests and wake/unlock controls unchanged; power writes and thermal overrides remain removed.
- Test proportional delays at all 101 levels, native folder open/close settings, nested callbacks, exception cleanup and unaffected ordinary App settings. Private folder headers are available for iOS 14/17, not exact 16.6.1 device proof. Actual path coverage and visual smoothness still require target-device validation.

Remove all automatic low-power management in 0.4.8:

- Remove the Honor of Kings foreground low-power preference, preference reads, foreground hooks, power writes, callbacks, timeout and state restoration. Delete PowerPolicy.c/h and their build inputs.
- Remove the remaining legacy lock-screen ownership cleanup. Existing GamePerformance, GameRestoreLowPower and OwnsLowPower preferences are ignored; upgrading does not write or restore the current low-power mode. Choose the desired state manually in Control Center.
- Retain the removal of lock-screen low-power switching and thermal overrides. iOS still manages its own low-power and thermal behavior. The 120 Hz module only reads system low-power state to choose a display request.
- Keep all three 0..10 acceleration levels, their 0.1 steps and independent wake/unlock switches unchanged.
- Validate both settings and packaged binaries for absence of the removed power/thermal controls, private writers and frameworks. No iPhone device test has been performed.

Independent acceleration levels in 0.4.7:

- Replace the old duration-ratio setting with an acceleration level from 0 to 10 in steps of 0.1. Speed is 1 + 0.9 * level: 0 preserves original speed, 10 is 10x. Apply duration / speed consistently in UIKit and SpringBoard. Remove the additional 0.8 duration multiplier.
- Use a new AnimationAcceleration preference so old duration ratios are not silently interpreted using the reversed meaning. All three acceleration levels start at 0; the previous ratio is retained but ignored.
- Add separate, disabled-by-default wake and unlock acceleration switches and levels. They share only the master switch, Reduce Motion and animation exclusion policy, and do not depend on the main animation switch or 120 Hz option.
- Multiply the computed SBScreenWakeAnimationController wake speed once, after the system combines wake and lift-to-wake factors. Fall back to only the SBFWakeAnimationSettings wake factor if the final-speed method is unavailable. Keep underlying wake/sleep settings and the wake animation scope out of main animation scaling.
- Apply unlock timing to identified lock-screen wallpaper settings and the animated CoverSheet dismissal completion path while the lock screen is visible/locked. Convert its noninteractive spring completion to ease-out using the system spring's settling time as the baseline. Do not change authentication or finger tracking. Runtime method signatures are checked before installing these private hooks.
- Deliver preference reload notifications immediately. Do not mutate saved animation settings during a lock/unlock cycle.
- Extend Objective-C fixtures to test all 101 levels, independent switches, native zero, disabled state, callbacks, repeated evaluation and context cleanup. These are runtime fixtures on macOS, not iPhone tests. CoverSheet entry points are private and still need iOS 16.6.1 device validation.
- Retain the 0.4.6 removal of lock-screen low-power switching and thermal override modules.

Lock-screen power and thermal module removal in 0.4.6:

- Remove the screen-off low-power feature, its preference and battery-state monitoring. Locking no longer enables low-power mode through this feature.
- Remove the pocket and sunlight thermal preference rows and all SBPocketStateMonitor/SBThermalController hooks. Apple system thermal management remains active.
- Preserve the separate Honor of Kings foreground power option. Suspend its writes while locked, including game-exit restoration; resume evaluation after unlocking. Read current lock state before each decision to avoid relying on notification order.
- On upgrade, consume the old OwnsLowPower marker and make at most one cleanup write when the old feature owned an enabled mode and no suspended manual mode needs restoring. Preserve modes without that ownership marker. A failed cleanup is logged and is not retried automatically.
- Stop retrying timed-out power writes in a loop and ignore late completion callbacks. Future game or preference events can evaluate the game policy again.
- Keep animation formulas and 120 Hz requests unchanged. This removes a confirmed power-mode interference path; the reported inverse ratio and lock/unlock animation-speed symptoms have not been validated on an iPhone.
- Add regression checks for locked-state no-op, legacy/manual power decisions and absence of removed thermal/power hooks in both packages.

Animation application fixes in 0.4.5:

- Fix a concrete no-op: the iOS 16 BSAnimationSettings factory returns an immutable object without setSpeed:. The old code silently skipped the speed write; its double setter cast also did not match the mutable class float setter. Pass the scaled duration into the immutable factory instead.
- Install ordinary UIView animation hooks in SpringBoard as well as apps. Add duration-based UIViewPropertyAnimator initializers and the running factory, using non-spring ease-out timing and a shared nesting guard against double scaling. Preserve callbacks, delays and animator identity/lifecycle.
- Explicitly include com.apple.springboard in the injection filter alongside UIKit. This is a coverage precaution, not evidence that the old filter failed on the device.
- Keep the 0.4.4 speed multiplier, user settings and 120 Hz behavior. No global fluid-response or Core Animation speed hook is introduced.
- Add runtime regression tests that install the production Logos hook source on Objective-C fixtures, reproduce the immutable-object no-op, and verify forwarded values, nested scaling, callbacks, exclusions, disabled state and Reduce Motion. These are macOS fixtures, not iOS device tests.
- The missing property-animator hooks and immutable settings write are confirmed code defects. Their contribution to the reported device symptom remains unmeasured; jailbreak injection, other tweaks and private fluid transitions still require device evidence.

Faster ease-out transitions in 0.4.4:

- Reduce controlled UIKit animation durations by 20% at the same user factor (0.30 s becomes 0.24 s at factor 1.00). Apply the equivalent playback-speed change to the existing SpringBoard conversion, subject to its existing 0.1..10 speed bounds.
- Keep the non-spring ease-out curve and BeginFromCurrentState behavior. Transition geometry, opacity targets, delays, and 120 Hz configuration are unchanged.
- Keep the saved/default animation factor (default 1.00, range 0..10, step 0.01). At factor 1.25, duration scaling matches factor 1.00 in 0.4.3 for the controlled paths. Existing factor-zero semantics are unchanged.
- Cache the current process animation exclusion when settings load/reload instead of reading preferences and scanning the list on every animation call. Settings notifications refresh this cache.
- UIKit scaling remains limited to the existing 0.12..1.0 second input range. No new private transition hooks are added.
- No iPhone frame-time measurements or device animation tests have been performed; faster scheduling does not establish higher FPS or smoother rendering.

Ease-out animation timing in 0.4.3:

- Preserve transition geometry and opacity targets. Use the system ease-out curve for a responsive start and gradual deceleration at the end, without adding a crossfade.
- Apply the curve to the existing SpringBoard non-spring settings conversion and UIKit duration APIs, including the two convenience overloads.
- Keep animation-factor scaling and the independent 120 Hz configuration unchanged. No PerformanceTweak binary or hooks are included.
- Respect the animation switch, Reduce Motion and the current process animation exclusion for duration/options as well as spring conversion. Preserve nested spring conversion state.
- Does not cover every private transition, interactive gesture animator or animation API. Device appearance, folder opening and interrupted transitions still require iOS 16.6.1 testing.

Optional TCP small-packet latency setting in 0.4.2:

- Add TCPNoDelay, off by default and gated by the master switch. Set TCP_NODELAY once on new IPv4/IPv6 TCP sockets created through the hooked socket symbol in injected app processes.
- Preserve socket results and errno, ignore option failures, and allow subsequent app setsockopt calls to override the initial choice. No connection retries or traffic capture.
- Exclude SpringBoard and non-app processes from this hook. UDP/QUIC, system networking services and paths bypassing socket are not covered.
- Existing sockets retain their options; fully quit and reopen the app after changing the switch for a clean comparison.
- Disabling Nagle can help small TCP writes but can increase packet overhead and battery use. It does not boost radio signal, remove carrier limits or guarantee download/game improvements. No global priority override is installed.
- Tests exercise real local TCP sockets on Linux and macOS; no iPhone latency, throughput or battery measurements have been performed.

Non-spring UIKit timing update in 0.4.1:

- Apply the explicit ease-in-out curve when converting UIView spring API calls to non-spring animations; retain existing duration, delay, and non-curve options.
- Leave the animation speed multiplier and all 120 Hz behavior unchanged.
- This changes timing only; it does not provide alpha fade for SpringBoard app launch or app switching.
- No device animation validation has been performed.

Animation exclusion action fix in 0.4.0:

- Bind the Settings row through the Preferences `action` selector instead of `detail`, so tapping it invokes the in-place list editor rather than attempting controller navigation.
- Keep fade-style SpringBoard launch/app-switch transitions out of this change; iOS 16.6.1 private transition targets have not been verified, and changing SBFAnimationSettings does not alter view alpha.
- No device Settings or animation validation has been performed.

Animation exclusion settings crash fix in 0.3.9:

- Replace navigation to an unsupported custom Preferences child controller with an in-place action sheet flow on the existing PSListController.
- Keep adding and removing Bundle IDs in the animation-only exclusion preference.
- No device Settings launch or exclusion-list UI validation has been performed.

Animation exclusion list and audio module removal in 0.3.8:

- Add a Settings list for app Bundle IDs whose UIKit and SpringBoard animation adjustments should be skipped; edits apply through the existing preferences notification.
- Do not consult the Relaxin blacklist for animation decisions. The local exclusion list affects animation hooks only.
- Remove the experimental audio tweak from the package and its Settings switch; retain source files outside the build target.
- No device UI, launch, app-switching, audio-removal, or stability validation has been performed.

SpringBoard animation loading fix in 0.3.7:

- Fix the main tweak's process gate: SpringBoard is not an `.app` bundle, so the previous app-only check returned before installing any SpringBoard animation hooks.
- Load the main animation tweak in SpringBoard and application bundles; do not apply the Relaxin app blacklist to this main tweak as requested.
- Leave the independent refresh-rate and audio tweak loading gates unchanged.
- This enables the existing SpringBoard speed and non-spring animation settings hook; it does not convert launch or app-switch visuals into a fade transition.
- No device launch, app-switching, fade, folder, or stability validation has been performed.

SpringBoard speed-only smoothing update in 0.3.6:

- Apply the animation multiplier to SpringBoard playback speed only; keep the native duration and ease-in-out non-spring timing unchanged to avoid double scaling on app launch and app switching.
- Bound playback speed to 0.1x through 10x; 1.00x preserves the source speed and 0.00x uses the capped maximum speed.
- Leave all 120 Hz behavior unchanged.
- No device launch, app-switching, folder, or playback-speed validation has been performed.

Smooth non-spring transition update in 0.3.5:

- Use an explicit ease-in-out curve for option-based app and SpringBoard transitions, preserving existing non-curve options and continuing interrupted animations from their current state.
- Keep the 120 Hz request independent from animation conversion and duration scaling.
- No device animation, folder, or launch-transition validation has been performed.

Independent 120 Hz and transition continuity update in 0.3.4:

- Decouple 120 Hz from the master switch, animation toggle and animation duration multiplier; only the 120 Hz preference and low-power mode affect it.
- Apply the 120 Hz frame-range request to original animations even when animation conversion is disabled.
- Preserve the original SBFAnimationSettings speed when creating non-spring ease-in-out transitions.
- Keep BeginFromCurrentState for option-based UIView transitions and original delay/duration values for smoother interruption and handoff.
- No device 120 Hz or transition-continuity validation has been performed.

Global 120 Hz animation update in 0.3.3:

- Enable the 120 Hz preference by default.
- Request CAFrameRateRange 120/120/120 and a high-frame-rate reason for SBFAnimationSettings-based transitions, including app launch/loading and folder transitions.
- Keep non-spring ease-in-out timing for those transitions.
- Remove thermal-state gating from the 120 Hz preference as requested; low-power mode can still cap refresh.
- This increases heat and battery use during sustained animation and is not a thermal-safe configuration.
- No device 120 Hz or loading-animation validation has been performed.

Low-power write and animation overhead hardening in 0.3.2:

- Add a three-second timeout and serial guard to low-power mode writes so a missing completion callback cannot leave power-mode changes permanently blocked.
- Retry power policy evaluation after a timed-out write, including unlock/charging restoration.
- Cache the BSAnimationSettings factory class, selector and ease-in-out timing function instead of resolving them for every transition.
- These changes reduce the chance of a stuck low-power/downclock state and lower SpringBoard animation conversion overhead.
- No device power, thermal or frequency validation has been performed.

Thermal throttling mitigation in 0.3.1:

- Stop forcing SBThermalController isInSunlight to YES; the "锁定阳光暴晒" switch now only suppresses SpringBoard thermal level/blocked responses and leaves the real sunlight state visible to other system components.
- Remove the global SBFFluidBehaviorSettings conversion that replaced every fluid interaction with a fixed 0.3-second animation, reducing continuous animation load and heat.
- Keep the duration-based non-spring conversion for SBFAnimationSettings transitions.
- Make the 120 Hz preference yield to Serious/Critical thermal state and react to thermal-state changes.
- These changes target automatic throttling caused by forced sunlight state, excessive fluid animation and 120 Hz heat.
- No device thermal or frequency validation has been performed.

Global non-spring transition update in 0.3.0:

- Convert UIView spring animations to ease-in-out non-spring transitions in apps and SpringBoard.
- Export SpringBoard SBFAnimationSettings and SBFFluidBehaviorSettings as duration-based BSAnimationSettings with ease-in-out timing, removing spring bounce globally.
- Default the animation duration multiplier to 1.00; changing it scales the non-spring transition duration.
- Keep BeginFromCurrentState for option-based UIView transitions so interrupted animations continue from the visible state.
- Add a top-right "注销" button in Settings; it posts a Darwin notification and lets SpringBoard restart itself.
- Turning off "调整动画" restores native spring behavior.
- No device animation, folder or respring validation has been performed.

0.2.0-based non-spring transition update in 0.2.5:

- Use the 0.2.0 feature set as the base, retaining the thermal toggles and battery-related switches.
- Convert app-level UIView spring animations to non-spring ease-in-out transitions with no bounce.
- Apply BeginFromCurrentState to option-based UIView transitions so interrupted animations continue from the current visible state.
- Keep SpringBoard folder and app-launch transitions native; no global SpringBoard spring settings are modified.
- Keep zombie reaping disabled by default because it can interfere with SpringBoard child handling.
- No device animation or folder validation has been performed.

Non-spring smooth animation update in 0.2.4:

- Leave UIView spring animations untouched so system spring curves remain native.
- Accelerate only non-spring UIView duration animations.
- Use an ease-in-out curve and BeginFromCurrentState for option-based UIView animations so interrupted transitions continue smoothly.
- SpringBoard folder and app-launch transitions remain stock; no global SpringBoard spring settings are modified.
- No device animation smoothness or dropped-frame measurement has been performed.

Folder transition stability rollback in 0.2.3:

- Remove the global SpringBoard SBFAnimationSettings speed hook and SBFFluidBehaviorSettings response hook so folder open/close transitions use stock timing.
- Revert the 0.2.1 120 Hz duration alignment and BeginFromCurrentState changes; app animation scaling returns to the 0.1.7 duration behavior.
- Keep app-launch and system folder spring animations native; app-internal UIView animations remain adjustable.
- Change zombie reaping to disabled by default; it remains an opt-in switch under 网络与电池.
- If folder opening still fails, disable the two thermal switches and the zombie reaping switch, then restart SpringBoard.
- No device folder or animation validation has been performed.

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
