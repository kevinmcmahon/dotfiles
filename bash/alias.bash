# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"

# Android logcat alias
alias clogcat='"$ANDROID_HOME/platform-tools/adb" logcat | ~/Tools/coloredlogcat.py'

# Shortcuts
alias d="cd ~/Dropbox"
alias dl="cd ~/Downloads"
alias p="cd ~/projects"
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

alias mp='cd /Users/kevin/Projects/apps/markerpal/'

alias wifi="networksetup -setairportpower $WIFI_IFACE"

# Code Analysis Tools
alias maat='java -jar ~/tools/code-maat/latest.jar'
alias mat='open -n ~/Tools/mat/MemoryAnalyzer.app'
