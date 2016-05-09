include theos/makefiles/common.mk

LDFLAGS += -F. -framework Cycript -framework JavaScriptCore -framework Security -current_version 1.0 -compatibility_version 1.0 -framework UIKit -framework CFNetwork

ARCHS = arm64

TWEAK_NAME = StreakNotify
StreakNotify_FILES = Tweak.xm fishhook/fishhook.c iSpy.class.xm iSpy.instance.xm iSpy.msgSend.common.xm iSpy.msgSend.whitelist.xm iSpy.msgSend.xm iSpy.msgSend_stret.xm typestring.xm iSpy.logwriter.xm iSpy.SSLPinning.xm
StreakNotify_CFLAGS = -DTHEOS
StreakNotify_LDFLAGS += -Wl,-segalign,4000

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
