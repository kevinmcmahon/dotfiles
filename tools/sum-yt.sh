#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: sum-yt <youtube-url-or-id>"
    echo "Examples:"
    echo "  sum-yt DbrY-J0bpto"
    echo "  sum-yt https://www.youtube.com/watch?v=DbrY-J0bpto"
    echo "  sum-yt https://youtu.be/DbrY-J0bpto"
    echo "  sum-yt https://m.youtube.com/watch?v=DbrY-J0bpto"
    exit 1
fi

# Extract video ID from various YouTube URL formats
input="$1"
video_id=""

# Check if input is already just a video ID (11 characters, alphanumeric with - and _)
if [[ "$input" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
    video_id="$input"
# Handle youtube.com/watch?v=VIDEO_ID format
elif [[ "$input" =~ youtube\.com/watch\?v=([a-zA-Z0-9_-]{11}) ]]; then
    video_id="${BASH_REMATCH[1]}"
# Handle youtu.be/VIDEO_ID format
elif [[ "$input" =~ youtu\.be/([a-zA-Z0-9_-]{11}) ]]; then
    video_id="${BASH_REMATCH[1]}"
# Handle youtube.com/embed/VIDEO_ID format
elif [[ "$input" =~ youtube\.com/embed/([a-zA-Z0-9_-]{11}) ]]; then
    video_id="${BASH_REMATCH[1]}"
# Handle youtube.com/v/VIDEO_ID format
elif [[ "$input" =~ youtube\.com/v/([a-zA-Z0-9_-]{11}) ]]; then
    video_id="${BASH_REMATCH[1]}"
# Handle m.youtube.com/watch?v=VIDEO_ID format
elif [[ "$input" =~ m\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11}) ]]; then
    video_id="${BASH_REMATCH[1]}"
# Handle youtube.com/shorts/VIDEO_ID format
elif [[ "$input" =~ youtube\.com/shorts/([a-zA-Z0-9_-]{11}) ]]; then
    video_id="${BASH_REMATCH[1]}"
else
    echo "Error: Could not extract video ID from: $input"
    exit 1
fi

echo "Summarizing video: $video_id"
llm -f youtube:"$video_id" 'summarize the video'
