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

## Deeplink testing

The Debug and release builds share the same bundle ID, so opening an
`emacsctl://` URL normally may route it to `/Applications/EmacsCtl.app`.
Target the freshly built Debug app explicitly:

```bash
DEV_APP="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*/Build/Products/Debug/EmacsCtl.app' -type d -print0 |
  xargs -0 ls -td | head -n 1)"

open -g -a "$DEV_APP" \
  'emacsctl://notify?title=Test&body=Noop&actionType=noop'
```

Use `-a` to bypass the default URL-scheme handler and reuse the running
Debug instance.

## Release procedure

1. **Make sure git is clean.** `git status` must show no uncommitted changes.
2. **Sync with remote.** `git pull --rebase --tags origin <branch>` to
   ensure local is up to date (including tags) before releasing.
3. **Update `README.md` for new features if necessary.** Review the commits
   since the last version tag (`git log $(git describe --tags --abbrev=0)..HEAD --oneline`) and
   if any of them introduce user-visible features or behaviour changes that
   are not yet reflected in `README.md` (especially the Features section),
   update it as part of the version bump. Use the format: a short sentence
   or title as the top-level bullet, with several sub-bullets for details.
   Skip this step only when the commits are purely internal (refactors, CI,
   chores, doc-only tweaks).
4. **Bump the version** using `just bump <level>` (`patch` / `minor` / `major`).
   If the level is unclear from the user's request, ask before running.
   ```bash
   just bump patch
   ```
   This rewrites `EMACSCTL_VERSION` in `version.xcconfig`.
5. **Commit and tag.** Stage the version change (and any README updates
   from step 3), commit, then create the matching `v<version>` tag:
   ```bash
   git add version.xcconfig README.md
   git commit -m "bump version to <version>"
   git tag v<version>
   ```
6. **Confirm with the user before pushing.** Show the exact `git push`
   commands you intend to run and wait for explicit approval. Do not push
   without confirmation.
7. **Push branch and tag** (after confirmation):
   ```bash
   git push origin HEAD
   git push origin v<version>
   ```
