# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"

# Android logcat alias
alias clogcat='"$ANDROID_HOME/platform-tools/adb" logcat | ~/Tools/coloredlogcat.py'

# Shortcuts
alias d="cd ~/Dropbox"
alias dl="cd ~/Downloads"
alias p="cd ~/Projects"
alias g="git"
alias v="vim"
alias m="mate ."
alias o="open ."
alias work="cd ~/work"
alias apps="cd ~/Projects/apps"
alias cls="clear"
alias bex='bundle exec'

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

alias ll='ls -lHG'
alias la='ls -laHG'
alias ..='cd ..'
alias ...='cd ../..'

# git aliases
alias g='git'
alias gp='git pull --rebase'
alias gm='git merge --no-ff'
alias gl="git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gs='git st'
alias ga='git add'
alias stash='git stash'
alias pop='git stash pop'

alias reload='source $HOME/.bash_profile'

alias rmorig='find . -name "*.orig" -print0 | xargs -0 rm -rf'

alias ded='rm -rf /Users/kevin/Library/Developer/Xcode/DerivedData'

alias fixbootstrap="launchctl list|grep UIKitApplication|awk '{print $3}'| xargs launchctl remove"

alias fixopenwith='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user'

# Show hidden files in Finder
alias showhidden='defaults write com.apple.finder AppleShowAllFiles TRUE && killall Finder'

# Hide hidden files in Finder
alias hidehidden='defaults write com.apple.finder AppleShowAllFiles FALSE && killall Finder'

alias mp='cd /Users/kevin/Projects/apps/markerpal/'

alias kitkat='/Applications/Android\ Studio.app/sdk/tools/emulator -avd N4_KITKAT -netspeed full -netdelay none'
alias mat='open -n ~/Tools/mat/MemoryAnalyzer.app'

alias wifi="networksetup -setairportpower $WIFI_IFACE"

# Open iOS Simulator
alias ios="open /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Applications/iPhone\ Simulator.app"

# Clean up LaunchServices to remove duplicates in the “Open With” menu
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"

# Empty the Trash on all mounted volumes and the main HDD
# Also, clear Apple’s System Logs to improve shell startup speed
alias emptytrash="sudo rm -rfv /Volumes/\*/.Trashes; sudo rm -rfv $HOME/.Trash/; sudo rm -rfv /private/var/log/asl/\*.asl"
alias secureemptytrash="sudo srm -rfv /Volumes/\*/.Trashes; sudo srm -rfv $HOME/.Trash/; sudo srm -rfv /private/var/log/asl/\*.asl"
