group "default" {
  targets = ["image"]
}

target "docker-metadata-action" {}

target "php-security-source" {
  context = "https://github.com/docker-library/php.git#f6048b5f6e3c2202ee082665a4ccc0d90de291a3:8.5/alpine3.24/fpm"
}

target "image" {
  inherits = ["docker-metadata-action"]
  context = "."
  dockerfile = "Dockerfile"
  # Match only the old pinned base. Dependabot's official update exits this override.
  contexts = {
    "php:8.5.11-fpm-alpine@sha256:fa01fb1645cd0fc566a5f146b099adace33b906571f972f71f2182a7c12d1cd7" = "target:php-security-source"
  }
}
