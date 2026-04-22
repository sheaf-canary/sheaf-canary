# Sheaf Project Warrant Canary

This repository contains the Sheaf Project's warrant canary: a signed
attestation, renewed on a regular schedule, that certain categories of
legal compulsion and compromise have **not** occurred.

The canary works by **absence**. If the canary is not renewed on time,
and no public explanation is given, readers should assume one or more
of its assertions no longer holds. There is no secret duress signal;
the only legitimate response to compulsion is to decline to sign.

## How to verify

```sh
./scripts/verify.sh
```

This verifies the latest canary in `canaries/`:

- Both expected signatures are present, valid, and from the expected keys
- The `Issued` and `Next canary due` dates
- The Bitcoin block hash against a public block explorer

Exit code 0 = verified. Non-zero = something is wrong; do not rely on
the canary until you understand why.

Manual verification (no scripts required):

```sh
gpg --import keys/*.asc
LATEST=$(ls canaries/*.txt | sort | tail -1)
gpg --verify "${LATEST}.siterelenby.asc" "$LATEST"
gpg --verify "${LATEST}.nocturnal.asc" "$LATEST"
```

The expected key fingerprints are listed in `SIGNERS` and also inline
in each signed canary file itself. Both must match.

## Schedule

- Canaries are issued **quarterly** (every 90 days)
- Each canary names the next due date and a 14-day grace period
- If the canary is not renewed by the end of the grace period, **treat
  it as expired**

## Mirrors

This repository is mirrored at:

- (primary) `github.com/sheaf-canary/sheaf-canary`
- (mirror) `codeberg.org/sheaf-canary/sheaf-canary` *(configure after initial push)*

If the mirrors disagree, that is itself a signal. Cross-check.

## Out-of-band channels

If the canary lapses, look for a public explanation at:

- This repository's README (top-of-file notice)
- *(fediverse handles to be added)*

Absence of both a renewal **and** an explanation is the signal.

## For signatories

The full signing process, refusal protocol, and pre-agreements live in
[`SIGNING.md`](./SIGNING.md). Read it before signing anything, and re-
read the refusal protocol section periodically so it's fresh when
needed.

Silence is the signal. Declining to sign is the correct response to
compulsion.
