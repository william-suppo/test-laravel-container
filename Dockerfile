###
#
# Resolve php dependencies
#
###
FROM php:8.1-cli-alpine as vendor

WORKDIR /app

RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

COPY composer.json composer.json
COPY composer.lock composer.lock

# Install php dependencies
RUN composer install --quiet --no-ansi --no-interaction --no-scripts --no-suggest --no-progress --prefer-dist

###
#
# Build assets
#
###
FROM node:16-alpine as frontend

WORKDIR /app

RUN mkdir -p /app/public

COPY package.json package-lock.json webpack.mix.js tailwind.config.js /app/
COPY resources/ /app/resources/

RUN npm ci && npm run prod

###
#
# Build app
#
###
FROM php:8.1-apache-buster

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libpq-dev \
    libzip-dev \
    libcurl4-openssl-dev \
    zip \
    unzip \
    default-mysql-client

# Copy vhost config
COPY vhost.conf /etc/apache2/sites-available/000-default.conf

# Enable Apache mods
RUN a2enmod rewrite

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd zip curl intl

# Get latest Composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

# Clean cache
RUN apt-get -y autoremove \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy source code
COPY --chown=www-data:www-data . /app

# Copy vendor
COPY --from=vendor --chown=www-data:www-data /app/vendor/ /app/vendor/

# Copy assets
COPY --from=frontend --chown=www-data:www-data /app/public/js/ /app/public/js/
COPY --from=frontend --chown=www-data:www-data /app/public/css/ /app/public/css/
COPY --from=frontend --chown=www-data:www-data /app/mix-manifest.json /app/mix-manifest.json
