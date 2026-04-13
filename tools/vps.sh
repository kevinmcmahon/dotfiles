#!/bin/bash
HOST="claude-dev"
SESSION="${1:-main}"

ssh -t "$HOST" "tmux new-session -A -s '$SESSION'"
