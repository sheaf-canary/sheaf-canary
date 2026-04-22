#!/usr/bin/env bash
# Create a new canary draft in canaries/ from TEMPLATE.txt.
#
# Substitutes the current date, the computed quarter, and the due/
# grace dates. The signatories, signature-files, and verify-commands
# blocks are generated dynamically by iterating SIGNERS, so the
# template stays stable across handle changes and key rotations.
# Entropy fields are left as {PLACEHOLDERS} to be filled in manually
# after running ./scripts/fetch-entropy.sh.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# ----- date math (portable between GNU and BSD date) -----

date_plus_days()
{
    local days=$1
    date -u -d "+${days} days" +%Y-%m-%d 2>/dev/null \
        || date -u -v+"${days}"d +%Y-%m-%d
}

today=$(date -u +%Y-%m-%d)
year=$(date -u +%Y)
month=$(date -u +%-m 2>/dev/null || date -u +%m | sed 's/^0//')
quarter=$(( (month - 1) / 3 + 1 ))
period="${year}-Q${quarter}"

next_due=$(date_plus_days 90)
grace_expiry=$(date_plus_days 104)

outfile="canaries/${period}.txt"

if [[ -e "$outfile" ]]
then
    echo "error: $outfile already exists" >&2
    echo "       (remove it first if you really want to replace it)" >&2
    exit 1
fi

# ----- load signer info from SIGNERS -----

declare -A handle_name=()
declare -A handle_fp=()
declare -a order=()

while IFS=$'\t' read -r handle name fingerprint _email
do
    [[ -z "${handle:-}" || "$handle" == \#* ]] && continue
    order+=("$handle")
    handle_name["$handle"]="$name"
    handle_fp["$handle"]="$fingerprint"
done < SIGNERS

if (( ${#order[@]} < 2 ))
then
    echo "error: expected at least 2 signers in SIGNERS, found ${#order[@]}" >&2
    exit 1
fi

# ----- build dynamic blocks -----

signatories_block=""
signature_files_block=""
verify_commands_block=""

for i in "${!order[@]}"
do
    handle=${order[i]}
    name=${handle_name[$handle]}
    fp=${handle_fp[$handle]}

    # Blank line between signatory entries, none before the first.
    if (( i > 0 ))
    then
        signatories_block+=$'\n\n'
    fi
    signatories_block+="${name}"$'\n'
    signatories_block+="  Key fingerprint: ${fp}"$'\n'
    signatories_block+="  Public key:      keys/${handle}.asc"

    if (( i > 0 ))
    then
        signature_files_block+=$'\n'
        verify_commands_block+=$'\n'
    fi
    signature_files_block+="  ${outfile}.${handle}.asc"
    verify_commands_block+="  gpg --verify ${outfile}.${handle}.asc ${outfile}"
done

# ----- substitute into template -----

mkdir -p canaries

tmpl=$(<TEMPLATE.txt)

tmpl=${tmpl//'{QUARTER}'/$period}
tmpl=${tmpl//'{ISSUED_DATE}'/$today}
tmpl=${tmpl//'{NEXT_DUE_DATE}'/$next_due}
tmpl=${tmpl//'{GRACE_EXPIRY}'/$grace_expiry}
tmpl=${tmpl//'{ENTROPY_DATE}'/$today}
tmpl=${tmpl//'{THIS_FILE}'/$outfile}
tmpl=${tmpl//'{SIGNATORIES_BLOCK}'/$signatories_block}
tmpl=${tmpl//'{SIGNATURE_FILES_BLOCK}'/$signature_files_block}
tmpl=${tmpl//'{VERIFY_COMMANDS_BLOCK}'/$verify_commands_block}

printf '%s\n' "$tmpl" > "$outfile"

echo "created: $outfile"
echo
echo "next steps:"
echo "  1. ./scripts/fetch-entropy.sh"
echo "  2. vim $outfile"
echo "       - paste BTC values"
echo "       - fill in Guardian + NYT headlines from today's front pages"
echo "  3. re-read the entire attestation. each point. carefully."
echo "  4. ./scripts/sign.sh $outfile"
echo "  5. git checkout -b canary-${period}"
echo "     git add $outfile ${outfile}.*.asc"
echo "     git commit -S -m 'canary: ${period}'"
echo "     git push -u origin canary-${period}"
echo "  6. open PR, co-signer reviews + signs + merges"
