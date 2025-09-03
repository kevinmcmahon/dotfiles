#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: sum-yt <youtube-video-id>"
    exit 1
fi

llm -f youtube:"$1" 'summarize the video'
