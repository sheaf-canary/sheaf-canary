#!/usr/bin/env bash
# Verify a canary's signatures, freshness, and BTC entropy.
#
# Usage:  scripts/verify.sh [canary-file]
#
# With no argument, verifies the lexicographically latest file in
# canaries/. Exits 0 only if every expected signature is valid,
# matches the expected fingerprint in SIGNERS, and the canary is
# within its grace window. BTC entropy mismatch produces a warning
# but does not fail verification (the signatures are authoritative;
# network failures to block explorers should not invalidate an
# otherwise-valid canary).

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

file=${1:-}

if [[ -z "$file" ]]
then
    file=$(ls canaries/*.txt 2>/dev/null | sort | tail -1 || true)
fi

if [[ -z "${file:-}" || ! -f "$file" ]]
then
    echo "error: no canary file found" >&2
    exit 1
fi

echo "=== verifying: $file ==="
echo

# ----- load expected signers -----

declare -a handles=()
declare -A expected_fp=()

while IFS=$'\t' read -r handle _name fingerprint _email
do
    [[ -z "${handle:-}" || "$handle" == \#* ]] && continue
    handles+=("$handle")
    # Strip spaces from fingerprint for comparison with gpg output.
    expected_fp["$handle"]=$(echo "$fingerprint" | tr -d '[:space:]')
done < SIGNERS

all_sigs_ok=1

# ----- verify each signature -----

for handle in "${handles[@]}"
do
    sigfile="${file}.${handle}.asc"
    want=${expected_fp[$handle]}

    if [[ ! -f "$sigfile" ]]
    then
        printf '  [MISSING] no signature from %s (%s)\n' "$handle" "$sigfile"
        all_sigs_ok=0
        continue
    fi

    status=$(gpg --status-fd 1 --verify "$sigfile" "$file" 2>/dev/null || true)

    if ! echo "$status" | grep -q '^\[GNUPG:\] GOODSIG'
    then
        printf '  [BADSIG]  %s — signature does not verify\n' "$handle"
        all_sigs_ok=0
        continue
    fi

    got=$(echo "$status" | awk '/^\[GNUPG:\] VALIDSIG/ {print $3; exit}')

    if [[ "$got" != "$want" ]]
    then
        printf '  [WRONGFP] %s — got %s, expected %s\n' "$handle" "$got" "$want"
        all_sigs_ok=0
        continue
    fi

    printf '  [OK]      %s (%s)\n' "$handle" "$got"
done

echo

# ----- freshness -----

issued=$(awk -F':[[:space:]]*' '/^Issued:/ {print $2; exit}' "$file")
next_due=$(awk -F':[[:space:]]*' '/^Next canary due:/ {print $2; exit}' "$file")
grace=$(sed -n 's/.*expires \([0-9]\{4\}-[0-9][0-9]-[0-9][0-9]\).*/\1/p' "$file" \
        | head -1)
today=$(date -u +%Y-%m-%d)

printf '  Issued:    %s\n' "$issued"
printf '  Next due:  %s\n' "$next_due"
printf '  Grace end: %s\n' "$grace"
printf '  Today:     %s\n' "$today"
echo

fresh_ok=1

if [[ "$today" > "$grace" ]]
then
    printf '  [EXPIRED] grace period ended %s\n' "$grace"
    fresh_ok=0
elif [[ "$today" > "$next_due" ]]
then
    printf '  [GRACE]   past due, within grace period until %s\n' "$grace"
elif [[ "$today" == "$next_due" ]]
then
    printf '  [DUE]     canary is due today\n'
else
    printf '  [CURRENT] canary is current\n'
fi

echo

# ----- BTC entropy (advisory only) -----

btc_height=$(awk '/^[[:space:]]*Bitcoin block height:/ {print $NF; exit}' "$file")
btc_hash=$(awk '/^[[:space:]]*Bitcoin block hash:/ {print $NF; exit}' "$file")

if [[ -n "${btc_height:-}" && -n "${btc_hash:-}" ]]
then
    real_hash=$(curl -fsS --max-time 10 \
        "https://blockstream.info/api/block-height/${btc_height}" 2>/dev/null \
        || echo "")

    if [[ -z "$real_hash" ]]
    then
        printf '  [WARN]    could not reach block explorer to check BTC entropy\n'
    elif [[ "$real_hash" == "$btc_hash" ]]
    then
        printf '  [OK]      BTC block %s hash matches\n' "$btc_height"
    else
        printf '  [WARN]    BTC hash mismatch: claimed %s, got %s\n' \
               "$btc_hash" "$real_hash"
    fi
    echo
fi

# ----- verdict -----

if (( all_sigs_ok == 1 && fresh_ok == 1 ))
then
    echo "=== VERIFIED ==="
    exit 0
else
    echo "=== VERIFICATION FAILED ==="
    exit 1
fi
