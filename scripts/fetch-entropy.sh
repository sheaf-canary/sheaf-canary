#!/usr/bin/env bash
# Fetch fresh entropy for a new canary.
#
# Outputs values to stdout in a format ready to paste into the
# ENTROPY section of a canary draft. Bitcoin data is fetched from
# blockstream.info; headlines must be filled in manually from the
# named sources on the day of signing.
#
# The BTC block hash is the primary automated entropy source: it
# is cryptographically unforgeable, publicly verifiable forever via
# any block explorer, and could not have been known in advance.
# Headlines are secondary, human-verifiable entropy.

set -euo pipefail

BTC_API=${BTC_API:-https://blockstream.info/api}

echo "# entropy fetched at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

btc_height=$(curl -fsS "${BTC_API}/blocks/tip/height")
btc_hash=$(curl -fsS "${BTC_API}/blocks/tip/hash")
btc_timestamp_unix=$(curl -fsS "${BTC_API}/block/${btc_hash}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["timestamp"])')
btc_timestamp=$(date -u -d "@${btc_timestamp_unix}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -r "${btc_timestamp_unix}" +%Y-%m-%dT%H:%M:%SZ)

cat <<EOF
  Bitcoin block height:  ${btc_height}
  Bitcoin block hash:    ${btc_hash}
  Block timestamp (UTC): ${btc_timestamp}

  The Guardian, top front page headline ($(date -u +%Y-%m-%d)):
    "FILL ME IN — read from https://www.theguardian.com/uk today"

  The New York Times, top front page headline ($(date -u +%Y-%m-%d)):
    "FILL ME IN — read from https://www.nytimes.com today"
EOF
