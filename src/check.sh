#!/bin/sh
file="${1:-./hello}"

# Execute the file in $file and check its output
output=$("$file")
expected="Hello, World!"

# 1. Check if the output matches the expected output
[ "$output" = "$expected" ] || (echo "Expected '$expected', got: '$output'" && exit 1)

# 2. Check if it's statically linked
output=$(file "$file")
echo "$output" | grep -qE 'statically linked|static-pie linked' || (echo "Binary $file is not statically linked\n\n$output" && exit 1)
