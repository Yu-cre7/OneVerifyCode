# Privacy

OneVerifyCode is designed to keep SMS data on the Mac where it already lives.

## What the app reads

- `~/Library/Messages/chat.db` is opened read-only to find incoming SMS and iMessage verification codes.
- The app reads message text, the sender handle, and the message timestamp. It does not send messages, mark them read, or write to the database.
- Reading requires Full Disk Access, granted by the user in System Settings.

## What the app stores

Preferences are stored in `NSUserDefaults` for the current macOS user. Local history is stored at:

```text
~/Library/Application Support/OneVerifyCode/history.json
```

History contains at most 50 entries: the code, a masked sender, a short masked summary, and a timestamp. Full message bodies are never written to the history file. The file is created with user-only (`0600`) permissions.

Clearing history in Settings removes those entries. Uninstalling the app does not automatically remove the history file; delete it manually if you want to remove local records.

## What the app does not do

- No account, login, analytics, telemetry, advertising, or cloud sync.
- No network requests. The app has no server component.
- No SMS bodies, verification codes, phone numbers, or history are sent to the maintainer or any third party.
- Logs do not contain verification codes or message bodies.
- No data is shared with the App Store or a crash-reporting service.

## Clipboard and Accessibility

When automatic copy is enabled, a detected code is placed on the system clipboard. Clipboard contents are managed by macOS and may be readable by other apps with clipboard access.

Click-to-fill uses the Accessibility API to find the focused text field and paste the code. Accessibility permission is optional; clipboard copy still works without it. The app does not record keystrokes or inspect unrelated window content.

## Beta distribution

Beta builds are ad-hoc signed and not notarized. macOS Gatekeeper may require a right-click **Open** or a quarantine removal command. This is a distribution limitation, not a data collection mechanism.

## Contact

For a privacy or security concern, use the private reporting process in [SECURITY.md](SECURITY.md). Do not post real verification codes, phone numbers, or SMS content in a public issue.
