# Security Policy

## Supported versions

Only the latest release of this fork is supported with security fixes.

## Reporting a vulnerability

Do **not** open a public issue for security problems.

Report privately via GitHub's [private vulnerability reporting](https://github.com/nicholyx/localsend/security/advisories/new)
or contact the repository owner. Include a description, reproduction steps and
the affected version/commit. You will get an acknowledgment within a few days.

## Threat model notes

LocalSend moves arbitrary files between devices on a local network. Things
worth reporting:

- The HTTP server accepting requests from peers it should reject
  (certificate / fingerprint / PIN validation bypasses)
- Path traversal or overwriting files outside the chosen destination directory
- The web send page leaking received files to unauthenticated browsers
- Secrets (tokens, PINs) ending up in logs

Out of scope: issues requiring a malicious device already trusted by the user,
and the upstream project's own security reports — please report upstream
issues to https://github.com/localsend/localsend instead.
