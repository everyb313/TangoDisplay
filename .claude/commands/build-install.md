Build the TangoDisplay macOS app and verify it is installed correctly.

## Step 1 — Build

Run:
```bash
bash Install.sh
```

Watch for Swift compilation errors. Common pitfall: `await` cannot be used inside `??` autoclosures — use `if let` unwrapping instead. If the build fails, diagnose the error, fix it, and re-run before continuing.

## Step 2 — Verify

After a successful build, confirm the installed version matches `Install.sh`:
```bash
defaults read /Applications/TangoDisplay.app/Contents/Info.plist CFBundleShortVersionString
```

## Step 3 — Report

Report the installed version on success. If the build failed, report what was wrong and what was fixed.
