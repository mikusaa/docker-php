#!/bin/sh
set -eu

base="$(sed -n 's/^FROM \(php:[^ ]*\).*/\1/p' Dockerfile)"
if [ "${1:-}" = "--base" ]; then
    test -n "$base"
    printf '%s\n' "$base"
    exit 0
fi
case "$base" in
    php:8.5.11-fpm-alpine@sha256:fa01fb1645cd0fc566a5f146b099adace33b906571f972f71f2182a7c12d1cd7)
        # The exact old base is replaced by docker-bake.hcl until Dependabot updates it.
        printf '%s\n' 8.5.12
        ;;
    *)
        version="$(printf '%s\n' "$base" | sed -nE 's/^php:([0-9]+\.[0-9]+\.[0-9]+)-fpm-alpine.*/\1/p')"
        test -n "$version"
        printf '%s\n' "$version"
        ;;
esac
