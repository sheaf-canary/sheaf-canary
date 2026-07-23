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
#
# Signing is pinned to the exact fingerprint listed for the handle in
# SIGNERS. See the note above the gpg call for why that matters.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)

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

# ----- look up this handle's key in SIGNERS -----

want=""
declare -a known=()

while IFS=$'\t' read -r h _name fingerprint _email
do
    [[ -z "${h:-}" || "$h" == \#* ]] && continue
    known+=("$h")
    if [[ "$h" == "$handle" ]]
    then
        want=$(echo "$fingerprint" | tr -d '[:space:]')
    fi
done < "${repo_root}/SIGNERS"

if [[ -z "$want" ]]
then
    echo "error: handle '$handle' is not listed in SIGNERS" >&2
    echo "       known handles: ${known[*]}" >&2
    echo "       pass the right one as the second argument, or set" >&2
    echo "       CANARY_HANDLE" >&2
    exit 1
fi

# --detach-sign + --armor: detached ASCII-armoured signature.
# We intentionally do NOT use clearsign; with two signers, two
# independent detached signatures against identical bytes is cleaner
# and avoids any "whose clearsign wraps whose" ambiguity.
#
# The trailing "!" on the key pins signing to exactly that key. Without
# it, gpg silently prefers the newest signing-capable subkey, which for
# most people is a day-to-day commit-signing subkey living on disk. The
# canary is not a commit: readers verify it against the one fingerprint
# published in SIGNERS and inside the canary text, and the whole premise
# is that producing that signature requires the key holder and whatever
# hardware guards it. A signature from a convenience subkey is a weaker
# claim wearing the same clothes.
gpg --armor --detach-sign --local-user "${want}!" --output "$sigfile" "$file"

# ----- assert we signed with the key we promised -----
#
# VALIDSIG field 3 is the fingerprint of the key that actually made the
# signature (a subkey, if one was used); the final field is its primary.
# verify.sh checks field 3 against SIGNERS, so check the same thing here
# and fail now, loudly, rather than at verification time in a PR.

status=$(gpg --status-fd 1 --verify "$sigfile" "$file" 2>/dev/null || true)
got=$(echo "$status" | awk '/^\[GNUPG:\] VALIDSIG/ {print $3; exit}')

if [[ "$got" != "$want" ]]
then
    rm -f "$sigfile"
    echo "error: signature was made by ${got:-an unknown key}," >&2
    echo "       expected $want" >&2
    echo "       discarded $sigfile; nothing was written" >&2
    exit 1
fi

echo
echo "signed: $sigfile"
echo "        with $want"
echo
echo "verify with:"
echo "  gpg --verify $sigfile $file"
