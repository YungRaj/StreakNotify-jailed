MODULES = jailed
include $(THEOS)/makefiles/common.mk

ARCHS = armv7 arm64
export SDKVERSION = 9.0

TWEAK_NAME = StreakNotify
DISPLAY_NAME = Snapchat
BUNDLE_ID = com.toyopagroup.picaboo

StreakNotify_FILES = Tweak.xm SNSettingsViewController.mm Friendmojilist/FriendmojiTableDataSource.m Friendmojilist/FriendmojiListController.m
StreakNotify_PRIVATE_FRAMEWORKS = AppSupport SpringBoardServices
StreakNotify_CFLAGS = -DTHEOS -Wno-deprecated-declarations
StreakNotify_IPA = /Users/ilhan/Downloads/Files/Code/Snapchat/StreakNotify-jailed/Snapchat.ipa

include $(THEOS_MAKE_PATH)/tweak.mk
