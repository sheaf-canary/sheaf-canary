#!/usr/bin/env bash
# Quick status line for the canary: healthy? due soon? expired?
#
# Intended for cron or CI use. Exit codes:
#   0  HEALTHY or DUE SOON (no action needed from automation)
#   1  DUE or IN GRACE PERIOD (signatories should act)
#   2  NO CANARY PRESENT
#   3  EXPIRED

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

latest=$(ls canaries/*.txt 2>/dev/null | sort | tail -1 || true)

if [[ -z "$latest" ]]
then
    echo "STATUS: NO CANARY FOUND"
    exit 2
fi

next_due=$(awk -F':[[:space:]]*' '/^Next canary due:/ {print $2; exit}' "$latest")
grace=$(sed -n 's/.*expires \([0-9]\{4\}-[0-9][0-9]-[0-9][0-9]\).*/\1/p' "$latest" \
        | head -1)
today=$(date -u +%Y-%m-%d)

days_to()
{
    local target=$1
    local t_sec n_sec
    t_sec=$(date -d "$target" +%s 2>/dev/null || date -j -f %Y-%m-%d "$target" +%s)
    n_sec=$(date -d "$today" +%s 2>/dev/null || date -j -f %Y-%m-%d "$today" +%s)
    echo $(( (t_sec - n_sec) / 86400 ))
}

d_due=$(days_to "$next_due")
d_grace=$(days_to "$grace")

printf 'latest:    %s\n' "$latest"
printf 'today:     %s\n' "$today"
printf 'next due:  %s  (%+d days)\n' "$next_due" "$d_due"
printf 'grace end: %s  (%+d days)\n' "$grace" "$d_grace"

if (( d_grace < 0 ))
then
    echo "STATUS: EXPIRED"
    exit 3
elif (( d_due < 0 ))
then
    echo "STATUS: IN GRACE PERIOD"
    exit 1
elif (( d_due == 0 ))
then
    echo "STATUS: DUE TODAY"
    exit 1
elif (( d_due <= 14 ))
then
    echo "STATUS: DUE SOON"
    exit 0
else
    echo "STATUS: HEALTHY"
    exit 0
fi
