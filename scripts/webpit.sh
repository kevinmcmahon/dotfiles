#!/bin/bash

cwebp -q 80 "$1" -o "${1%.*}.webp" 
