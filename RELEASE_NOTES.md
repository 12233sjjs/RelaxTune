Target: iPhone 13 Pro, iOS 16.6.1, Relaxin v0.5.6.

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
