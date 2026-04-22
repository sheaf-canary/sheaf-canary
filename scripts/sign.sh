#!/usr/bin/env bash
# Sign a canary file with the current user's GPG key.
#
# Usage:  scripts/sign.sh <canary-file> [handle]
#
# If not given, handle defaults to $CANARY_HANDLE, then to a
# lowercased, space-stripped version of git user.name. The resulting
# signature is written to <canary-file>.<handle>.asc.
#
# Refuses to overwrite an existing signature file; delete it first
# if you are deliberately re-signing.

set -euo pipefail

file=${1:?usage: sign.sh <canary-file> [handle]}
handle=${2:-${CANARY_HANDLE:-}}

if [[ -z "$handle" ]]
then
    handle=$(git config user.name \
             | tr '[:upper:]' '[:lower:]' \
             | tr -d '[:space:]')
fi

if [[ ! -f "$file" ]]
then
    echo "error: $file does not exist" >&2
    exit 1
fi

sigfile="${file}.${handle}.asc"

if [[ -e "$sigfile" ]]
then
    echo "error: $sigfile already exists" >&2
    echo "       remove it explicitly if you intend to re-sign" >&2
    exit 1
fi

# --detach-sign + --armor: detached ASCII-armoured signature.
# We intentionally do NOT use clearsign; with two signers, two
# independent detached signatures against identical bytes is cleaner
# and avoids any "whose clearsign wraps whose" ambiguity.
gpg --armor --detach-sign --output "$sigfile" "$file"

echo
echo "signed: $sigfile"
echo
echo "verify with:"
echo "  gpg --verify $sigfile $file"
