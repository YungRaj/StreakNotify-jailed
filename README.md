# StreakNotify
A jailbreak tweak that specifies to the user everything about Snapchat streaks and is an extension to tweaks that don’t take advantage of this feature of Snapchat. If you snap a lot of people, this is what you’ll want for sure.

A clock/timer emoji and time remaining will show up on your feed for any streak that you have currently going with another user

Notifications will be pushed based on intervals that you specify in settings

Custom Friends allows notifications to be enabled for those specified in Friendmojilist settings 

Auto Reply allows Snaps to be sent automatically to those when notifications are delivered

# How to Install
1. Remove Snapchat if you have it installed
2. Download a decrypted version of Snapchat via Google for version v10.x.x or above
3. Clone this project using git clone http://github.com/YungRaj/StreakNotify-jailed in Terminal
4. Set Snapchat .ipa file to .zip and unarchive
5. Copy StreakNotify-install folder contents to Payload/Snapchat.app
6. Copy PhantomLite http://github.com/CokePokes/PhantomLite contents to Payload/Snapchat.app
7. Open the Snapchat binary in Payload/Snapchat.app/Snapchat in iHex or some binary editor
8. Replace every instance of the string "/usr/lib/libSystem.B.dylib" to "@executable_path/Sys.dylib" and save changes to file
9. Select folder that contains Snapchat.app and zip it. Change the .zip to .ipa
10. Install ipa file with Cydia Impactor at http://www.cydiaimpactor.com <br /> <br />

Snapchat.app Directory Contents should look like
```ruby
/Snapchat.app/
             Frameworks/CydiaSubstrate.framework
             Sys.dylib
             PhLite
             libloader/
                       CydiaSubstrate.framework
                       genghisChron.dylib
                       StreakNotify.dylib

```

# For Power Users only
Note: You might notice that you will have two instances of CydiaSubstrate within Snapchat.app, one in Snapchat.app/Frameworks and Snapchat.app/libloader. <br /> <br />
You can change the executable path using iHex within genghisChron.dylib's LC_LOAD_DYLIB load command pointing to CydiaSubstrate.framework, change it to @executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate, and then remove the CydiaSubstrate.framework in libloader to avoid having both installed in different directories. <br /> <br />
I do not explain this in the original directions because it probably won't be something that regular users know how to do. <br />


# Note:
beta-testing branch is for beta testing the tweak… now is default branch for SN

# Known issues
Auto Reply IS NOT WORKING, reverse engineering Snapchat’s API’s is hard <br />
Snapchat updates cause selectors used for models become deprecated (UPDATE TO UPDATE) <br />
No caption insertion for auto reply in Preferences Bundle (FIXED) <br />
Choose image is dead in the Preferences Bundle (FIXED) <br />
Daemon not loading because of permissions issues (FIXED) <br />
FriendmojiList custom friends crashing (FIXED) <br />
/var/root/Documents folder missing on some devices (FIXED) <br />
Crashes before saving preferences and launching the app (FIXED) <br />
Random but not frequent crashes on cellForRowAtIndexPath: (FIXED)



