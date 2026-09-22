# docker-php

这是一个基于官方 `php:8.5-fpm-alpine` 制作的 PHP-FPM 镜像，主要用于运行
Typecho，也可以用于其他常规 PHP 应用。

镜像只提供 PHP 运行环境，不包含 Typecho、Nginx 和数据库。应用文件需要从宿主机
挂载，HTTP 请求则由 Nginx 等 Web 服务器通过 FastCGI 转发给 PHP-FPM。

支持 `linux/amd64` 和 `linux/arm64`。

## 和官方镜像的区别

在官方 PHP-FPM Alpine 镜像的基础上，本镜像增加了：

- `imagick`、`gd`、`exif`：图片处理；
- `mysqli`、`pdo_mysql`、`pdo_pgsql`：MySQL 和 PostgreSQL；
- `redis`：Redis 缓存；
- `bcmath`、`intl`、`zip`：常用 PHP 功能；
- Composer 2、Git 和完整时区数据；
- 通过 `PUID`、`PGID` 调整 `www-data` 的 UID 和 GID；
- 通过 `TZ` 同时设置系统和 PHP 时区。

官方镜像已经内置 cURL、DOM、mbstring、OPcache、PDO SQLite、SQLite3 等模块，
本镜像直接保留这些模块。

PHP-FPM 监听容器内的 `9000` 端口，`pm.max_requests` 设置为 `300`，其余进程管理
参数沿用官方镜像默认值。

## 镜像地址

Docker Hub：

```text
mikusa/docker-php:8.5.10-fpm-alpine
```

GitHub Container Registry：

```text
ghcr.io/mikusaa/docker-php:8.5.10-fpm-alpine
```

可用标签：

| 标签 | 说明 |
| --- | --- |
| `8.5.10-fpm-alpine` | 固定 PHP 补丁版本，生产环境推荐使用 |
| `8.5-fpm-alpine` | 跟随最新的 PHP 8.5 补丁版本 |
| `latest` | 当前推荐版本 |

## 使用方法

下面的例子假设 Typecho 文件位于当前目录的 `typecho` 文件夹。

```yaml
services:
  php:
    image: mikusa/docker-php:8.5.10-fpm-alpine
    restart: unless-stopped
    environment:
      TZ: Asia/Shanghai
      PUID: 1000
      PGID: 1000
    volumes:
      - ./typecho:/home/wwwroot

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    depends_on:
      - php
    ports:
      - "80:80"
    volumes:
      - ./typecho:/home/wwwroot:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
```

对应的 `nginx.conf` 可以从下面这份基础配置开始：

```nginx
server {
    listen 80;
    server_name _;
    root /home/wwwroot;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri =404;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass php:9000;
    }
}
```

启动服务：

```sh
docker compose up -d
```

## 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `TZ` | `Asia/Shanghai` | 系统和 PHP 使用的时区 |
| `PUID` | `1000` | PHP-FPM 工作用户 `www-data` 的 UID |
| `PGID` | `1000` | PHP-FPM 工作用户 `www-data` 的 GID |

`PUID` 和 `PGID` 必须是非零数字。它们应该与宿主机上 Typecho 文件的所有者一致，
否则 PHP 可能无法写入上传目录、缓存或配置文件。镜像只修改容器内 `www-data` 的身份，
不会递归修改挂载目录的权限。

## 自定义 PHP 和 FPM

镜像沿用官方 PHP 配置。需要修改上传大小、内存限制等参数时，可以挂载自己的 ini：

```yaml
services:
  php:
    volumes:
      - ./php.ini:/usr/local/etc/php/conf.d/zzz-custom.ini:ro
```

例如：

```ini
memory_limit = 256M
upload_max_filesize = 50M
post_max_size = 50M
```

需要调整 FPM worker 数量时，可以用同样的方式挂载额外配置：

```yaml
services:
  php:
    volumes:
      - ./php-fpm.conf:/usr/local/etc/php-fpm.d/zzz-custom.conf:ro
```

```ini
[www]
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

## 注意事项

- `9000` 是 FastCGI 端口，不是 HTTP 端口，不要直接暴露到公网；
- 不要在 Compose 中设置 `user:`，入口脚本需要 root 权限来应用 `PUID`、`PGID` 和时区，
  PHP-FPM 工作进程仍会以 `www-data` 运行；
- PHP 版本升级前应先检查 Typecho 主题和插件的兼容性；
- 生产环境建议固定完整版本标签，确认新镜像可用后再升级；
- Typecho 程序、`usr` 目录和数据库需要单独备份，本镜像不会管理这些数据。
