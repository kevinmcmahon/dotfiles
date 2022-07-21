# ZSH setup

## Main setup

1. Install oh-my-zsh
```
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

2. Remove stock zprofile and zshrc

```
rm ~/.zprofile && rm ~/.zshrc
```

3. Symlink custom zprofile and zshrc

```
ln -s dotfiles/zsh/zprofile.symlink .zprofile
ln -s dotfiles/zsh/zshrc.symlink .zshrc
```
4. Add customizations

```
ln -s ~/dotfiles/zsh/alias.zsh aliash.zsh $ZSH_CUSTOM/alias.zsh
```

5. Reload
```
omz reload
```

## Add Plugins

### git open

1. git clone https://github.com/paulirish/git-open.git $ZSH_CUSTOM/plugins/git-open
2. Add git-open to your plugin list - edit ~/.zshrc and change plugins=(...) to plugins=(... git-open)
