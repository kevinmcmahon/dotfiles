# ZSH setup

## Main setup

1. Install oh-my-zsh
```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

2. Remove stock zprofile and zshrc
```
rm ~/.zprofile ~/.zshrc ~/.zshenv 2>/dev/null
```

3. Symlink zsh config files
```
ln -s ~/dotfiles/zsh/zprofile.symlink ~/.zprofile
ln -s ~/dotfiles/zsh/zshrc.symlink ~/.zshrc
ln -s ~/dotfiles/zsh/zshenv.symlink ~/.zshenv
ln -s ~/dotfiles/zsh/env ~/.zsh
```

4. Add custom aliases to oh-my-zsh
```
ln -s ~/dotfiles/zsh/alias.zsh $ZSH_CUSTOM/alias.zsh
```

5. Install required plugins
```
git clone https://github.com/paulirish/git-open.git $ZSH_CUSTOM/plugins/git-open
git clone https://github.com/romkatv/zsh-defer.git $ZSH_CUSTOM/plugins/zsh-defer
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
git clone https://github.com/Aloxaf/fzf-tab $ZSH_CUSTOM/plugins/fzf-tab
```

6. Reload
```
omz reload
```
