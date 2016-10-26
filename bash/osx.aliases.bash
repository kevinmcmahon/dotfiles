#!/usr/bin/env bash

# Desktop Programs
alias preview="open -a '$PREVIEW'"
alias xcode="open -a '/Applications/Xcode.app'"
alias chrome="open -a google\ chrome"
alias f='open -a Finder '
alias ded='rm -rf /Users/kevin/Library/Developer/Xcode/DerivedData'

# Show hidden files in Finder
alias showhidden='defaults write com.apple.finder AppleShowAllFiles TRUE && killall Finder'

# Hide hidden files in Finder
alias hidehidden='defaults write com.apple.finder AppleShowAllFiles FALSE && killall Finder'


alias dskill='find . -name .DS_Store -delete'

alias fixbootstrap="launchctl list|grep UIKitApplication|awk '{print $3}'| xargs launchctl remove"

alias fixopenwith='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user'

alias fixmenubar='killall -KILL SystemUIServer'

# Open iOS Simulator
alias ios="open /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone\ Simulator.app"

# Clean up LaunchServices to remove duplicates in the “Open With” menu
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash="sudo rm -rfv /Volumes/\*/.Trashes; sudo rm -rfv $HOME/.Trash/; sudo rm -rfv /private/var/log/asl/\*.asl"

alias secureemptytrash="sudo srm -rfv /Volumes/\*/.Trashes; sudo srm -rfv $HOME/.Trash/; sudo srm -rfv /private/var/log/asl/\*.asl"
