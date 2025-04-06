HISTSIZE=100000
SAVEHIST=$HISTSIZE
HISTFILE=~/.zsh_history

# History options
setopt appendhistory             # Don't overwrite history file
setopt sharehistory              # Share history across all sessions
setopt hist_ignore_all_dups      # Remove all previous duplicates in history
setopt hist_save_no_dups         # Avoid writing duplicates to file
setopt hist_ignore_space         # Ignore commands starting with a space
setopt hist_verify               # Show before executing from history
