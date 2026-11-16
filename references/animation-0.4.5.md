# Animation application investigation

The user confirmed 0.4.4 was installed, SpringBoard restarted, Animations enabled,
and AnimationFactor set to 1.00. Both app and SpringBoard transitions looked unchanged.

## Confirmed code defects

1. The existing factory creates BSAnimationSettings, then RTSetAnimationSpeed checks
   for setSpeed:. iOS 16 declares BSAnimationSettings.speed readonly. The setter is
   on BSMutableAnimationSettings and takes float, not the old double cast. Thus the
   immutable-factory path does not apply the user factor or 0.8 acceleration.
2. UIView duration hooks were in the app-only RTApps group. SpringBoard installed
   the UIView spring overload but not the ordinary duration overloads.
3. UIViewPropertyAnimator had no hooks at all. Calls through these APIs did not
   reach the existing duration/curve policy. This is a coverage gap, not proof that
   every app animation uses this class.

## Sources checked on 2026-11-16

- iOS 16 runtime declarations at commit 419e481cabff3393288aaa436f2d98e27bc2ed57:
  https://github.com/qingralf/iOS16-Runtime-Headers/blob/419e481cabff3393288aaa436f2d98e27bc2ed57/PrivateFrameworks/BaseBoard.framework/BSAnimationSettings.h
  https://github.com/qingralf/iOS16-Runtime-Headers/blob/419e481cabff3393288aaa436f2d98e27bc2ed57/PrivateFrameworks/BaseBoard.framework/BSMutableAnimationSettings.h
- Open-source Speedster (README advertises iOS 13-16) uses distinct fluid-response,
  folder-settings and CASpringAnimation paths. It demonstrates that the existing
  SBF export hook is not comprehensive. No Speedster implementation was copied:
  https://github.com/Hoangdus/Speedster/blob/b1bbbf98ac5607ff3280e7568d892ac5b31bdd94/Speedster/Speedster.x
- Public UIViewPropertyAnimator APIs and class declaration:
  https://github.com/nst/iOS-Runtime-Headers/blob/master/PrivateFrameworks/UIKitCore.framework/UIViewPropertyAnimator.h

## Fix and evidence boundary

Pass final duration into the immutable factory. Keep delay and timing function.
Do not mutate the source settings or use an ABI-mismatched setter. Fail back to the
original result for an absent/mismatched factory or invalid duration/delay.

Use a shared animation module in apps and SpringBoard, add duration-based property
animators, and keep nested calls from scaling twice. Explicitly target SpringBoard
in the injection plist. No assertion is made that UIKit filtering was broken.

tests/test_animation_hooks.m installs src/Animation.x through the Logos internal
generator on macOS Objective-C fixtures. It exercises actual replacement dispatch,
including an immutable BS fixture. It cannot validate UIKit internals, actual device
method selection, firmware thermal/frame behavior, jailbreak injection, or visual
smoothness. In particular, fluid interactive transitions and third-party game/render
engines remain outside the tested paths.
