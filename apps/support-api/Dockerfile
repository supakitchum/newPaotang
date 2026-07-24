FROM php:8.4-cli AS base

RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip libjpeg62-turbo-dev libpng-dev libwebp-dev libpq-dev libzip-dev \
    && docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-install gd pcntl pdo_pgsql zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html

FROM base AS development
ENV COMPOSER_ALLOW_SUPERUSER=1
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8100", "--no-reload"]

FROM base AS production
ENV APP_ENV=production APP_DEBUG=false COMPOSER_ALLOW_SUPERUSER=1
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts
COPY . .
RUN composer dump-autoload --optimize && php artisan package:discover --ansi
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8100", "--no-reload"]
