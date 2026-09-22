# syntax=docker/dockerfile:1.7
FROM php:8.5.10-fpm-alpine@sha256:ce1dcc234879feab0f309100e55e89e7cf21b9085e76de2a03a8240cec02751e

LABEL org.opencontainers.image.source="https://github.com/mikusaa/docker-php" \
      org.opencontainers.image.description="面向 Typecho 等 PHP 应用的 PHP-FPM Alpine 镜像"

ADD --chmod=755 --checksum=sha256:4fb76a1fb1085e1e2148f3919b8e9ba8429f749b3cc96fa785a23f173192dc9a \
    https://github.com/mlocati/docker-php-extension-installer/releases/download/2.11.27/install-php-extensions \
    /usr/local/bin/install-php-extensions

COPY --from=composer:2@sha256:a5f59b9fd2faf31218632be4809dc6491761085e8064c31dc3b84378c48c248b /usr/bin/composer /usr/local/bin/composer
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY zz-www-user.conf /usr/local/etc/php-fpm.d/zz-www-user.conf

ENV TZ=Asia/Shanghai \
    PUID=1000 \
    PGID=1000 \
    COMPOSER_HOME=/tmp/composer \
    COMPOSER_ALLOW_SUPERUSER=1

RUN set -eux; \
    apk add --no-cache git shadow tzdata; \
    install-php-extensions imagick bcmath pdo_mysql pdo_pgsql redis mysqli zip gd exif intl

WORKDIR /home/wwwroot
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
