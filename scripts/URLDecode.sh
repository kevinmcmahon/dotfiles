#!/bin/bash
#
# URL Decode
# https://gist.github.com/levigroker/892fd435d701b4e8f56bfcec819d5ef2
#
# A BBEdit Text Filter script to take textual input and produce URL decoded text of the same.
# See http://bbeditextras.org/wiki/index.php?title=Text_Filters
# Levi Brown
# @levigroker
# levigroker@gmail.com
# January 12, 2018
##

IN=$(tee)
CMD="echo urldecode('${IN}');"
OUT=$(php -r "$CMD")
echo -n "${OUT}"