Target: iPhone 13 Pro, iOS 16.6.1, Relaxin v0.5.6.

Fixes for the missing Settings entry in 0.1.0:

- Add `isController = true` to the PreferenceLoader entry, matching the Theos preference-bundle template.
- Add the preference domain to each switch definition.
- Validate controller metadata, switch definitions and installed bundle paths in both packages.
- After upgrading, reload SpringBoard and fully reopen Settings.

- Animation toggle and duration multiplier 0.0 through 10.0 in 0.1 steps; default 0.9.
- Screen-off low-power mode with ownership-aware restoration.
- Waiting for connectivity on new default/ephemeral URLSession configurations.
- Experimental RemoteIO playback EQ, disabled by default.

Packages:
- `iphoneos-arm64.deb`: standard rootless, under `/var/jb`.
- `iphoneos-arm64e.deb`: RootHide package scheme, for the Relaxin environment.

Rootless and RootHide packages are alternatives. Install only the format supported by your package manager.

Compilation and automated core checks do not establish device compatibility. No phone testing, latency reduction, battery-life improvement, or all-app audio coverage has been established. EQ does not cover AVPlayer/AudioQueue/system audio paths and is not Dolby.
