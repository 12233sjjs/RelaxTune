#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import "Settings.h"

// ProMotion120 1.0.14-1 is the unmodified, user-supplied RootHide module.
// Its Filter targets a deliberately nonmatching bundle, avoiding ordinary
// auto-injection (not a security boundary against an external loader). Explicit
// loading here makes the existing master/HighRefresh preferences control hook
// installation without stacking the old hooks.
// Substrate hooks and the module's persistent keepalive cannot safely be removed
// by dlclose. Changing either switch requires restarting SpringBoard and apps.
void RTRefreshRateDidChange(void) {
    // Deliberately no live uninstall/reinstall of an already active hook set.
}

%ctor {
    @autoreleasepool {
        RTLoadSettings();
        if (!atomic_load(&RTEnabled) || !atomic_load(&RTHighRefresh)) return;
        // Same directory preserves the provider's @loader_path/.jbroot imports.
        // The provider performs its own supported-model and process checks.
        (void)dlopen("@loader_path/RelaxTuneProMotion120.dylib", RTLD_NOW | RTLD_LOCAL);
    }
}
