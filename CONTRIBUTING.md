# Contributing to SentinelUI

Thanks for your interest in contributing.

## How to contribute

1. Fork the repository and create a branch for your change.
2. Keep changes focused: one feature or fix per pull request.
3. Follow the existing code style (tabs for indentation, module pattern
   `S:NewModule("Name", "dbkey")`).
4. New modules need: a TOC entry, an `enable` flag in `Core/Defaults.lua`,
   and a config entry if it exposes options.
5. User-facing strings go through `S.L`; German translations belong in
   `Locales/deDE.lua`.
6. User-visible changes get a `CHANGELOG.md` entry.
7. Verify Lua syntax before committing.

## Bug reports

Use the bug report issue template and include:

- What you did, what happened, what you expected
- The SentinelUI version (see the TOC file)
- Any Lua error text (BugSack/SentinelUI error log)
- A screenshot if it is a visual issue
