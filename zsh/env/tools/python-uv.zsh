# ~/.zsh/env/tools/python-uv.zsh

py()    { uv run python "$@"; }
py3()   { uv run python "$@"; }
pipuv() { uv run pip "$@"; }
