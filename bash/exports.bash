export M2_HOME=/usr/local/Cellar/maven/3.1.1/libexec
export ANDROID_HOME=/Applications/Android\ Studio.app/sdk
export GRADLE_HOME=/Users/kevin/Tools/gradle
export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:/opt/local/bin:/opt/local/sbin:/Library/Frameworks/GDAL.framework/Programs:/usr/local/git/bin:$ANDROID_HOME:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:/Users/kevin/Tools:/Users/kevin/Tools/bin:$GRADLE_HOME/bin:~/Tools/dex2jar:$M2_HOME:$PATH:."

# Make TextMate the default editor
export EDITOR="/usr/local/bin/mate -w"
export GIT_EDITOR="mate -wl1"

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

#export DATABASE_URL=postgres://kmcmahon:0c791fd488@beta.spacialdb.com:9999/spacialdb_1321928742fe_kmcmahon
#export DATABASE_URL=postgres://mnaijy_wasnok:63992490@spacialdb.com:9999/mnaijy_wasnok
#export DATABASE_URL=postgres://qwjvxk_fbrczr:da4ed395@spacialdb.com:9999/qwjvxk_fbrczr

export PS1='\[\033[G\]\h:\W$(__git_ps1 "[\[\e[0;32m\]%s\[\e[0m\]\[\e[0;33m\]$(parse_git_dirty)\[\e[0m\]]")$ '

export PROMPT_COMMAND='echo -ne "\033]0; ${PWD##*/}\007"'