#!/usr/bin/env bash

# Desktop Programs
alias preview="open -a '$PREVIEW'"
alias xcode="open -a '/Applications/Xcode.app'"
alias chrome="open -a google\ chrome"
alias f='open -a Finder '

# Show hidden files in Finder
alias showhidden='defaults write com.apple.finder AppleShowAllFiles TRUE && killall Finder'

# Hide hidden files in Finder
alias hidehidden='defaults write com.apple.finder AppleShowAllFiles FALSE && killall Finder'
