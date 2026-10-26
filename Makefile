TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = YouTube
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTBackgroundOnly
YTBackgroundOnly_FILES = Tweak.x
YTBackgroundOnly_CFLAGS = -fobjc-arc
YTBackgroundOnly_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
