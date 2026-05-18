# EmacsCtl

A macOS menu-bar app to control a long-running Emacs daemon, register
EmacsCtl as the default opener for selected file types, and route opens
into a running Emacs session via `emacsclient`.

It also acts as a URL handler for `org-protocol://` (registered via
`CFBundleURLSchemes` in `Info.plist`) and forwards captures to Emacs:

- `org-protocol://...` URLs are handed to `OrgUrlProcessor` and dispatched
 to `emacsclient`, so you don't need an AppleScript shim.
- `emacsctl://...` URLs are handled by `EmacsCtlUrlProcessor`, currently
 used to display actionable notifications (`emacsctl://notify?...`).
- `org-protocol://roam-ref?...` opens a small editable capture window
  (`OrgRoamCaptureWindow`) that lets you tweak the captured content
  before it's forwarded to Emacs.

## Stack

- **Language / UI:** Swift + Objective-C, AppKit, xib-based windows
- **Bundle ID:** `com.tctony.EmacsCtl` (LaunchHelper: `com.tctony.EmacsCtl.LaunchHelper`)
- **Deployment target:** macOS 13.5
- **Dependencies (CocoaPods):** Sparkle (auto-update), MASShortcut (global hotkey)
- **Update feed:** `https://tctony.github.io/EmacsCtl/update.xml` (Sparkle)
- **Version source of truth:** `version.xcconfig` (`EMACSCTL_VERSION`)

## Layout

- `EmacsCtl/` — main app (AppDelegate, EmacsControl, ConfigStore, UI/, OC/)
- `LaunchHelper/` — login-item helper used to start the app at login
- `EmacsCtl.xcworkspace` — the workspace to open (uses Pods)
- `XCConfig/` + `version.xcconfig` — build settings and version
- `justfile` — version-bump helper
- `assets/` — README screenshots
- `Pods/`, `Podfile`, `Podfile.lock` — CocoaPods

## Build

```bash
xcodebuild -workspace EmacsCtl.xcworkspace -scheme EmacsCtl \
  -configuration Debug -destination 'platform=macOS' build
```

Open `EmacsCtl.xcworkspace` in Xcode for normal development.

## Release procedure

1. **Make sure git is clean.** `git status` must show no uncommitted changes.
2. **Bump the version** using `just bump <level>` (`patch` / `minor` / `major`).
   If the level is unclear from the user's request, ask before running.
   ```bash
   just bump patch
   ```
   This rewrites `EMACSCTL_VERSION` in `version.xcconfig`.
3. **Commit and tag.** Stage the version change, commit, then create the
   matching `v<version>` tag:
   ```bash
   git add version.xcconfig
   git commit -m "bump version to <version>"
   git tag v<version>
   ```
4. **Confirm with the user before pushing.** Show the exact `git push`
   commands you intend to run and wait for explicit approval. Do not push
   without confirmation.
5. **Push branch and tag** (after confirmation):
   ```bash
   git push origin HEAD
   git push origin v<version>
   ```
