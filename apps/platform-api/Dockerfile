FROM php:8.4-fpm AS base

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
        echo "max_execution_time=60"; \
    } > /usr/local/etc/php/conf.d/newpaotang-uploads.ini

RUN sed -ri 's/^pm = .*/pm = dynamic/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -ri 's/^pm.max_children = .*/pm.max_children = 10/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -ri 's/^pm.start_servers = .*/pm.start_servers = 2/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -ri 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 2/' /usr/local/etc/php-fpm.d/www.conf \
    && sed -ri 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 4/' /usr/local/etc/php-fpm.d/www.conf \
    && { \
        echo "pm.max_requests = 500"; \
        echo "request_terminate_timeout = 75s"; \
        echo "catch_workers_output = yes"; \
        echo "clear_env = no"; \
    } >> /usr/local/etc/php-fpm.d/www.conf

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

CMD ["php-fpm", "-F"]
