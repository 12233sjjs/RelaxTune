ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RelaxTune RelaxTuneAudio
RelaxTune_FILES = src/Tweak.x src/Refresh.x src/Settings.m src/PowerPolicy.c
RelaxTune_FRAMEWORKS = UIKit QuartzCore Foundation
RelaxTune_CFLAGS = -Isrc
RelaxTune_OBJCFLAGS = -fobjc-arc

RelaxTuneAudio_FILES = src/Audio.x src/Settings.m src/DSP.c
RelaxTuneAudio_FRAMEWORKS = UIKit Foundation AudioToolbox AVFAudio
RelaxTuneAudio_CFLAGS = -Isrc
RelaxTuneAudio_OBJCFLAGS = -fobjc-arc

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
RelaxTune_LDFLAGS += -lroothide
RelaxTuneAudio_LDFLAGS += -lroothide
RelaxTunePrefs_LDFLAGS += -lroothide
endif

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = RelaxTunePrefs
RelaxTunePrefs_FILES = prefs/RootController.m
RelaxTunePrefs_INSTALL_PATH = /Library/PreferenceBundles
RelaxTunePrefs_PRIVATE_FRAMEWORKS = Preferences
RelaxTunePrefs_FRAMEWORKS = UIKit Foundation
RelaxTunePrefs_CFLAGS = -fobjc-arc -Isrc
RelaxTunePrefs_LDFLAGS += -F$(THEOS_PROJECT_DIR)/work/frameworks
RelaxTunePrefs_RESOURCE_DIRS = prefs/Resources

include $(THEOS_MAKE_PATH)/bundle.mk
