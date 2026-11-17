# Phase Timing And Folder Exclusion 0.4.9

## Confirmed Code Findings

Version 0.4.8 divided eligible UIKit and SBF export durations by acceleration,
but passed their startup delays through unchanged. A 0.5-second animation with
a 0.2-second delay at level 10 therefore played for 0.05 seconds after a full
0.2-second wait. The fix applies the same acceleration divisor to the delay.
UIKit eligibility remains based on the original 0.12-1.0-second duration.
Negative and nonfinite delays pass through; long progress animations keep
their original delay. Source playback-speed handling is unchanged.

Nested UIView calls also received rewritten ease-out and begin-from-current-state
options even though the depth guard prevented a second duration change.
Only the outer call now receives those options. Public spring conversion
keeps its already-scaled delay and duration when entering the ordinary hook.

Neither finding establishes the cause of actual iPhone dropped frames.
No on-device frame-time trace or video comparison was available.

## GitHub Research

- [Speedster](https://github.com/Hoangdus/Speedster/blob/b1bbbf98ac5607ff3280e7568d892ac5b31bdd94/Speedster/Speedster.x)
  claims iOS 13-16 support and uses global SBFAnimationSettings setters for
  folder changes, while acknowledging they can affect other SpringBoard
  animations. We do not copy these global spring-constant changes.
- [SBHFolderZoomSettings, iOS 17](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/SpringBoardHome.framework/SBHFolderZoomSettings.h)
  identifies the folder settings subclass and innerFolderFadeSettings.
- [SBHIconAnimationSettings](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/SpringBoardHome.framework/SBHIconAnimationSettings.h)
  and [SBHScaleZoomSettings](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/SpringBoardHome.framework/SBHScaleZoomSettings.h)
  provide the inherited central/crossfade/icon-grid/outer-folder getters.
  Getter results are marked only for SBHFolderZoomSettings instances.
- [SBFolderIconZoomAnimator, iOS 17](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/SpringBoardHome.framework/SBFolderIconZoomAnimator.h)
  declares _prepareAnimation and the fraction/settings/delay/alreadyAnimating/
  sharedCompletion entry point.
- [_SBInnerFolderIconZoomAnimator, iOS 17](https://github.com/MTACS/iOS-17-Runtime-Headers/blob/d1d960dfaa4107765dd7fcf891e4967c0930d5fd/PrivateFrameworks/SpringBoardHome.framework/_SBInnerFolderIconZoomAnimator.h)
  declares _prepareAnimation and _animateToFraction:afterDelay:withSharedCompletion:.
- The same signatures appear in the
  [iOS 14 outer animator](https://github.com/SparkDev97/iOS14-Runtime-Headers/blob/f1f1b547ae5f6c98a4eb490258276a67aa3d0226/PrivateFrameworks/SpringBoardHome.framework/SBFolderIconZoomAnimator.h),
  [inner animator](https://github.com/SparkDev97/iOS14-Runtime-Headers/blob/f1f1b547ae5f6c98a4eb490258276a67aa3d0226/PrivateFrameworks/SpringBoardHome.framework/_SBInnerFolderIconZoomAnimator.h)
  and [folder settings](https://github.com/SparkDev97/iOS14-Runtime-Headers/blob/f1f1b547ae5f6c98a4eb490258276a67aa3d0226/PrivateFrameworks/SpringBoardHome.framework/SBHFolderZoomSettings.h).

The iOS 16 header repository checked in prior work does not contain
SpringBoardHome. Cross-version header agreement is supporting evidence,
not verification of 16.6.1 coverage. Runtime signatures are checked before
installing these folder-specific hooks. Unknown entry points stay untouched.

## Boundaries

Folder scopes use a thread-local depth with exception cleanup. No global
folder-open flag, asynchronous timer, completion-block replacement or auth
state changes are introduced. Marked folder settings remain native during
later exports, including after the setup scope returns. If the system shares
one marked settings object with unrelated animation owners, that object's
exports also remain native; actual ownership requires device inspection.

Folder timing and curves pass through. The existing independent 120 Hz
request can still be applied to the original settings. Main acceleration,
native zero, 0.1 steps, separate wake/unlock controls, and removal of power
management/thermal overrides remain unchanged.

macOS Logos fixtures validate the actual hook source against mock folder
classes and real QuartzCore/Foundation factories. They do not render iPhone
animations, measure FPS or establish complete private-path coverage.
