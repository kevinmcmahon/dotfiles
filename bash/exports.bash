export PATH="/usr/local/bin:/usr/local/sbin:/usr/local/mysql/bin:/opt/local/bin:/opt/local/sbin:/Library/Frameworks/GDAL.framework/Programs:/opt/android/sdk/platform-tools:$PATH"
# Make vim the default editor
export EDITOR="vim"
export GIT_EDITOR="mate -wl1"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# Larger bash history (allow 32³ entries; default is 500)
export HISTSIZE=32768
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoredups

# Make some commands not show up in history
export HISTIGNORE="ls:ls *:cd:cd -:pwd;exit:date:* --help"

# Prefer US English and use UTF-8
export LC_ALL="en_US.UTF-8"
export LANG="en_US"

export ANDROID_HOME=/Developer/android
export GRADLE_HOME=~/Tools/gradle-1.0-milestone-7
export PATH=$PATH:$ANDROID_HOME:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:~/Tools:$GRADLE_HOME/bin:~/Tools/dex2jar
export DATABASE_URL=postgres://kmcmahon:0c791fd488@beta.spacialdb.com:9999/spacialdb_1321928742fe_kmcmahon

export PS1='\h:\W$(__git_ps1 "[\[\e[0;32m\]%s\[\e[0m\]\[\e[0;33m\]$(parse_git_dirty)\[\e[0m\]]")$ '
export M2_HOME=/usr/share/maven
