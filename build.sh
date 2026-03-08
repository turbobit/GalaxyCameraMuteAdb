#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RELEASE_DIR="$SCRIPT_DIR/release"
VERSION=$(tr -d '\r\n' < "$SCRIPT_DIR/VERSION")

case "$(uname -s)" in
    Darwin)
        APP_NAME="GalaxyCameraMuteAdb_v${VERSION}_macos"
        ;;
    Linux)
        APP_NAME="GalaxyCameraMuteAdb_v${VERSION}_linux"
        ;;
    *)
        APP_NAME="GalaxyCameraMuteAdb_v${VERSION}"
        ;;
esac

mkdir -p "$RELEASE_DIR"

cd "$SCRIPT_DIR"
go build -ldflags "-X main.version=$VERSION" -o "$RELEASE_DIR/$APP_NAME" .

printf 'Build completed: %s (version %s)\n' "$RELEASE_DIR/$APP_NAME" "$VERSION"
