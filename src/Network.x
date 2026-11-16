#import <Foundation/Foundation.h>
#import <substrate.h>
#import <dlfcn.h>
#import "Settings.h"
#include "NetworkPolicy.h"

static int (*RTOriginalSocket)(int, int, int);

static int RTSocket(int domain, int type, int protocol) {
    int fd = RTOriginalSocket(domain, type, protocol);
    RTConfigureNewSocket(fd, domain, type, protocol,
        atomic_load(&RTEnabled) && atomic_load(&RTTCPNoDelay));
    return fd;
}

%ctor {
    @autoreleasepool {
        NSBundle *bundle = NSBundle.mainBundle;
        if (![bundle.bundlePath.pathExtension isEqualToString:@"app"] ||
            [bundle.bundleIdentifier isEqualToString:@"com.apple.springboard"]) return;
        RTLoadSettings();
        void *symbol = dlsym(RTLD_DEFAULT, "socket");
        if (symbol) MSHookFunction(symbol, (void *)&RTSocket, (void **)&RTOriginalSocket);
    }
}
