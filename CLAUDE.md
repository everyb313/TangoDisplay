# TangoDisplay — Dev Notes

## Release Process

Use the `/release` slash command — it handles the full workflow automatically:

```
/release X.Y.Z
```

Steps covered: version bump in `Install.sh`, README changelog + download link, docs update, commit/push, `bash Install.sh` build, zip, GitHub release creation, asset upload, and wiki sync.

- ALWAYS follow the procedure in `.claude/commands/release.md` — do not start exploring or making changes first
- Use Python for GitHub API calls — never inline JSON in a curl `-d` string. Shell escaping produces `Invalid control character` errors on release body text
- When creating GitHub releases via `gh release create`, use `--notes-file` instead of inline `--notes` to avoid JSON escaping issues with special characters (em dashes, ⌘ symbols, control chars)
- If a tag already exists from a prior attempt, update the existing release instead of creating a new one
- When fixing a bug, always verify the actual code change is present in the commit BEFORE building/releasing a beta — never ship a version-bump-only release
- Release process follows a defined 9-step pipeline (version bump, release notes, docs/wiki update, commit/push, build, sign, appcast, GitHub release, wiki sync). Follow `release.md` exactly and only include verified changes in release notes

GitHub token is stored in the macOS keychain:
```bash
TOKEN=$(security find-internet-password -s github.com -w)
```

## Build Verification

- After any code change, run the build and confirm success before reporting completion
- For Swift code: `await` cannot be used inside `??` autoclosures — unwrap with `if let` instead
- When changing UI layout, verify against any reference screenshot provided — do not assume first-pass interpretation is correct

## Bug Investigation

- Bugs in this project are often source-specific (e.g., JRiver vs. other players). Before proposing a fix, confirm whether the bug is source-agnostic or specific to one player, and state that assumption explicitly for user confirmation

## Feature Implementation

- Always handle the cortina-mode/cortina-track edge case when implementing display, ordering, or background features — it has been missed repeatedly

## Audio Unit / Plugin Notes

- For macOS AU plugin window issues, check whether the plugin is loaded out-of-process (V2/V3 plugins) before attempting view-hierarchy or scrollview fixes

## Response

Respond like smart caveman. Cut all filler, keep technical substance.
- Drop articles (a, an, the), filler (just, really, basically, actually).
- Drop pleasantries (sure, certainly, happy to).
- No hedging. Fragments fine. Short synonyms.
- Technical terms stay exact. Code blocks unchanged.
- Pattern: [thing] [action] [reason]. [next step].
