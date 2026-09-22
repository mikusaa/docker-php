#!/bin/sh
set -eu

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
TZ="${TZ:-Asia/Shanghai}"

case "$PUID" in
    ''|*[!0-9]*)
        echo "PUID must be a numeric UID" >&2
        exit 1
        ;;
    0)
        echo "PUID must not be 0" >&2
        exit 1
        ;;
esac

case "$PGID" in
    ''|*[!0-9]*)
        echo "PGID must be a numeric GID" >&2
        exit 1
        ;;
    0)
        echo "PGID must not be 0" >&2
        exit 1
        ;;
esac

case "$TZ" in
    ''|/*|../*|*/../*|*/..|*[!A-Za-z0-9/_+-]*)
        echo "TZ must be a valid timezone name" >&2
        exit 1
        ;;
esac

if [ ! -f "/usr/share/zoneinfo/$TZ" ]; then
    echo "TZ '$TZ' is not a valid timezone in /usr/share/zoneinfo" >&2
    exit 1
fi

cp "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone
echo "date.timezone = $TZ" > /usr/local/etc/php/conf.d/zz-timezone.ini

if [ "$PUID" != "$(id -u www-data)" ] || [ "$PGID" != "$(id -g www-data)" ]; then
    groupmod -o -g "$PGID" www-data
    usermod -o -u "$PUID" -g "$PGID" www-data
fi

exec docker-php-entrypoint "$@"
