export M2_HOME=/usr/local/Cellar/maven/3.1.1/libexec
export ANDROID_HOME=~/tools/android-sdk

if [ -f ~/dotfiles/bash/exports.bash.local ]; then
	source ~/dotfiles/bash/exports.bash.local	
fi

# Make TextMate the default editor
export EDITOR="bbedit --wait --resume"
export GIT_EDITOR="bbedit --wait --resume"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# Larger bash history (allow 32³ entries; default is 500)
export HISTSIZE=32768
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoredups

export ARCHFLAGS="-arch x86_64"
export ARCH_FLAGS=$ARCHFLAGS

# Make some commands not show up in history
export HISTIGNORE="ls:ls *:cd:cd -:pwd;exit:date:* --help"

# Prefer US English and use UTF-8
export LC_ALL="en_US.UTF-8"
export LANG="en_US"

export PS1='\[\033[G\]\h:\W$(__git_ps1 "[\[\e[0;32m\]%s\[\e[0m\]\[\e[0;33m\]$(parse_git_dirty)\[\e[0m\]]")$ '

export PROMPT_COMMAND='echo -ne "\033]0; ${PWD##*/}\007"'
export JAVA_HOME=`/usr/libexec/java_home` 
