# LLM CLI Templates

Templates for the [llm](https://llm.datasette.io/) CLI tool.

## Installation

The `templates.symlink` directory needs to be symlinked to the appropriate location depending on your OS.

### macOS

```bash
ln -s /path/to/dotfiles/llm/templates.symlink ~/Library/Application\ Support/io.datasette.llm/templates
```

### Linux

```bash
ln -s /path/to/dotfiles/llm/templates.symlink ~/.config/io.datasette.llm/templates
```

### Windows

```powershell
New-Item -ItemType SymbolicLink -Path "$env:APPDATA\io.datasette.llm\templates" -Target "C:\path\to\dotfiles\llm\templates.symlink"
```

**Note:** Replace `/path/to/dotfiles` (or `C:\path\to\dotfiles` on Windows) with the actual path to your dotfiles directory.
