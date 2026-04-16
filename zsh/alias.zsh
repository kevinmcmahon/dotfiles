alias vim='nvim'
alias vi='nvim'
alias zshconfig="vi ~/.zshrc"
alias ohmyzsh="vi ~/.oh-my-zsh"


# Recursively delete `.DS_Store` files
alias cleanup="find . -name '*.DS_Store' -type f -ls -delete"
#
# cleanup repomix outputs
alias rmrepomix="find . -name 'repomix-output*' -type f -ls -delete"

# more tidying up scripts
alias rmorig='find . -name "*.orig" -print0 | xargs -0 rm -rf'

# llm and agents
alias llmg='llm -m gemini-3-flash-preview'
alias l32='llm -m mlx-community/Llama-3.2-3B-Instruct-4bit'
alias cmdhelp='llm -t cmd'

alias claude='~/.local/bin/claude'
alias cld='claude'
alias cldy='claude --dangerously-skip-permissions'
alias ccusage='npx ccusage@latest'

alias codexy='codex --dangerously-bypass-approvals-and-sandbox'


alias repomix='npx repomix@latest'
alias cdk='npx aws-cdk@latest'
alias eslint='npx eslint@latest'

# Shortcuts
alias cls="clear"
alias dl='cd ~/Downloads'
alias p='cd ~/projects'
alias work='cd ~/work'
alias blog='cd ~/projects/blog'
alias f='fzf'
alias y='yazi'
alias croc='croc --yes'

# bat!
alias cat='bat'
alias bcat='/bin/cat'

alias ls="eza --no-filesize --long --color=always --icons=always --no-user"

# remove any existing la/ll
unalias la ll 2>/dev/null

# long listing, human-readable sizes, "almost all" entries, with colors & icons
alias ll='eza --long --color=always --icons=always --no-user'

alias la='ll --no-time --group-directories-first --all'

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
alias gdiff='g difftool'

# Get current external IP
alias ip="curl icanhazip.com"

# tmux

alias t='tmux attach -t main 2>/dev/null || tmux new -s main'
alias tdev='tmux attach -t dev 2>/dev/null || tmux new -s dev'

# If tmux feels hung: detach all other clients and reattach cleanly
alias tfix='sess="main-$(hostname -s)"; tmux detach-client -a 2>/dev/null; tmux switch-client -t "$sess" 2>/dev/null || tmux attach -t "$sess" 2>/dev/null || tmux new -s "$sess"'

alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# suffix aliases (open files by extension: e.g. `./data.json` opens in jless)
alias -s json=jless
alias -s {yaml,yml}='bat -l yaml'
alias -s md=bat
alias -s py='uv run'

# batch rename (noglob lets you use wildcards without quoting)
alias mmv='noglob zmv -W'

# global aliases (expand anywhere in a command)
alias -g G='| rg'
alias -g L='| less'
alias -g J='| jq .'
alias -g W='| wc -l'
alias -g H='| head'
alias -g T='| tail'
alias -g NUL='> /dev/null 2>&1'
alias -g ERR='2>&1'

# macOS-only aliases
if [[ "$OSTYPE" == darwin* ]]; then
  alias o='open .'

  # Applications
  alias marked='open -a Marked\ 2'

  # In VS Code do `Cmd+Shift+P` then `Shell Command: Install 'code' command in PATH`
  alias ci='/usr/local/bin/code-insiders'
  alias code='/usr/local/bin/code-insiders'

  # Hide/show all desktop icons (useful when presenting)
  alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
  alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

  # Toggle wifi (add on or off after command)
  alias wifi="networksetup -setairportpower en0"

  # copy the working directory path
  alias cpwd='pwd|tr -d "\n"|pbcopy'

  # Xcode derived data cleanup
  alias ded='rm -rf ~/Library/Developer/Xcode/DerivedData/'

  # suffix: open media/docs by extension
  alias -s {mov,mp4,png,pdf}=open

  # global: pipe to clipboard
  alias -g C='| pbcopy'
fi
