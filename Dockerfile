FROM php:8.2-cli-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Install system libraries + build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    curl \
    pkg-config \
    autoconf \
    g++ \
    make \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    gettext \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        mysqli \
        mbstring \
        gd \
        zip \
        intl \
        gettext \
        bcmath \
    && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . /app

# Install PHP dependencies (vendor/)
RUN composer install --no-dev --optimize-autoloader

# Start server
CMD php -S 0.0.0.0:$PORT -t .
