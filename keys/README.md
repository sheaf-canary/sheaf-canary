Drop ASCII-armoured public keys here, one per signatory, named after
the handle in SIGNERS.

    gpg --armor --export <your-fingerprint> > keys/<handle>.asc

These copies are for convenience of verifiers who don't want to
fetch from a keyserver. They are not authoritative — the authoritative
identity check is the fingerprint comparison performed by verify.sh
against the SIGNERS file.
