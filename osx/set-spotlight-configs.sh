#!/usr/bin/env bash

# Spotlight configurations
#
# Run ./set-spotlight-configs.sh and you'll be good to go.

# Prevent Spotlight from indexing Derived Data, Caches, et al.
touch ~/Library/Caches/.metadata_never_index
touch ~/Library/Developer/.metadata_never_index
killall Finder