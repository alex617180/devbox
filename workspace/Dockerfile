# workspace/Dockerfile
ARG PHP_TAG=8.3-cli
FROM php:${PHP_TAG}

ARG NODE_MAJOR=20

# Базовые пакеты + PHP-расширения (+Xdebug)
RUN apt-get update && apt-get install -y \
    git unzip zip curl gnupg ca-certificates procps iproute2 net-tools lsof \
    default-mysql-client \
    libzip-dev libicu-dev libxml2-dev \
    libjpeg-dev libpng-dev libwebp-dev libfreetype6-dev \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install \
      pdo_mysql zip intl bcmath pcntl sockets exif gd \
 && pecl channel-update pecl.php.net \
 && if php -r 'exit(PHP_VERSION_ID >= 80000 ? 0 : 1);'; then \
      pecl install xdebug; \
    else \
      pecl install xdebug-3.1.6; \
    fi \
 && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Node.js LTS + npm
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
 && apt-get update && apt-get install -y nodejs \
 && npm i -g npm@latest

# Xdebug конфиг (расширение уже установлено через PECL; загружается этим файлом)
COPY xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini

# Нормальный dev-пользователь
RUN useradd -m -u 1000 -s /bin/bash dev || true

WORKDIR /var/www
EXPOSE 8000-8015 5173-5199
