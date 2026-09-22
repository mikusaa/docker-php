#!/bin/sh
set -eu

IMAGE="${1:-docker-php:test}"
PLATFORM="${2:-linux/amd64}"
EXPECTED_PHP_VERSION="${EXPECTED_PHP_VERSION:-$(sed -nE 's/^FROM php:([0-9]+\.[0-9]+\.[0-9]+)-fpm-alpine.*/\1/p' Dockerfile)}"
CONTAINER_ID=""
OUTPUT_FILE="$(mktemp)"

cleanup() {
    if [ -n "$CONTAINER_ID" ]; then
        docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
    fi
    rm -f "$OUTPUT_FILE"
}
trap cleanup EXIT INT TERM

actual_php_version="$(docker run --rm --platform "$PLATFORM" "$IMAGE" php -r 'echo PHP_VERSION;')"
if [ "$actual_php_version" != "$EXPECTED_PHP_VERSION" ]; then
    echo "Expected PHP $EXPECTED_PHP_VERSION, got $actual_php_version" >&2
    exit 1
fi

docker run --rm --platform "$PLATFORM" "$IMAGE" php -r '
$required = [
    "bcmath", "curl", "exif", "gd", "imagick", "intl", "mbstring",
    "mysqli", "pdo_mysql", "pdo_pgsql", "pdo_sqlite", "redis", "zip",
];
$missing = array_values(array_filter($required, fn ($extension) => !extension_loaded($extension)));
if ($missing !== []) {
    fwrite(STDERR, "Missing PHP extensions: " . implode(", ", $missing) . PHP_EOL);
    exit(1);
}
'

docker run --rm --platform "$PLATFORM" "$IMAGE" composer --version

docker run --rm --platform "$PLATFORM" "$IMAGE" php-fpm -tt >"$OUTPUT_FILE" 2>&1
grep -F "listen = 9000" "$OUTPUT_FILE" >/dev/null
grep -F "pm.max_requests = 300" "$OUTPUT_FILE" >/dev/null

runtime_state="$(docker run --rm --platform "$PLATFORM" \
    -e PUID=12345 \
    -e PGID=12346 \
    -e TZ=UTC \
    "$IMAGE" sh -eu -c '
        php-fpm -t >/dev/null 2>&1
        printf "%s:%s:%s" "$(id -u www-data)" "$(id -g www-data)" "$(php -r "echo date_default_timezone_get();")"
    ')"
if [ "$runtime_state" != "12345:12346:UTC" ]; then
    echo "Unexpected runtime state: $runtime_state" >&2
    exit 1
fi

if docker run --rm --platform "$PLATFORM" -e PUID=0 "$IMAGE" true >"$OUTPUT_FILE" 2>&1; then
    echo "PUID=0 should have been rejected" >&2
    exit 1
fi
grep -F "PUID must not be 0" "$OUTPUT_FILE" >/dev/null

if docker run --rm --platform "$PLATFORM" -e TZ=../UTC "$IMAGE" true >"$OUTPUT_FILE" 2>&1; then
    echo "An unsafe timezone path should have been rejected" >&2
    exit 1
fi
grep -F "TZ must be a valid timezone name" "$OUTPUT_FILE" >/dev/null

CONTAINER_ID="$(docker run -d --platform "$PLATFORM" "$IMAGE")"
i=0
while [ "$i" -lt 10 ]; do
    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_ID")" = "true" ]; then
        break
    fi
    i=$((i + 1))
    sleep 1
done

if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_ID")" != "true" ]; then
    docker logs "$CONTAINER_ID" >&2
    echo "PHP-FPM did not remain running" >&2
    exit 1
fi

docker exec "$CONTAINER_ID" php-fpm -t
echo "Smoke tests passed for $IMAGE on $PLATFORM"
