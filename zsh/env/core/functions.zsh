# Utility functions for environment management
load_env_file() {
    local file=$1
    [[ -f $file ]] && source $file
}

# Optional: Add more helper functions
load_env_dir() {
  local dir=$1
  if [[ ! -d "$dir" ]]; then
    echo "⚠️  load_env_dir: missing dir: $dir" >&2
    return 1
  fi

  local file
  for file in "$dir"/*.zsh; do
    [[ -f "$file" ]] || continue
    load_env_file "$file"
  done
}

function virtualenv_info {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo "(${VIRTUAL_ENV:t})"
    fi
}
