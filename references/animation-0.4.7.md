# Animation Acceleration 0.4.7

## Requested Semantics

Main, wake and unlock settings each use a level in [0, 10], rounded to 0.1.
Speed = 1 + 0.9 * level, and duration = source duration / speed. Level 0
preserves source speed, level 10 is the maximum 10x. The main module retains
its existing non-spring ease-out curve even at level 0; lock-specific modules
pass through at level 0 or when their independent switches are off.

The old AnimationFactor duration ratio is not read. New levels default to 0
so an old value of 0 (previously immediate) cannot become an unintended mode.
The three level keys and two new toggles are stored independently.

## Open Source And Headers

- [Speedster](https://github.com/Hoangdus/Speedster/blob/b1bbbf98ac5607ff3280e7568d892ac5b31bdd94/Speedster/Speedster.x)
  uses SBFWakeAnimationSettings speedMultiplierForWake and
  speedMultiplierForLiftToWake. Its README claims iOS 13-16 support. We use
  its wake getter only as a fallback, with relative scaling and zero passthrough.
- [iOS 16 SBFWakeAnimationSettings](https://github.com/qingralf/iOS16-Runtime-Headers/blob/419e481cabff3393288aaa436f2d98e27bc2ed57/PrivateFrameworks/SpringBoardFoundation.framework/SBFWakeAnimationSettings.h)
  confirms double return types and the wake/content/wallpaper getters.
- [iOS 16 UIView](https://github.com/qingralf/iOS16-Runtime-Headers/blob/419e481cabff3393288aaa436f2d98e27bc2ed57/PrivateFrameworks/UIKitCore.framework/UIView.h)
  confirms _animateUsingSpringWithTension:friction:interactive:animations:completion:.
- [Wake controller header](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/SpringBoard.framework/SBScreenWakeAnimationController.h)
  and [iOS 17.6.1 implementation](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/SpringBoard.framework/SBScreenWakeAnimationController.m)
  identify the final _animationSpeedForBacklightChangeSource:isWake: method.
  The system multiplies wake and lift-to-wake factors, so hooking both would
  compound acceleration. Adjust the final speed once when its runtime signature
  matches; otherwise adjust only the common wake getter. A thread-local wake
  scope excludes setup animations from main scaling; sleep speed is unchanged.
- [LockScreenRestore](https://github.com/aronsz26/LockScreenRestore/blob/03841a562732234c84785411837a3cbbad383ecb/Tweak.xm)
  uses CoverSheet transition settings on iOS 16. Its README reports tests on
  iPhone 13 Pro/iOS 16.1.1; this is upstream evidence, not our device validation.
- [iOS 17 CoverSheet sliding controller header](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/SpringBoard.framework/SBCoverSheetSlidingViewController.h)
  and [iOS 17.6.1 implementation](https://github.com/SuperChaoM/iPhone15-3_17.6.1_21G101_Restore/blob/95df6b804bee0e01538eb2ddad0413609938d063/System/Library/PrivateFrameworks/SpringBoard.framework/SBCoverSheetSlidingViewController.m)
  show the completion path through _finishTransitionToPresented:animated:withCompletion:
  and the tension/friction animation. This is not proof of its behavior on 16.6.1.
- [iOS 14 CSLockScreenSettings](https://github.com/SparkDev97/iOS14-Runtime-Headers/blob/f1f1b547ae5f6c98a4eb490258276a67aa3d0226/PrivateFrameworks/CoverSheet.framework/CSLockScreenSettings.h)
  and iOS 17 headers list the four unlock wallpaper settings getters. Only
  install them if their actual runtime signatures match; do not invent replacements.

## Limits

CoverSheet also presents Notification Center. The completion scope is limited
to animated dismissal while SBLockScreenManager reports isUILocked or
isLockScreenVisible. Unknown lock state leaves the completion path native.
It is not an authentication bypass and does not accelerate Face ID, passcode
checks, app loading or physical display wake.

No global CAAnimation speed, layer speed, fluid response, spring constants,
thermal state or low-power state is modified by the new animation controls.
The CASpringAnimation object is used only to calculate a baseline settling
duration; the replacement itself is a non-spring ease-out UIView animation.

The 120 Hz module remains independent. Actual frame rate, transition coverage,
interrupted gestures and visual smoothness require an iOS 16.6.1 device.
