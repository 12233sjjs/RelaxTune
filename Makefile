ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME ?= roothide

# The imported provider is the supplied arm64e RootHide binary, not a rebuilt
# rootless module. Do not silently package it as a standard rootless build.
ifneq ($(THEOS_PACKAGE_SCHEME),roothide)
$(error This ProMotion120 integration requires THEOS_PACKAGE_SCHEME=roothide)
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RelaxTune
RelaxTune_FILES = src/Tweak.x src/Animation.x src/Refresh.x src/Network.x src/Settings.m src/TimeCapsuleBattery.x src/RTBatteryTemperature.m
RelaxTune_FRAMEWORKS = UIKit QuartzCore Foundation CoreFoundation
RelaxTune_CFLAGS = -Isrc
RelaxTune_OBJCFLAGS = -fobjc-arc

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
RelaxTune_CFLAGS += -DRT_ROOTHIDE=1
RelaxTune_LDFLAGS += -lroothide
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
