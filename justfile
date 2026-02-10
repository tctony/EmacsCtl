# Justfile for version bumping
# Usage: just bump <level>
# level: major (or main), minor, patch

set shell := ["bash", "-cu"]

# Version file path
VERSION_FILE := "version.xcconfig"
VERSION_VAR := "EMACSCTL_VERSION"

help:
    @just -l

get-version:
    @grep -E "^{{VERSION_VAR}} =" "{{VERSION_FILE}}" | cut -d'=' -f2 | xargs

# Main bump command with level parameter
bump level:
    #!/usr/bin/env bash
    set -euo pipefail
    current=$(just get-version)
    major=$(echo $current | cut -d. -f1)
    minor=$(echo $current | cut -d. -f2)
    patch=$(echo $current | cut -d. -f3)
    level_upper=$(echo {{level}} | tr '[:lower:]' '[:upper:]')

    case "$level_upper" in
        MAJOR|MAIN)
            new_version="$((major + 1)).0.0"
            ;;
        MINOR)
            new_version="$major.$((minor + 1)).0"
            ;;
        PATCH)
            new_version="$major.$minor.$((patch + 1))"
            ;;
        *)
            echo "Error: Invalid level '{{level}}'. Use major/main, minor, or patch."
            exit 1
            ;;
    esac

    sed -i '' "s/^{{VERSION_VAR}} = .*/{{VERSION_VAR}} = ${new_version}/" "{{VERSION_FILE}}"
    echo "Bumped $level_upper version: $current → $new_version"
