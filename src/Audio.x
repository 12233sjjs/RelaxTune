#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFAudio/AVFAudio.h>
#import <substrate.h>
#import "Settings.h"
#include "DSP.h"
#include <stdatomic.h>
#include <math.h>

// Callback contexts stay alive until process exit, including after disposal.
// This avoids freeing refCon while an audio callback is still in flight.
#define RT_MAX_CALLBACKS 64
typedef struct {
    AudioUnit unit;
    AURenderCallbackStruct original;
    AudioStreamBasicDescription format;
    RTEqualizer eq;
    atomic_bool active;
    atomic_bool ready;
    atomic_bool running;
    atomic_bool published;
    bool needsReset;
} RTPlayback;

static RTPlayback RTCallbacks[RT_MAX_CALLBACKS];
static atomic_uint RTCallbackCount;
static atomic_bool RTSessionAllowed;

static void RTUpdateSession(void) {
    NSString *category = AVAudioSession.sharedInstance.category;
    BOOL allowed = [category isEqualToString:AVAudioSessionCategoryPlayback] ||
                   [category isEqualToString:AVAudioSessionCategoryAmbient] ||
                   [category isEqualToString:AVAudioSessionCategorySoloAmbient];
    atomic_store(&RTSessionAllowed, allowed);
}

static unsigned RTCount(void) {
    unsigned count = atomic_load(&RTCallbackCount);
    return count < RT_MAX_CALLBACKS ? count : RT_MAX_CALLBACKS;
}

static void RTPrepare(RTPlayback *context) {
    if (atomic_load(&context->running)) return;
    atomic_store(&context->ready, false);
    UInt32 size = sizeof(context->format);
    if (AudioUnitGetProperty(context->unit, kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input, 0, &context->format, &size) != noErr) return;
    AudioStreamBasicDescription f = context->format;
    if (f.mFormatID != kAudioFormatLinearPCM || f.mChannelsPerFrame < 1 || f.mChannelsPerFrame > 2 ||
        f.mFramesPerPacket != 1 || (f.mFormatFlags & kAudioFormatFlagIsBigEndian) ||
        !(f.mFormatFlags & kAudioFormatFlagIsPacked)) return;
    BOOL floating = (f.mFormatFlags & kAudioFormatFlagIsFloat) && f.mBitsPerChannel == 32;
    BOOL integer = !(f.mFormatFlags & kAudioFormatFlagIsFloat) &&
                   (f.mFormatFlags & kAudioFormatFlagIsSignedInteger) && f.mBitsPerChannel == 16;
    UInt32 channelsPerBuffer = (f.mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? 1 : f.mChannelsPerFrame;
    if ((!floating && !integer) || f.mBytesPerFrame != channelsPerBuffer * (f.mBitsPerChannel / 8)) return;
    context->needsReset = true;
    atomic_store(&context->ready, RTEQInit(&context->eq, f.mSampleRate));
}

static OSStatus RTRender(void *refcon, AudioUnitRenderActionFlags *flags,
                         const AudioTimeStamp *time, UInt32 bus, UInt32 frames,
                         AudioBufferList *buffers) {
    RTPlayback *context = refcon;
    OSStatus status = context->original.inputProc(context->original.inputProcRefCon,
                                                 flags, time, bus, frames, buffers);
    BOOL enabled = atomic_load(&RTEnabled) && atomic_load(&RTAudio) &&
                   atomic_load(&RTSessionAllowed) && atomic_load(&context->active) &&
                   atomic_load(&context->ready);
    if (status != noErr || !enabled || !buffers ||
        (flags && (*flags & kAudioUnitRenderAction_OutputIsSilence))) {
        context->needsReset = true;
        return status;
    }
    AudioStreamBasicDescription f = context->format;
    BOOL planar = (f.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    UInt32 expectedBuffers = planar ? f.mChannelsPerFrame : 1;
    UInt32 channels = planar ? 1 : f.mChannelsPerFrame;
    size_t bytesNeeded = (size_t)frames * f.mBytesPerFrame;
    if (buffers->mNumberBuffers != expectedBuffers) return status;
    // Validate every buffer before modifying any samples.
    for (UInt32 b = 0; b < expectedBuffers; b++) {
        if (!buffers->mBuffers[b].mData || buffers->mBuffers[b].mNumberChannels != channels ||
            buffers->mBuffers[b].mDataByteSize < bytesNeeded) return status;
    }
    if (context->needsReset) {
        RTEQReset(&context->eq);
        context->needsReset = false;
    }
    BOOL floating = (f.mFormatFlags & kAudioFormatFlagIsFloat) != 0;
    for (UInt32 b = 0; b < expectedBuffers; b++) {
        void *data = buffers->mBuffers[b].mData;
        for (UInt32 frame = 0; frame < frames; frame++) {
            for (UInt32 c = 0; c < channels; c++) {
                size_t index = (size_t)frame * channels + c;
                unsigned channel = planar ? b : c;
                float input = floating ? ((float *)data)[index] : ((int16_t *)data)[index] / 32768.0f;
                float output = RTEQSample(&context->eq, channel, input);
                if (floating) ((float *)data)[index] = output;
                else ((int16_t *)data)[index] = (int16_t)lrintf(fmaxf(-32768.0f, fminf(32767.0f, output * 32768.0f)));
            }
        }
    }
    return status;
}

static BOOL RTIsPlaybackUnit(AudioUnit unit, AudioUnitPropertyID property,
                              AudioUnitScope scope, AudioUnitElement element) {
    if (property != kAudioUnitProperty_SetRenderCallback || scope != kAudioUnitScope_Input || element != 0) return NO;
    AudioComponent component = AudioComponentInstanceGetComponent(unit);
    AudioComponentDescription description;
    return component && AudioComponentGetDescription(component, &description) == noErr &&
           description.componentType == kAudioUnitType_Output &&
           description.componentSubType == kAudioUnitSubType_RemoteIO;
}

%group RTAudioHooks
%hookf(OSStatus, AudioUnitSetProperty, AudioUnit unit, AudioUnitPropertyID property, AudioUnitScope scope, AudioUnitElement element, const void *data, UInt32 size) {
    if (!atomic_load(&RTEnabled) || !atomic_load(&RTAudio))
        return %orig(unit, property, scope, element, data, size);
    if (!RTIsPlaybackUnit(unit, property, scope, element) || !data ||
        size != sizeof(AURenderCallbackStruct)) return %orig(unit, property, scope, element, data, size);
    AURenderCallbackStruct callback = *(const AURenderCallbackStruct *)data;
    RTPlayback *context = NULL;
    if (callback.inputProc && callback.inputProc != RTRender) {
        unsigned slot = atomic_fetch_add(&RTCallbackCount, 1);
        if (slot < RT_MAX_CALLBACKS) {
            context = &RTCallbacks[slot];
            context->unit = unit;
            context->original = callback;
            RTPrepare(context);
            atomic_store(&context->active, true);
            atomic_store(&context->published, true);
            callback.inputProc = RTRender;
            callback.inputProcRefCon = context;
        }
    }
    OSStatus status = %orig(unit, property, scope, element, &callback, sizeof(callback));
    if (status == noErr) {
        for (unsigned i = 0; i < RTCount(); i++) {
            if (atomic_load(&RTCallbacks[i].published) && RTCallbacks[i].unit == unit &&
                &RTCallbacks[i] != context) atomic_store(&RTCallbacks[i].active, false);
        }
    } else if (context) {
        atomic_store(&context->active, false);
    }
    return status;
}

%hookf(OSStatus, AudioUnitInitialize, AudioUnit unit) {
    for (unsigned i = 0; i < RTCount(); i++) {
        if (atomic_load(&RTCallbacks[i].published) && RTCallbacks[i].unit == unit &&
            atomic_load(&RTCallbacks[i].active)) RTPrepare(&RTCallbacks[i]);
    }
    return %orig(unit);
}

%hookf(OSStatus, AudioOutputUnitStart, AudioUnit unit) {
    if (atomic_load(&RTEnabled) && atomic_load(&RTAudio)) RTUpdateSession();
    for (unsigned i = 0; i < RTCount(); i++) {
        if (atomic_load(&RTCallbacks[i].published) && RTCallbacks[i].unit == unit &&
            atomic_load(&RTCallbacks[i].active)) {
            RTPrepare(&RTCallbacks[i]);
            atomic_store(&RTCallbacks[i].running, true);
        }
    }
    OSStatus status = %orig(unit);
    if (status != noErr) {
        for (unsigned i = 0; i < RTCount(); i++) {
            if (atomic_load(&RTCallbacks[i].published) && RTCallbacks[i].unit == unit)
                atomic_store(&RTCallbacks[i].running, false);
        }
    }
    return status;
}

%hookf(OSStatus, AudioOutputUnitStop, AudioUnit unit) {
    OSStatus status = %orig(unit);
    if (status == noErr) {
        for (unsigned i = 0; i < RTCount(); i++) {
            if (atomic_load(&RTCallbacks[i].published) && RTCallbacks[i].unit == unit)
                atomic_store(&RTCallbacks[i].running, false);
        }
    }
    return status;
}

%hookf(OSStatus, AudioComponentInstanceDispose, AudioComponentInstance unit) {
    OSStatus status = %orig(unit);
    if (status == noErr) {
        for (unsigned i = 0; i < RTCount(); i++) {
            if (atomic_load(&RTCallbacks[i].published) && RTCallbacks[i].unit == unit)
                atomic_store(&RTCallbacks[i].active, false);
        }
    }
    return status;
}
%end

static void RTInstallAudioIfNeeded(void) {
    if (!atomic_load(&RTEnabled) || !atomic_load(&RTAudio)) return;
    RTUpdateSession();
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionRouteChangeNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                if (atomic_load(&RTEnabled) && atomic_load(&RTAudio)) RTUpdateSession();
            }];
        %init(RTAudioHooks);
    });
}

static void RTAudioSettingsChanged(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        RTLoadSettings();
        RTInstallAudioIfNeeded();
    });
}

%ctor {
    @autoreleasepool {
        if (!RTShouldLoadAppHooks()) return;
        NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
        if ([bundle isEqualToString:@"com.apple.springboard"] ||
            [bundle isEqualToString:@"com.apple.mobilephone"] ||
            [bundle isEqualToString:@"com.apple.facetime"] ||
            [bundle isEqualToString:@"com.apple.camera"] ||
            [bundle isEqualToString:@"com.apple.VoiceMemos"]) return;
        RTLoadSettings();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            RTAudioSettingsChanged, CFSTR("com.12233sjjs.relaxtune.changed"), NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        RTInstallAudioIfNeeded();
    }
}
