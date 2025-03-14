alias vim='nvim'
alias vi='nvim'
alias zshconfig="bbedit ~/.zshrc"
alias ohmyzsh="bbedit ~/.oh-my-zsh"

alias reload='exec zsh'

# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"

# more tidying up scripts
alias rmorig='find . -name "*.orig" -print0 | xargs -0 rm -rf'
 
alias llmg='llm -m gemini-2.0-flash'

# Shortcuts
alias cls="clear"
alias dl='cd ~/Downloads'
alias p='cd ~/projects'
alias o='open .'
alias work='cd ~/work'
alias blog='cd ~/projects/blog'

alias ip="echo Your ip is; dig +short myip.opendns.com @resolver1.opendns.com;"

# bat!
alias cat='bat'

# Applications
alias marked='open -a Marked\ 2'

# In VS Code do `Cmd+Shift+P` then `Shell Command: Install 'code' command in PATH`
alias ci='/usr/local/bin/code-insiders'

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

# git aliases
alias g='git'
alias gp='git pull --rebase'
alias gm='git merge --no-ff'
alias gl="git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gs='git st'
alias ga='git add'
alias stash='git stash'
alias pop='git stash pop'
alias gldk='git lgdk'

# Toggle wifi (add on or off after command)
alias wifi="networksetup -setairportpower en0"

# Get current external IP
alias ip="curl icanhazip.com"

# copy the working directory path
alias cpwd='pwd|tr -d "\n"|pbcopy'

alias ded='rm -rf ~/Library/Developer/Xcode/DerivedData/'

