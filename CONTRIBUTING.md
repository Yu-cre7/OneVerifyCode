# Contributing to OneVerifyCode

Thanks for helping improve OneVerifyCode. The project is a small, native macOS menu-bar app, so changes should stay focused on local SMS verification-code handling and the existing AppKit design.

## Before you start

- Use macOS 13 or newer.
- Install Command Line Tools with `xcode-select --install`.
- Install Python 3 for packaging and localization checks. A full Xcode installation is not required.
- Read [README.md](README.md) for the product and privacy model.

## Build and test

```bash
make test      # extractor, history, and localization checks
make app       # build/stage/一码.app (Universal)
make run       # launch the built app
```

`make test` must pass before a pull request is ready. If you change user-visible text, update the Chinese source string and `assets/en.lproj/Localizable.strings` together. Run:

```bash
python3 tools/check_l10n.py
```

## Design constraints

- Objective-C + AppKit, with hand-written frame layout. Do not add SwiftUI or Interface Builder files.
- Keep the menu-bar-first behavior and `LSUIElement=1`.
- Preserve the privacy boundary: `chat.db` is read-only, message bodies are not stored, history is capped at 50 entries, and logs must not contain codes or message text.
- Do not add network calls, analytics, accounts, or cloud storage.
- Keep the bilingual UI working for menu items, settings, the floating card, status text, hints, and errors.
- Test both light and dark appearance, and both Chinese and English, when changing layout.
- Do not commit build products (`build/`), packaged installers (`dist/`), or local metadata such as `.DS_Store`.

## Pull requests

1. Keep the change scoped and explain the user-visible result.
2. Include the commands and results used for verification.
3. Add or update documentation when behavior or permissions change.
4. Update `CHANGELOG.md` for user-visible changes.
5. Avoid committing personal data, real phone numbers, real verification codes, or screenshots of private messages.

By contributing, you agree that your contribution is licensed under the repository's MIT License.
