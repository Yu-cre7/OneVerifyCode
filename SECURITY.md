# Security Policy

OneVerifyCode is a local-only macOS utility. It reads the Messages database on this Mac, keeps verification codes in memory and in a local history file, and does not send message content anywhere.

## Supported versions

Security fixes are provided for the latest 0.5.x beta release. Older beta builds may not receive fixes.

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Use GitHub's private vulnerability reporting:

1. Open the repository's **Security** tab.
2. Choose **Report a vulnerability**.
3. Include the affected version, macOS version, reproduction steps, and the impact.

If private reporting is unavailable, open a minimal issue asking the maintainer for a private contact channel. Do not include verification codes, SMS bodies, phone numbers, or other personal data in a public issue.

## Scope

Useful reports include:

- unintended network access or telemetry;
- exposure of SMS content, verification codes, phone numbers, or the history file to other users or processes;
- incorrect file permissions on local application data;
- a crash or code path that writes to `chat.db`;
- bypasses of the documented read-only behavior.

The app is ad-hoc signed and not notarized during the beta. Reports that only concern Gatekeeper warnings, the absence of notarization, or the need to re-grant TCC permissions after an overwrite install are known limitations rather than vulnerabilities.

## Privacy expectations

- `~/Library/Messages/chat.db` is opened read-only.
- History is capped at 50 entries and stored with user-only permissions (`0600`).
- Full message bodies are not saved.
- Logs do not contain verification codes or message bodies.
- The app does not require an account and does not make network requests.
