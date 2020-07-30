alias reload='source $HOME/.bash_profile'

# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"

# more tidying up scripts
alias rmorig='find . -name "*.orig" -print0 | xargs -0 rm -rf'

# Android logcat alias
alias clogcat='"$ANDROID_HOME/platform-tools/adb" logcat | ~/Tools/coloredlogcat.py'

# Shortcuts
alias cls="clear"
alias dl="cd ~/Downloads"
alias p="cd ~/projects"
alias g="git"
alias v="vim"
alias m="mate ."
alias o="open ."
alias work="cd ~/work"
alias bex='bundle exec'
alias blog='cd ~/projects/blog'

# bat!
alias cat='bat'

# Applications
alias ci='/usr/local/bin/code-insiders'
alias marked="open -a Marked\ 2"

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

# directory view/nav
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

# bundle
alias be='bundle exec'

# Toggle wifi (add on or off after command)
alias wifi="networksetup -setairportpower en0"

# Get current external IP
alias ip="curl icanhazip.com"

# copy the working directory path
alias cpwd='pwd|tr -d "\n"|pbcopy'

alias amplify='npx @aws-amplify/cli'
