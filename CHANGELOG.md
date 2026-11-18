# Changelog

All notable changes to OneVerifyCode are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions use [Semantic Versioning](https://semver.org/).

## [0.5.3] - 2026-11-18

### Added

- Added a History settings page preview to the README, plus menu-bar menu screenshots in Chinese and English.
- Added repository health files: security policy, contribution guide, changelog, issue forms, pull request template, and CI localization/test workflow.
- Added `panelTheme`, `panelSize`, and `panelTransparency` to the persistence contract documentation.

### Changed

- Renamed the project directory to `OneVerifyCode`.
- Updated the in-app GitHub link and README clone URL to `https://github.com/Yu-cre7/OneVerifyCode`.
- Raised the floating-card background transparency range from 0–40% to 0–100%.
- Moved test compilation to the native architecture so `make test` works on both Intel and Apple silicon.
- Refreshed README screenshots for version 0.5.3.

### Fixed

- Removed the tracked root `.DS_Store` from the release tree.
- Avoided stale version references in README status and preview images.

## [0.5.2] - 2026-11-17

### Added

- Added a GitHub repository link on the About page.
- Added `安装说明.txt` with drag-to-Applications, permissions, and quarantine guidance inside the DMG.
- Added a dedicated sidebar drag layer so only the left sidebar and brand header move the Settings window.

### Changed

- Updated the About description to explain local extraction, quick fill, and clipboard behavior.
- Refined the DMG layout and validation checks for the bundled app and Applications link.

## [0.5.1] - 2026-11-16

### Added

- Added compact pill-shaped permission actions with hover, pressed, disabled, and focus states.
- Added a green "no action needed" state when Full Disk Access is already granted.

### Fixed

- Prevented permission CTAs from stretching across the entire settings card.
- Fixed truncation of the English `Needs permission` badge.

## [0.5.0] - 2026-11-15

### Added

- Added complete Chinese and English UI switching with Follow System, Chinese, and English options.
- Added localized menu items, settings pages, floating cards, status text, hints, and errors.
- Added localization validation for missing keys and format-placeholder mismatches.
- Added full bilingual README, documentation, and screenshots.

## [0.4.2]

### Added

- Migrated launch at login to `SMAppService.mainAppService`.
- Added automatic cleanup of the legacy LaunchAgent plist.

## [0.4.1]

### Added

- Added seven floating-card themes: Aurora, Twilight, Mint, Amber, Graphite, White, and Black.
- Added opaque high-contrast White and Black presets.

## [0.4.0]

### Added

- Added the settings window with six sections.
- Added three card sizes, adjustable transparency, theme selection, and a history summary column.
- Reorganized the menu-bar menu.

## [0.3.0]

### Added

- Added the floating card beside the focused input field.
- Added click-to-copy and optional automatic paste with Accessibility permission.
- Added local history capped at 50 entries.

## [0.2.0]

### Added

- Added read-only access to `~/Library/Messages/chat.db`.
- Added `text` and `attributedBody` decoding.
- Added full-width digit and spaced-code extraction.

## [0.1.0]

### Added

- Initial menu-bar app, code extraction, clipboard copy, and first-run permission flow.
