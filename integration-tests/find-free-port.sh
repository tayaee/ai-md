#!/bin/bash
# Prints the first free TCP port at or after $1 (default 18080), scanning up to +99.
set -euo pipefail
start=${1:-18080}

for ((p = start; p < start + 100; p++)); do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then
        echo "$p"
        exit 0
    fi
    exec 3>&- 3<&- 2>/dev/null || true
done

echo "no free port found in range $start-$((start + 99))" >&2
exit 1
