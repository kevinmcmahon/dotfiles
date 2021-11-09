#!/bin/bash
#
# URL Encode
# https://gist.github.com/levigroker/36525010ba0bce15450c89fe6a5f36b1
#
# A BBEdit Text Filter script to take textual input and produce URL encoded text of the same.
# See http://bbeditextras.org/wiki/index.php?title=Text_Filters
# Levi Brown
# @levigroker
# levigroker@gmail.com
# January 12, 2018
##

IN=$(tee)
CMD="echo urlencode('${IN}');"
OUT=$(php -r "$CMD")
echo -n "${OUT}"