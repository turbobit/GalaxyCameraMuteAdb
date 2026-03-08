#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RELEASE_DIR="$SCRIPT_DIR/release"
VERSION=$(tr -d '\r\n' < "$SCRIPT_DIR/VERSION")
TAG="v$VERSION"
TITLE="GalaxyCameraMuteAdb $TAG"
BRANCH=$(git -C "$SCRIPT_DIR" branch --show-current)
SKIP_PUBLISH=0

if [ "${1:-}" = "-SkipPublish" ] || [ "${1:-}" = "--skip-publish" ]; then
    SKIP_PUBLISH=1
fi

case "$(uname -s)" in
    Darwin)
        ASSET_NAME="GalaxyCameraMuteAdb_v${VERSION}_macos"
        ;;
    Linux)
        ASSET_NAME="GalaxyCameraMuteAdb_v${VERSION}_linux"
        ;;
    *)
        ASSET_NAME="GalaxyCameraMuteAdb_v${VERSION}"
        ;;
esac

ASSET_PATH="$RELEASE_DIR/$ASSET_NAME"
NOTES_PATH="$RELEASE_DIR/release-notes-$VERSION.md"

printf 'Version: %s\n' "$VERSION"
printf 'Tag: %s\n' "$TAG"
printf 'Branch: %s\n' "$BRANCH"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

sh "$SCRIPT_DIR/build.sh"

if [ ! -f "$ASSET_PATH" ]; then
    printf 'Build output not found: %s\n' "$ASSET_PATH" >&2
    exit 1
fi

if [ "$SKIP_PUBLISH" -eq 0 ]; then
    if [ -n "$(git -C "$SCRIPT_DIR" status --short)" ]; then
        printf 'Changes detected. Staging files.\n'
        git -C "$SCRIPT_DIR" add -A
        git -C "$SCRIPT_DIR" commit -m "release: $TAG"
    else
        printf 'No changes to commit.\n'
    fi

    git -C "$SCRIPT_DIR" push origin "$BRANCH"
fi

ALL_TAGS=$(git -C "$SCRIPT_DIR" tag --list 'v*' --sort=-version:refname)
TAG_EXISTS=0
PREVIOUS_TAG=""

for existing_tag in $ALL_TAGS; do
    if [ "$existing_tag" = "$TAG" ]; then
        TAG_EXISTS=1
    elif [ -z "$PREVIOUS_TAG" ]; then
        PREVIOUS_TAG="$existing_tag"
    fi
done

{
    printf '# %s\n\n' "$TITLE"

    if [ -n "$PREVIOUS_TAG" ]; then
        printf 'Compare: %s..%s\n\n' "$PREVIOUS_TAG" "$TAG"
        git -C "$SCRIPT_DIR" log "$PREVIOUS_TAG..HEAD" --pretty='format:- %h %s'
    else
        printf 'Initial release\n\n'
        git -C "$SCRIPT_DIR" log --reverse --pretty='format:- %h %s'
    fi

    printf '\n\nAsset\n\n- %s\n' "$ASSET_NAME"
} > "$NOTES_PATH"

if [ -n "$PREVIOUS_TAG" ]; then
    printf 'Previous tag: %s\n' "$PREVIOUS_TAG"
else
    printf 'Previous tag: (none)\n'
fi
printf 'Notes file: %s\n' "$NOTES_PATH"
printf 'Asset file: %s\n' "$ASSET_PATH"

if [ "$SKIP_PUBLISH" -eq 1 ]; then
    printf 'SkipPublish enabled. Remote tag/release upload skipped.\n'
    exit 0
fi

gh auth status

if [ "$TAG_EXISTS" -eq 1 ]; then
    printf 'Existing tag found. Updating tag to current HEAD.\n'
    git -C "$SCRIPT_DIR" tag -f "$TAG" HEAD
else
    printf 'Creating new tag.\n'
    git -C "$SCRIPT_DIR" tag "$TAG" HEAD
fi

git -C "$SCRIPT_DIR" push origin "refs/tags/$TAG" --force

if gh release view "$TAG" >/dev/null 2>&1; then
    printf 'Existing GitHub release found. Updating release.\n'
    gh release edit "$TAG" --title "$TITLE" --notes-file "$NOTES_PATH"
    gh release upload "$TAG" "$ASSET_PATH" --clobber
else
    printf 'Creating GitHub release.\n'
    gh release create "$TAG" "$ASSET_PATH" --title "$TITLE" --notes-file "$NOTES_PATH"
fi

printf 'Release completed: %s\n' "$TAG"
