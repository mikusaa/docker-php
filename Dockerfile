# syntax=docker/dockerfile:1.7
FROM php:8.5.12-fpm-alpine@sha256:c15690bd932bd6d33f43ccae6ddd8d60acb93cee50c16afc6e699265d5d86583

LABEL org.opencontainers.image.source="https://github.com/mikusaa/docker-php" \
      org.opencontainers.image.description="预装常用扩展的 PHP-FPM Alpine 镜像"

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

# Pin the same official extension releases while PECL downloads return HTTP 500.
RUN set -eux; \
    apk add --no-cache git shadow tzdata; \
    git clone --branch 6.3.0 --depth 1 https://github.com/phpredis/phpredis.git /tmp/phpredis; \
    test "$(git -C /tmp/phpredis rev-parse HEAD)" = df4fab2de7fc327c54c94a13af2b9542e4fbd720; \
    git -C /tmp/phpredis submodule update --init --depth 1; \
    install-php-extensions \
        Imagick/imagick@70087bab33eab913e99ac77d64d04d1a2fd0b7b0 \
        bcmath pdo_mysql pdo_pgsql \
        /tmp/phpredis \
        mysqli zip gd exif intl; \
    rm -rf /tmp/phpredis

WORKDIR /home/wwwroot
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
