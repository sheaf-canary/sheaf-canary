# Signatory handbook

This document is the operational manual for the humans who sign Sheaf's
warrant canary. If you are a reader trying to verify a canary, you want
[`README.md`](./README.md) instead.

Everything here is part of the protocol. The two-person property of this
canary depends on both signatories following the process — in particular
the independent-verification and careful-reading steps. A canary where
one signatory rubber-stamps the other's commit has the same trust value
as a one-person canary.


## Table of contents

1. [One-time setup](#one-time-setup)
2. [Pre-agreements to make now](#pre-agreements-to-make-now)
3. [The quarterly rhythm](#the-quarterly-rhythm)
4. [Signing session: initiator](#signing-session-initiator)
5. [Signing session: co-signer](#signing-session-co-signer)
6. [Post-merge](#post-merge)
7. [The refusal protocol](#the-refusal-protocol)
8. [Changing cadence](#changing-cadence)
9. [Key rotation](#key-rotation)


## One-time setup

Before the first canary:

1. **Generate a long-lived personal signing key** each (ed25519 is fine,
   RSA 4096 is fine). This is *your* key, not a project key. Back it up
   offline — Yubikey + a paper backup kept in a different physical
   location from your daily machine is the standard recipe.

2. **Fill in `SIGNERS`** with the real 40-character fingerprints, tab-
   separated. The handle column drives signature filenames, so keep it
   short and stable — e.g. `siterelenby`, `nocturnal`.

3. **Export public keys** into `keys/`:

   ```sh
   gpg --armor --export <your-fingerprint> > keys/<handle>.asc
   ```

4. **Configure git to sign commits by default.** Use `--local` (not
   `--global`) so this identity stays scoped to this repo and does not
   leak into commits you make elsewhere — particularly important if
   your canary handle is a pseudonym separate from your daily dev
   identity. Also set `user.name` and `user.email` locally to match
   your key's UID, so GitHub shows the commit as verified:

   ```sh
   git config --local user.name <your-handle>
   git config --local user.email <email-matching-your-key-UID>
   git config --local user.signingkey <your-fingerprint>
   git config --local commit.gpgsign true
   git config --local tag.gpgsign true
   ```

5. **On GitHub, set branch protection on `main`**:

   - Require a pull request before merging
   - Require 1 review from the other signatory
   - Require signed commits
   - Do not allow force pushes
   - Do not allow deletions
   - Both signatories as org owners with 2FA enforced

6. **Configure at least one mirror**, ideally on a different provider
   in a different jurisdiction. Codeberg is the obvious pick. Add it
   as a git remote:

   ```sh
   git remote add codeberg git@codeberg.org:sheaf-canary/sheaf-canary.git
   ```

   And list the mirror URL in `README.md` so readers can cross-check.

7. **Install weekly status polling** on both your daily machines:

   ```sh
   # crontab -e
   0 9 * * 1  cd ~/sheaf-canary && ./scripts/status.sh || \
              notify-send "Sheaf canary needs attention"
   ```

   Adjust `notify-send` to whatever actually gets your attention
   (email, Signal-to-self, pushover, desktop notification). The point
   is that you don't have to remember — the cron nags you starting
   14 days before the due date.


## Pre-agreements to make now

These are the things that are much easier to agree on before they
matter than to improvise under pressure. Write them down somewhere
you'll both remember — a pinned message in your shared DMs, a file
in a separate private repo, whatever:

- **"I am not going to sign this quarter's canary."** This exact
  sentence (or your equivalent) is a legitimate thing either of you
  can say to the other, with no follow-up questions, and the other
  person will not press for a reason. Agree to this now. It's the
  thing that makes the refusal protocol workable when gag orders
  are in play.

- **Unavailability is not refusal.** If one of you is travelling /
  ill / offline on the planned signing date, the default is to
  reschedule within the grace period, not to skip. If rescheduling
  within grace is impossible, the default is to let the canary lapse
  *with a public explanation posted before the grace deadline* — not
  to sign from a compromised context or skip the reading ritual.

- **"Compromised context" examples.** Agree now, in writing, on
  what counts: shared machines, machines you don't physically
  control, keys not in your possession, signing while under
  observation by someone who shouldn't see the process. When in
  doubt, wait.

- **No steganographic tells, ever.** Neither of you will *ever*
  issue a canary containing a concealed duress signal, a deliberate
  error, or a hidden marker. The canary text already says this
  publicly; this is the internal commitment behind it.


## The quarterly rhythm

A canary cycle looks like:

```
day  0       30      60      76         90            104
     |       |       |       |          |             |
     sign    .       .       [DUE SOON  [DUE]         [EXPIRED
                              nudges]    [GRACE]       if no
                                                       renewal]
```

- `status.sh` starts returning `DUE SOON` 14 days before the due date.
- Plan to sign a **few days before the due date**, not on it. Slack
  absorbs life.
- If you slip, pick a new date and tell the other person. Deviation
  should be visible to both of you, even if it's mundane.


## Signing session: initiator

Let's say you're initiating this quarter.

```sh
cd ~/sheaf-canary
git checkout main
git pull                             # make sure you're current

./scripts/new-canary.sh              # creates canaries/YYYY-QN.txt
./scripts/fetch-entropy.sh           # prints BTC block + headline slots
```

Paste the BTC block data into the draft. Then **open theguardian.com/uk
and nytimes.com in your own browser** and copy one current front-page
headline from each. Don't script this. The entire point of the headlines
is that a human looked at the real site today; let tooling do it and
you've defeated the entropy.

Now the actual signing ritual. Open the draft:

```sh
vim canaries/YYYY-QN.txt
```

**Read every assertion. All of them. Every time.** Not a skim — you
wrote this template months ago, and an assertion you glanced at once
is not an assertion you verified today. For each numbered point, ask
yourself: *is this unambiguously, fully true, right now?*

If the answer to any point is not an unambiguous yes: **stop**. Do not
sign. See [the refusal protocol](#the-refusal-protocol). Decline with
no further explanation; ping the co-signer out-of-band using the pre-
agreed sentence.

If every assertion is cleanly true:

```sh
./scripts/sign.sh canaries/YYYY-QN.txt siterelenby

git checkout -b canary-YYYY-QN
git add canaries/YYYY-QN.txt canaries/YYYY-QN.txt.siterelenby.asc
git commit -S -m "canary: YYYY-QN (initiator sig)"
git push -u origin canary-YYYY-QN
```

Open a PR. **In the PR description, paste:**

- The BTC block height and hash you used
- Both headlines, labelled with source
- The date you verified them against the live sites

This is the co-signer's cross-check target and it creates a permanent
audit record of the entropy you claimed to see. Don't skip it.


## Signing session: co-signer

When you receive notification of a canary PR, you are not approving a
code change. You are making an independent attestation. The workflow
protects that independence only if you do the independent parts.

```sh
git fetch
git checkout canary-YYYY-QN

./scripts/verify.sh                  # initiator's sig should verify
```

Then, on your own, without referring to the PR description:

1. **Open theguardian.com/uk and nytimes.com in your own browser** and
   check the headlines match what's in the file. If the front pages
   have rotated since the initiator signed (The Guardian especially
   rotates fast), check the Wayback Machine's snapshot for the issue
   date. Close enough on the same date is fine; unrelated headlines
   are not.

2. **Open `blockstream.info/block/<hash>`** and confirm the block
   exists, the hash matches, and the timestamp is on the issue date.

3. **Read every assertion.** Same standard as the initiator: any
   point that isn't unambiguously true means you don't sign. If you
   have doubts, ping the initiator out-of-band — not in the PR
   thread — and resolve before signing.

If clean:

```sh
./scripts/sign.sh canaries/YYYY-QN.txt nocturnal
git add canaries/YYYY-QN.txt.nocturnal.asc
git commit -S -m "canary: YYYY-QN (co-sign)"
git push
```

**Merge via the GitHub UI, not the CLI.** The UI merge creates a
merge commit with both of you associated and a permanent PR audit
trail. CLI merges can lose that context.


## Post-merge

Immediately:

```sh
git checkout main && git pull
./scripts/verify.sh                  # confirm: two [OK] lines, VERIFIED

git tag -s canary-YYYY-QN -m "canary: YYYY-QN"
git push origin canary-YYYY-QN

git push codeberg main
git push codeberg canary-YYYY-QN
```

Signed tag is your permanent anchor point for this canary. `git tag -v
canary-YYYY-QN` verifies it forever.

**Then stop.** Do not announce on fedi, Discord, the Sheaf project
README, or anywhere else. Canaries are strongest when their presence
is routine and their absence is the signal. If every renewal is
celebrated publicly, the day you have to go silent the missing
celebration is itself a signal you can't control. Readers who care
know where to look; they can check on their own cadence.


## The refusal protocol

This is the protocol the entire canary exists to enable. It matters
more than the normal workflow.

**Refuse to sign if, at signing time, any of these is true:**

- You have received a warrant, subpoena, NSL, court order, or any
  similar compelled-disclosure instrument relating to Sheaf
- You are under a gag order or non-disclosure directive relating to
  anything in the canary's assertions
- Any party has requested, suggested, or attempted to compel code
  or infrastructure modifications covered by point 4 of the canary
- Keys, credentials, or signing material have been disclosed to or
  seized by anyone
- Any physical or electronic search, seizure, or unauthorised access
  to Sheaf infrastructure has occurred or come to your attention
- Any assertion in the canary is not fully, unambiguously true for
  any other reason

**If you are refusing to sign:**

1. **Do not sign. That is the whole protocol.** No hint, no clever
   signal, no subtle error, no "I'll sign anyway and add a period
   out of place." The canary's interpretation section publicly
   commits both of you to not doing this. Stick to it.

2. **Do not explain why to the co-signer.** If you're under a gag,
   saying "I got served" is precisely the thing the gag prohibits.
   Use the pre-agreed sentence: *"I am not going to sign this
   quarter's canary."* Nothing more. The co-signer will not press.

3. **Co-signer: you may still sign your half if *you* have not been
   served** and every assertion is true from your perspective. A
   canary with only one signature is dead by its own terms and
   readers will know; you do not need to actively invalidate it.

4. **Do not panic-delete, edit, or force-push.** The append-only
   ledger is part of the value, and tampering with history is a
   signal that's much messier than silence. Leave everything as it
   is.

5. **Let the grace period elapse.** Fourteen days after the due
   date, the canary is expired per its own public terms. Readers
   watching now know.

6. **Post an explanation only if you can.** "We are pausing the
   canary due to [true, non-compelled reason]" is fine if you can
   say it truthfully. If you can't, don't. The README has already
   told readers that absence + no explanation is the signal.

**The temptation to sign anyway is exactly what this protocol exists
to resist.** If you find yourself rationalising — "it's basically
true," "I don't want to alarm users," "it's awkward to explain the
gap," "maybe just one more cycle" — that is the moment to not sign.


## Changing cadence

If you ever change the signing frequency:

1. **Decide during a canary you were going to sign normally.** Don't
   announce mid-cycle.

2. **Put the new cadence in that canary's text.** Add a line in the
   schedule-adjacent area: "Starting with the next canary, cadence
   will change from X to Y. Next canary due YYYY-MM-DD."

3. **Update `README.md`'s Schedule section in the same commit.**

4. **Update `scripts/new-canary.sh`.** Change the day counts in the
   `date_plus_days` calls. Commit with the cadence-change canary so
   tooling and attestation land together.

5. **Update the `DUE SOON` threshold in `status.sh`** if appropriate
   (14 days of nudging doesn't make sense for a 30-day cycle).

6. **Run one full cycle under the new cadence before tweaking
   anything else.** Don't compound changes.

Quarterly → monthly is the safe direction (more assurance, not
less). Monthly → quarterly needs an explicit, pre-announced reason —
otherwise it can look like signal-dampening.


## Key rotation

If you need to replace your signing key (compromise, migration,
upgrading algorithms):

1. **Add the new key as a new handle** in `SIGNERS` (e.g. `siterelenby2`)
   and publish the pubkey to `keys/siterelenby2.asc`. Keep the old entry
   in place for now.

2. **In the next canary**, sign with *both* your old and new keys.
   This produces three signature files: old-you, new-you, and the
   co-signer. The overlap canary is the crypto handshake that binds
   the new identity to the old one.

3. **In the canary after that**, remove the old entry from `SIGNERS`
   and sign only with the new key. Delete `keys/old.asc` in the
   same commit.

4. **Document the rotation** briefly in the canary text of step 2 so
   readers aren't surprised: "SiteRelEnby is rotating keys; this canary
   is signed by both siterelenby and siterelenby2, and the next will be
   signed only by siterelenby2."

If a key is *compromised* rather than voluntarily rotated, the
rotation canary is also where you say so — and you revoke the old
key separately via keyserver publication of a revocation
certificate.
