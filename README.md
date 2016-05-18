# StreakNotify-Jailed
This version of StreakNotify allows one to install it on a non-jailbroken iDevice. 32 bit binaries are supported only because the theos-jailed fork of the theos framework only supports armv7 binaries only. 

# How to compile
1. Create a provisioning profile from developer.apple.com with a unique App ID
2. Copy the provision profile to the folder in which StreakNotify-jailed is installed
3. Open a terminal window and change to the directory where SN-jailed is installed
4. Run make (with any changes to Makefile that you find necessary)
4. Run ./patchapp.sh patch ./Snapchat-ARMv7.ipa ./Profile.mobileprovision 
5. Install the resulting ipa file using iTunes

A provisioning file containing devices that are approved is necessary to recreate the ipa (using patchapp.sh) that contains the tweak and the needed jailbreak libraries to load it. 