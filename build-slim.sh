#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"

if [ ! -d frontend ]; then
    echo "frontend/ is missing. Run: git submodule update --init --recursive" >&2
    exit 1
fi

(cd frontend && npm ci --no-audit --no-fund && npm run build)
mkdir -p web/html
rm -rf web/html/*
cp -R frontend/dist/* web/html/

CGO_ENABLED=1 GOOS=linux GOARCH="${GOARCH:-amd64}" \
    go build -trimpath -ldflags='-s -w' -tags 'slim,with_utls' -o "${OUTPUT:-sui-slim}" main.go

ls -lh "${OUTPUT:-sui-slim}"
