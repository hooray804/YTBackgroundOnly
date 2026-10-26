TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTBackgroundOnly

YTBackgroundOnly_FILES = Tweak.x
YTBackgroundOnly_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
