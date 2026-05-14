FROM php:8.4-cli AS base

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libpq-dev \
        libzip-dev \
        libonig-dev \
        libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install bcmath dom gd mbstring pcntl pdo_pgsql zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN { \
        echo "upload_max_filesize=500M"; \
        echo "post_max_size=520M"; \
        echo "memory_limit=768M"; \
    } > /usr/local/etc/php/conf.d/newpaotang-uploads.ini

WORKDIR /var/www/html

FROM base AS development

ENV COMPOSER_ALLOW_SUPERUSER=1

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]

FROM base AS production

ENV APP_ENV=production \
    APP_DEBUG=false \
    COMPOSER_ALLOW_SUPERUSER=1

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --no-scripts

COPY . .
RUN composer dump-autoload --optimize \
    && php artisan package:discover --ansi

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
