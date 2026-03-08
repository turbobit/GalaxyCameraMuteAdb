#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERSION=$(tr -d '\r\n' < "$SCRIPT_DIR/VERSION")

cd "$SCRIPT_DIR"
go run -ldflags "-X main.version=$VERSION" .
